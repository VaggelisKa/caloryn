import Foundation

struct LogLinkDraft: Equatable, Sendable {
    enum Field: String, CaseIterable, Sendable {
        case version = "v"
        case name
        case kcal
        case grams
        case protein
        case carbs
        case fat
        case meal

        var label: String {
            switch self {
            case .version: "version number"
            case .name: "food name"
            case .kcal: "calorie value"
            case .grams: "portion weight"
            case .protein: "protein amount"
            case .carbs: "carbs amount"
            case .fat: "fat amount"
            case .meal: "meal"
            }
        }
    }

    static let linkPrefix = "caloryn://log?"
    static let supportedVersion = "1"
    static let maximumNameLength = 100
    static let calorieRange: ClosedRange<Double> = 0...20_000
    static let macroRange: ClosedRange<Double> = 0...5_000

    let name: String
    let kcal: Double
    let grams: Double?
    let proteinG: Double?
    let carbsG: Double?
    let fatG: Double?
    let meal: WidgetMeal?

    static func parse(_ text: String) -> Result<LogLinkDraft, LogLinkRejection> {
        do throws(LogLinkRejection) {
            let query = try extractQuery(from: text)
            let values = try fieldValues(in: query)
            return .success(try draft(from: values))
        } catch {
            return .failure(error)
        }
    }

    private static let prefixScalars = Array(linkPrefix.unicodeScalars)
    private static let linkTerminators: Set<Unicode.Scalar> = ["`", ")", "]", ">", "<", "\"", "'"]

    private static func extractQuery(from text: String) throws(LogLinkRejection) -> String {
        let scalars = Array(text.unicodeScalars)
        let starts = linkStarts(in: scalars, upTo: 2)
        guard let start = starts.first else { throw .noLink }
        guard starts.count == 1 else { throw .multipleLinks }

        let queryStart = start + prefixScalars.count
        let queryEnd = scalars[queryStart...].firstIndex { endsLink($0) } ?? scalars.endIndex
        let query = String(String.UnicodeScalarView(scalars[queryStart..<queryEnd]))
        guard !query.contains("#") else { throw .containsFragment }
        return query
    }

    private static func linkStarts(in scalars: [Unicode.Scalar], upTo limit: Int) -> [Int] {
        var starts: [Int] = []
        var index = 0
        while index + prefixScalars.count <= scalars.count, starts.count < limit {
            if hasLinkPrefix(scalars, at: index) {
                starts.append(index)
                index += prefixScalars.count
            } else {
                index += 1
            }
        }
        return starts
    }

    private static func hasLinkPrefix(_ scalars: [Unicode.Scalar], at start: Int) -> Bool {
        prefixScalars.indices.allSatisfy { offset in
            lowercasedASCII(scalars[start + offset]) == prefixScalars[offset]
        }
    }

    private static func lowercasedASCII(_ scalar: Unicode.Scalar) -> Unicode.Scalar {
        switch scalar {
        case "A"..."Z": Unicode.Scalar(scalar.value + 32) ?? scalar
        default: scalar
        }
    }

    private static func endsLink(_ scalar: Unicode.Scalar) -> Bool {
        scalar.properties.isWhitespace || linkTerminators.contains(scalar)
    }

    private static func fieldValues(in query: String) throws(LogLinkRejection) -> [Field: String] {
        guard let components = URLComponents(string: linkPrefix + query, encodingInvalidCharacters: false) else {
            throw .malformedLink
        }

        var pairs: [(name: String, value: String)] = []
        for item in components.percentEncodedQueryItems ?? [] {
            guard let name = item.name.removingPercentEncoding,
                  let value = (item.value ?? "").removingPercentEncoding else {
                throw .malformedLink
            }
            pairs.append((name, value))
        }

        let versions = pairs.filter { $0.name == Field.version.rawValue }
        guard let version = versions.first else { throw .missingField(.version) }
        guard versions.count == 1 else { throw .duplicateField(.version) }
        guard version.value == supportedVersion else { throw .unsupportedVersion }

        var values: [Field: String] = [:]
        for pair in pairs {
            guard !pair.name.isEmpty else { throw .malformedLink }
            guard let field = Field(rawValue: pair.name) else { throw .unknownField(pair.name) }
            guard values.updateValue(pair.value, forKey: field) == nil else { throw .duplicateField(field) }
        }
        return values
    }

    private static func draft(from values: [Field: String]) throws(LogLinkRejection) -> LogLinkDraft {
        guard let rawName = values[.name] else { throw .missingField(.name) }
        guard let rawKcal = values[.kcal] else { throw .missingField(.kcal) }

        let name = try cleanedName(rawName)

        let kcal = try amount(rawKcal, of: .kcal)
        guard calorieRange.contains(kcal) else { throw .outOfRange(.kcal) }

        let grams = try optionalAmount(.grams, in: values)
        if let grams, !FavoriteFoodLogging.isSafePortion(grams) {
            throw .outOfRange(.grams)
        }

        return LogLinkDraft(
            name: name,
            kcal: kcal,
            grams: grams,
            proteinG: try macro(.protein, in: values, portionGrams: grams),
            carbsG: try macro(.carbs, in: values, portionGrams: grams),
            fatG: try macro(.fat, in: values, portionGrams: grams),
            meal: try meal(in: values)
        )
    }

