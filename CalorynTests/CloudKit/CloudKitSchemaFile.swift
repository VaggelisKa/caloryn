import CoreData

@MainActor
enum CloudKitSchemaFile {
    typealias RecordTypes = [String: [String: String]]

    enum Failure: Error, Equatable {
        case unsupportedAttribute(entity: String, attribute: String)
    }

    private static let systemFields = [
        ("\"___createTime\"", "TIMESTAMP"),
        ("\"___createdBy\"", "REFERENCE"),
        ("\"___etag\"", "STRING"),
        ("\"___modTime\"", "TIMESTAMP"),
        ("\"___modifiedBy\"", "REFERENCE"),
        ("\"___recordID\"", "REFERENCE"),
    ]

    private static let usersRecordType = """
        RECORD TYPE Users (
            "___createTime" TIMESTAMP,
            "___createdBy"  REFERENCE,
            "___etag"       STRING,
            "___modTime"    TIMESTAMP,
            "___modifiedBy" REFERENCE,
            "___recordID"   REFERENCE,
            roles           LIST<INT64>,
            GRANT WRITE TO "_creator",
            GRANT READ TO "_world"
        );
    """

    static func recordTypes(in text: String) -> RecordTypes {
        var recordTypes: RecordTypes = [:]
        var current: String?
        for line in text.split(separator: "\n") {
            let words = line.split(whereSeparator: \.isWhitespace).map(String.init)
            if words.starts(with: ["RECORD", "TYPE"]), words.count > 2 {
                let name = words[2].trimmingCharacters(in: CharacterSet(charactersIn: "("))
                recordTypes[name] = [:]
                current = name
            } else if words.first == ");" {
                current = nil
            } else if let current, words.count > 1, words[0] != "GRANT" {
                let field = words[0].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                recordTypes[current, default: [:]][field] = words[1].trimmingCharacters(in: CharacterSet(charactersIn: ","))
            }
        }
        return recordTypes
    }

    static func recordTypes(of model: NSManagedObjectModel) throws -> RecordTypes {
        var recordTypes: RecordTypes = [:]
        for entity in model.entities {
            let fields = try fields(of: entity)
            recordTypes[recordTypeName(of: entity)] = Dictionary(
                uniqueKeysWithValues: fields.map { ($0.name, $0.type) }
            )
        }
        return recordTypes
    }

    static func render(_ model: NSManagedObjectModel) throws -> String {
        let entities = model.entities.sorted { recordTypeName(of: $0) < recordTypeName(of: $1) }
        let recordTypes = try entities.map { try render(entity: $0) }
        return "DEFINE SCHEMA\n\n" + (recordTypes + [usersRecordType]).joined(separator: "\n\n") + "\n"
    }

    private static func recordTypeName(of entity: NSEntityDescription) -> String {
        "CD_\(entity.name ?? "")"
    }

    private static func render(entity: NSEntityDescription) throws -> String {
        let fields = try fields(of: entity).sorted { $0.name < $1.name }
        let rows = fields.map { ($0.name, [$0.type, $0.indexes].filter { !$0.isEmpty }.joined(separator: " ")) }
            + systemFields
        let width = rows.map(\.0.count).max() ?? 0
        let lines = rows.map { name, definition in
            "        \(name.padding(toLength: width, withPad: " ", startingAt: 0)) \(definition),"
        } + [
            "        GRANT WRITE TO \"_creator\",",
            "        GRANT CREATE TO \"_icloud\",",
            "        GRANT READ TO \"_world\"",
        ]
        return "    RECORD TYPE \(recordTypeName(of: entity)) (\n" + lines.joined(separator: "\n") + "\n    );"
    }

    private struct Field {
        let name: String
        let type: String

        var indexes: String {
            switch type {
            case "STRING": "QUERYABLE SEARCHABLE SORTABLE"
            case "ASSET": ""
            default: "QUERYABLE SORTABLE"
            }
        }
    }

    private static func fields(of entity: NSEntityDescription) throws -> [Field] {
        var fields = [Field(name: "CD_entityName", type: "STRING")]
        for attribute in entity.attributesByName.values where !attribute.isTransient {
            let name = "CD_\(attribute.name)"
            switch attribute.attributeType {
            case .UUIDAttributeType, .stringAttributeType, .URIAttributeType:
                fields.append(Field(name: name, type: "STRING"))
            case .booleanAttributeType, .integer16AttributeType, .integer32AttributeType, .integer64AttributeType:
                fields.append(Field(name: name, type: "INT64"))
            case .doubleAttributeType, .floatAttributeType:
                fields.append(Field(name: name, type: "DOUBLE"))
            case .dateAttributeType:
                fields.append(Field(name: name, type: "TIMESTAMP"))
            case .transformableAttributeType, .compositeAttributeType:
                fields.append(Field(name: name, type: "BYTES"))
            case .binaryDataAttributeType:
                fields.append(Field(name: name, type: "BYTES"))
                fields.append(Field(name: "\(name)_ckAsset", type: "ASSET"))
            default:
                throw Failure.unsupportedAttribute(entity: entity.name ?? "", attribute: attribute.name)
            }
        }
        for relationship in entity.relationshipsByName.values where !relationship.isToMany {
            fields.append(Field(name: "CD_\(relationship.name)", type: "STRING"))
        }
        return fields
    }
}
