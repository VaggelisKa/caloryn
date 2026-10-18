import Foundation

struct MealTemplateLibraryRowSummary: Equatable {
    struct Item: Equatable {
        let name: String
        let calories: Double

        init(name: String, calories: Double) {
            self.name = name
            self.calories = calories
        }
    }

    static let unavailableText = "Unavailable meal"

    let name: String
    let items: [Item]

    init(name: String, items: [Item]) {
        self.name = name
        self.items = items
    }

    var isAvailable: Bool { !items.isEmpty }

    var detail: String {
        guard isAvailable else { return Self.unavailableText }
        return items.map(\.name).joined(separator: ", ")
    }

    var calories: Double {
        items.reduce(0) { total, item in
            item.calories.isFinite ? total + item.calories : total
        }
    }

    var caloriesText: String? {
        guard isAvailable else { return nil }
        return "\(calories.rounded().truncatedSafely)"
    }

    var accessibilityLabel: String {
        guard let caloriesText else { return "\(name), \(Self.unavailableText)" }
        return "\(name), \(detail), \(caloriesText) kilocalories"
    }
}
