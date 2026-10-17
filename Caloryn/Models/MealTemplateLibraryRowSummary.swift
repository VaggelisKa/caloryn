import Foundation

/// What one saved meal's row says about itself: its items by name, and their total.
///
/// Takes the meal's name and each item's name and kcal rather than the `MealTemplate`,
/// because that is all the row depends on. A meal whose items could not be read is still
/// listed, so it can be opened and fixed or deleted, but it has no items to name and no
/// total to print: it reads "Unavailable meal" rather than "0 kcal".
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

    /// The items in the meal's own order, comma-joined: "Skyr, Granola, Banana". Names are
    /// printed as saved, so a brand keeps its capitals.
    var detail: String {
        guard isAvailable else { return Self.unavailableText }
        return items.map(\.name).joined(separator: ", ")
    }

    /// The whole meal in kcal. A figure that never became a number counts as nothing, so
    /// one bad item cannot turn the total into NaN.
    var calories: Double {
        items.reduce(0) { total, item in
            item.calories.isFinite ? total + item.calories : total
        }
    }

    /// Rounded to whole kcal; nil for an unavailable meal, which has no total to print.
    var caloriesText: String? {
        guard isAvailable else { return nil }
        return "\(calories.rounded().truncatedSafely)"
    }

    /// The row read as one element, the unit spelled out.
    var accessibilityLabel: String {
        guard let caloriesText else { return "\(name), \(Self.unavailableText)" }
        return "\(name), \(detail), \(caloriesText) kilocalories"
    }
}
