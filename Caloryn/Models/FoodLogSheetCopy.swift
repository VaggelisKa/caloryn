import Foundation

enum FoodLogSheetCopy {
    static func serving(_ description: String) -> String {
        let trimmed = description.trimmingCharacters(in: .whitespaces)
        if let match = trimmed.wholeMatch(
            of: /(.*?)\s*\(\s*(\d+(?:[.,]\d+)?)\s*(g|kg|ml|cl|dl|l|oz)\s*\)/.ignoresCase()
        ) {
            let count = match.1.trimmingCharacters(in: .whitespaces)
            let weight = "\(match.2) \(match.3)"
            return count.isEmpty ? weight : "\(count) \(weight)"
        }
        if let match = trimmed.wholeMatch(of: /(\d+(?:[.,]\d+)?)\s*(g|kg|ml|cl|dl|l|oz)/.ignoresCase()) {
            return "\(match.1) \(match.2)"
        }
        return trimmed
    }

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

    static func suggestionsTitle(for meal: MealType) -> String {
        switch meal {
        case .breakfast: "Usually at breakfast"
        case .lunch: "Usually at lunch"
        case .dinner: "Usually at dinner"
        case .snack: "Usually as a snack"
        }
    }

    static func savedMealDetail(itemCount: Int) -> String {
        switch itemCount {
        case ..<1: "Unavailable meal"
        case 1: "Saved meal, 1 item"
        default: "Saved meal, \(itemCount) items"
        }
    }

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

    static func portionSaveTitle(isEditing: Bool, meal: MealType) -> String {
        isEditing ? "Save changes" : "Log to \(meal.displayName.lowercased())"
    }
}
