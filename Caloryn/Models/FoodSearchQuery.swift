import Foundation

struct FoodSearchQuery: Equatable {
    private static let calorynAPILengthLimit = 100

    let text: String

    init(_ typed: String) {
        text = typed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isEmpty: Bool {
        text.isEmpty
    }

    var calorynAPIText: String {
        guard text.utf16.count <= Self.calorynAPILengthLimit else { return text }
        let collapsed = text.unicodeScalars
            .split(whereSeparator: \.properties.isWhitespace)
            .map { String(String.UnicodeScalarView($0)) }
            .joined(separator: " ")
        return collapsed.unicodeScalars.allSatisfy(\.isASCII) ? collapsed.lowercased() : collapsed
    }
}
