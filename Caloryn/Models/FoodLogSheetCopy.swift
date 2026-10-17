import Foundation

/// The sentences the Add Food and Portion sheets build out of data.
///
/// Sentence case and comma joins (`docs/design/plate-market.md`, "Copy"); a food row's line
/// is built by `FoodRowSummary`. Kept out of the views so the wording rules can be tested
/// without rendering anything.
enum FoodLogSheetCopy {
    // MARK: - Servings

    /// A declared serving in the house form, "1 pot 150 g": the weight follows the count
    /// without brackets, with a space before its unit. "1 pot (150g)" becomes "1 pot 150 g"
    /// and a bare "170g" becomes "170 g"; anything that is not a count and a weight is
    /// shown as written.
    static func serving(_ description: String) -> String {
        let trimmed = description.trimmingCharacters(in: .whitespaces)
        // "1 pot (150g)", "2 squares ( 20 g )".
        if let match = trimmed.wholeMatch(
            of: /(.*?)\s*\(\s*(\d+(?:[.,]\d+)?)\s*(g|kg|ml|cl|dl|l|oz)\s*\)/.ignoresCase()
        ) {
            let count = match.1.trimmingCharacters(in: .whitespaces)
            let weight = "\(match.2) \(match.3)"
            return count.isEmpty ? weight : "\(count) \(weight)"
        }
        // "170g", "250 ml".
        if let match = trimmed.wholeMatch(of: /(\d+(?:[.,]\d+)?)\s*(g|kg|ml|cl|dl|l|oz)/.ignoresCase()) {
            return "\(match.1) \(match.2)"
        }
        return trimmed
    }

    /// The weight in grams a serving's description ends on: 150 for "1 pot (150g)" and for
    /// its house form "1 pot 150 g", 40 for "40 g", 12.5 for "12,5 g". `nil` when it gives
    /// none, or gives it in another unit: a millilitre is not a gram, and a row priced off a
    /// guessed density would be wrong.
    static func servingGrams(_ description: String) -> Double? {
        let trimmed = description.trimmingCharacters(in: .whitespaces)
        guard let match = trimmed.wholeMatch(
            of: /(?:.*[\s(])?(\d+(?:[.,]\d+)?)\s*g\s*\)?/.ignoresCase()
        ),
            let grams = Double(match.1.replacingOccurrences(of: ",", with: ".")),
            grams.isFinite, grams > 0
        else { return nil }
        return grams
    }

    // MARK: - Add Food

    /// The heading over the contextual suggestions: "Usually at lunch".
    static func suggestionsTitle(for meal: MealType) -> String {
        switch meal {
        case .breakfast: "Usually at breakfast"
        case .lunch: "Usually at lunch"
        case .dinner: "Usually at dinner"
        case .snack: "Usually as a snack"
        }
    }

    /// The line under a saved meal's name: "Saved meal, 3 items". A meal none of whose
    /// items can be read any more says so instead.
    static func savedMealDetail(itemCount: Int) -> String {
        switch itemCount {
        case ..<1: "Unavailable meal"
        case 1: "Saved meal, 1 item"
        default: "Saved meal, \(itemCount) items"
        }
    }

    // MARK: - Portion

    /// The line under the food's name: brand, serving, and what 100 g is worth.
    /// "Arla, 1 pot 150 g, 63 kcal per 100 g". A recipe has no serving of its own, so it
    /// skips that part.
    static func portionDetail(
        brand: String?,
        servingDescription: String?,
        isRecipe: Bool,
        caloriesPer100g: Double
    ) -> String {
        var parts: [String] = []
        if let brand = brand?.trimmingCharacters(in: .whitespaces), !brand.isEmpty {
            parts.append(brand)
        }
        if !isRecipe,
           let serving = servingDescription?.trimmingCharacters(in: .whitespaces),
           !serving.isEmpty {
            parts.append(Self.serving(serving))
        }
        parts.append("\(caloriesPer100g.rounded().truncatedSafely) kcal per 100 g")
        return parts.joined(separator: ", ")
    }

    /// The Portion sheet's primary action. A new log names the meal it lands in, "Log to
    /// lunch"; editing an entry saves it wherever the meal chips now point.
    static func portionSaveTitle(isEditing: Bool, meal: MealType) -> String {
        isEditing ? "Save changes" : "Log to \(meal.displayName.lowercased())"
    }
}