    private static func cleanedName(_ raw: String) throws(LogLinkRejection) -> String {
        let cleaned = normalizedName(raw)
        guard !cleaned.isEmpty else { throw .emptyName }
        guard cleaned.unicodeScalars.count <= maximumNameLength else { throw .nameTooLong }
        return cleaned
    }

    static func normalizedName(_ raw: String) -> String {
        var cleaned = String.UnicodeScalarView()
        var pendingSpace = false
        for scalar in raw.unicodeScalars {
            if scalar.properties.isWhitespace {
                pendingSpace = !cleaned.isEmpty
                continue
            }
            switch scalar.properties.generalCategory {
            case .control, .format:
                continue
            default:
                if pendingSpace {
                    cleaned.append(" ")
                    pendingSpace = false
                }
                cleaned.append(scalar)
            }
        }
        return String(cleaned)
    }

    private static func optionalAmount(_ field: Field, in values: [Field: String]) throws(LogLinkRejection) -> Double? {
        guard let text = values[field] else { return nil }
        return try amount(text, of: field)
    }

    private static func amount(_ text: String, of field: Field) throws(LogLinkRejection) -> Double {
        let parts = text.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        guard let whole = parts.first,
              isASCIIDigits(whole, count: 1...6),
              parts.count == 1 || isASCIIDigits(parts[1], count: 1...2),
              let value = Double(text) else {
            throw .invalidNumber(field)
        }
        return value
    }

    private static func isASCIIDigits(_ text: Substring, count: ClosedRange<Int>) -> Bool {
        count.contains(text.utf8.count)
            && text.utf8.allSatisfy { (UInt8(ascii: "0")...UInt8(ascii: "9")).contains($0) }
    }

    private static func macro(
        _ field: Field,
        in values: [Field: String],
        portionGrams: Double?
    ) throws(LogLinkRejection) -> Double? {
        guard let grams = try optionalAmount(field, in: values) else { return nil }
        guard macroRange.contains(grams) else { throw .outOfRange(field) }
        if let portionGrams, grams > portionGrams {
            throw .exceedsPortion(field)
        }
        return grams
    }

    private static func meal(in values: [Field: String]) throws(LogLinkRejection) -> WidgetMeal? {
        guard let text = values[.meal] else { return nil }
        guard let meal = WidgetMeal(rawValue: text) else { throw .invalidMeal }
        return meal
    }
}

enum LogLinkRejection: LocalizedError, Equatable, Sendable {
    case noLink
    case multipleLinks
    case malformedLink
    case containsFragment
    case unsupportedVersion
    case unknownField(String)
    case duplicateField(LogLinkDraft.Field)
    case missingField(LogLinkDraft.Field)
    case emptyName
    case nameTooLong
    case invalidNumber(LogLinkDraft.Field)
    case outOfRange(LogLinkDraft.Field)
    case exceedsPortion(LogLinkDraft.Field)
    case invalidMeal

    var errorDescription: String? {
        switch self {
        case .noLink:
            "No Caloryn link found. Copy the chatbot’s reply with the line that starts with caloryn://log?, then paste again."
        case .multipleLinks:
            "The text contains more than one Caloryn link. Paste one food at a time."
        case .malformedLink:
            "The link is damaged or incomplete. Ask your chatbot to send it again in a code block."
        case .containsFragment:
            "The link contains a “#”, which Caloryn doesn’t accept. Ask your chatbot for a new link."
        case .unsupportedVersion:
            "This link was made for a newer version of Caloryn. Update Caloryn, then paste it again."
        case .unknownField:
            "The link has a field Caloryn doesn’t recognize. It may only contain v, name, kcal, grams, protein, carbs, fat and meal."
        case .duplicateField(let field):
            "The link gives the \(field.label) more than once."
        case .missingField(let field):
            "The link has no \(field.label)."
        case .emptyName:
            "The food name is empty."
        case .nameTooLong:
            "The food name is longer than 100 characters."
        case .invalidNumber(let field):
            "The \(field.label) isn’t a plain number. Use digits with up to two decimals, such as 150 or 12.5, without units, signs or commas."
        case .outOfRange(.kcal):
            "The calorie value must be between 0 and 20,000."
        case .outOfRange(.grams):
            "The portion weight must be more than 0 g and no more than 100,000 g."
        case .outOfRange(let field):
            "The \(field.label) must be between 0 and 5,000 g."
        case .exceedsPortion(let field):
            "The \(field.label) can’t be more than the portion weight."
        case .invalidMeal:
            "The meal must be breakfast, lunch, snack or dinner, in lowercase."
        }
    }
}
