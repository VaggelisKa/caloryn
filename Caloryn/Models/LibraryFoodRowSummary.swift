import Foundation

/// What one food's row in the My Foods library says about itself: its name, where it comes
/// from and what a serving is, and the kcal figure with what it counts.
///
/// Takes the facts the row prints rather than the `FoodItem`. The figure and its caption come
/// from `FoodRowSummary`, the Add Food row's rules, so the same food reads the same on both
/// tabs: "95" over "kcal a pot" for a countable serving, "kcal a serving" for a serving
/// recorded only as a weight, "kcal per 100 g" for a food with no serving at all.
///
/// The detail line joins the brand and the serving with a comma, as the Plate vocabulary
/// writes it ("Arla, 1 pot 150 g"), never a middle dot. A serving with no description is
/// written as its weight ("250 g"), so a figure "a serving" always says what the serving
/// is. Any part can be missing; a food with none has no detail line at all.
struct LibraryFoodRowSummary: Equatable {
    let name: String
    let detail: String?
    let caloriesText: String
    let caloriesCaption: String

    init(
        name: String,
        brand: String?,
        servingDescription: String?,
        caloriesPer100g: Double,
        servingGrams: Double? = nil,
        servingUnitName: String? = nil,
        servingUnitCount: Double? = nil
    ) {
        self.name = name

        let row = FoodRowSummary(
            brand: nil,
            servingDescription: nil,
            detail: nil,
            caloriesPer100g: caloriesPer100g,
            caloriesPerServing: servingGrams.map { caloriesPer100g * $0 / 100 },
            servingUnitName: servingUnitName,
            servingUnitCount: servingUnitCount,
            isRecipe: false,
            portionCalories: nil
        )
        caloriesText = row.figure
        caloriesCaption = row.figureCaption

        let serving = Self.nonEmpty(servingDescription).map(FoodLogSheetCopy.serving)
            ?? servingGrams.flatMap(Self.weightText)
        let parts = [Self.nonEmpty(brand), serving].compactMap { $0 }
        detail = parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    private static func nonEmpty(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespaces), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private static func weightText(_ grams: Double) -> String? {
        guard grams.isFinite, grams > 0 else { return nil }
        return "\(grams.rounded().truncatedSafely) g"
    }
}

extension LibraryFoodRowSummary {
    /// The serving the Portion sheet opens on: the food's own, counted in its unit when it
    /// has one ("1 pot"), or per 100 g when it records no serving.
    init(food: FoodItem) {
        let grams = food.defaultServingG
        let info = food.servingInfo
        self.init(
            name: food.name,
            brand: food.brand,
            servingDescription: food.servingDescription,
            caloriesPer100g: food.caloriesPer100g,
            servingGrams: grams,
            servingUnitName: grams == nil ? nil : info?.unitName,
            servingUnitCount: grams.flatMap { grams in
                info.map { grams / $0.gramsPerUnit }
            }
        )
    }
}
