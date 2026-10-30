import CoreData
import SwiftData
import XCTest
@testable import Caloryn

@MainActor
final class CloudKitSchemaContractTests: XCTestCase {
    private static let directory = URL(filePath: #filePath).deletingLastPathComponent()
    private static let productionSchemaURL = directory.appending(path: "ProductionSchema.ckdb")
    private static let modelSchemaURL = directory.appending(path: "ModelSchema.ckdb")

    func testProductionAcceptsEveryFieldTheModelsCanWrite() throws {
        let production = try Self.productionRecordTypes()
        let model = try CloudKitSchemaFile.recordTypes(of: Self.model())

        let missing = model.flatMap { recordType, fields -> [String] in
            guard let deployed = production[recordType] else {
                return [recordType]
            }
            return fields.keys
                .filter { deployed[$0] == nil }
                .map { "\(recordType).\($0)" }
        }

        XCTAssertEqual(
            missing.sorted(),
            [],
            """
            CloudKit Production would reject every record carrying these, and one rejected record \
            fails its whole upload batch. Import ModelSchema.ckdb into Development, deploy it to \
            Production, then export Production over ProductionSchema.ckdb (docs/cloudkit-schema.md).
            """
        )
    }

    func testTheModelSchemaTypesEveryFieldAsProductionAlreadyStoresIt() throws {
        let production = try Self.productionRecordTypes()
        let model = try CloudKitSchemaFile.recordTypes(of: Self.model())

        let shared = model.flatMap { recordType, fields in
            fields.compactMap { field, type in
                production[recordType]?[field].map { (field: "\(recordType).\(field)", model: type, production: $0) }
            }
        }
        let mismatched = shared
            .filter { $0.model != $0.production }
            .map { "\($0.field): \($0.model) here, \($0.production) in Production" }

        XCTAssertGreaterThan(shared.count, 100)
        XCTAssertEqual(mismatched.sorted(), [])
    }

    func testModelSchemaFileMatchesTheModels() throws {
        let rendered = try CloudKitSchemaFile.render(Self.model())
        guard let recorded = try? String(contentsOf: Self.modelSchemaURL, encoding: .utf8) else {
            try rendered.write(to: Self.modelSchemaURL, atomically: true, encoding: .utf8)
            return XCTFail("Recorded ModelSchema.ckdb from the models. Run the test again.")
        }

        XCTAssertEqual(
            recorded,
            rendered,
            "The models changed. Delete ModelSchema.ckdb, run this test twice, and import the new file (docs/cloudkit-schema.md)."
        )
    }

    func testTheModelSchemaFileReadsBackAsTheModelsRecordTypes() throws {
        let model = try Self.model()

        let readBack = CloudKitSchemaFile.recordTypes(in: try CloudKitSchemaFile.render(model))
            .filter { $0.key != "Users" }
            .mapValues { $0.filter { !$0.key.hasPrefix("___") } }

        XCTAssertEqual(readBack, try CloudKitSchemaFile.recordTypes(of: model))
    }

    func testEveryModelEntityBecomesARecordTypeWithItsAttributesAndToOneRelationships() throws {
        let model = try CloudKitSchemaFile.recordTypes(of: Self.model())

        XCTAssertEqual(
            Set(model.keys),
            ["CD_UserProfile", "CD_FoodItem", "CD_FoodLogEntry", "CD_RecipeIngredient",
             "CD_DailyGoalSnapshot", "CD_MealTemplate", "CD_MealTemplateItem"]
        )
        XCTAssertEqual(model["CD_FoodLogEntry"]?["CD_foodItem"], "STRING")
        XCTAssertNil(model["CD_FoodItem"]?["CD_logEntries"])
        XCTAssertEqual(model["CD_MealTemplateItem"]?["CD_snapshotData"], "BYTES")
        XCTAssertEqual(model["CD_MealTemplateItem"]?["CD_snapshotData_ckAsset"], "ASSET")
    }

    private static func model() throws -> NSManagedObjectModel {
        try XCTUnwrap(NSManagedObjectModel.makeManagedObjectModel(for: CalorynModelSchema.models))
    }

    private static func productionRecordTypes() throws -> CloudKitSchemaFile.RecordTypes {
        CloudKitSchemaFile.recordTypes(in: try String(contentsOf: productionSchemaURL, encoding: .utf8))
    }
}
