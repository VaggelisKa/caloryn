import Foundation

struct FoodSearchQuery: Equatable {
    private static let calorynAPILengthLimit = 100

    let text: String

    init(_ typed: String) {
        text = typed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var meetsSearchMinimum: Bool {
        guard text.utf16.count >= 2 else { return false }
        return text.precomposedStringWithCompatibilityMapping.unicodeScalars
            .split(whereSeparator: { !Self.isLetterOrDigit($0) })
            .contains { String(String.UnicodeScalarView($0)).lowercased().unicodeScalars.count >= 2 }
    }

    var calorynAPIText: String {
        guard text.utf16.count <= Self.calorynAPILengthLimit else { return text }
        let collapsed = text.unicodeScalars
            .split(whereSeparator: \.properties.isWhitespace)
            .map { String(String.UnicodeScalarView($0)) }
            .joined(separator: " ")
        return collapsed.unicodeScalars.allSatisfy(\.isASCII) ? collapsed.lowercased() : collapsed
    }

    private static func isLetterOrDigit(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter,
             .decimalNumber, .letterNumber, .otherNumber:
            true
        default:
            false
        }
    }
}
