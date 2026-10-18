import Foundation

/// What one food's row in the My Foods library says about itself: its name, where it comes
/// from and what a serving is, and the kcal figure with what it counts.
///
/// Takes the facts the row prints rather than the `FoodItem`. The detail line, the figure and
/// its caption come from `FoodRowSummary`, the Add Food row's rules, so the same food reads
/// the same on both tabs: a serving is priced as itself, "95" over "kcal" beside
/// "Arla, 1 pot 150 g · per 100 g: 63 kcal", and a food with no serving falls back to
/// "kcal per 100 g". A serving with no description is written as its weight ("250 g"), so
/// the figure always says what amount it is for. Any part can be missing; a food with none
/// has no detail line at all.
struct LibraryFoodRowSummary: Equatable {
    let name: String
    let detail: String?
    /// The detail line as VoiceOver reads it.
    let detailAccessibilityLabel: String?
    let caloriesText: String
    let caloriesCaption: String

    init(
        name: String,
        brand: String?,
        servingDescription: String?,
        caloriesPer100g: Double,
        servingGrams: Double? = nil
    ) {
        self.name = name

        let row = FoodRowSummary(
            brand: brand,
            servingDescription: servingDescription,
            servingGrams: servingGrams,
            caloriesPer100g: caloriesPer100g
        )
        detail = row.subtitle
        detailAccessibilityLabel = row.subtitleAccessibilityLabel
        caloriesText = row.figure
        caloriesCaption = row.figureCaption
    }
}

extension LibraryFoodRowSummary {
    /// The serving the Portion sheet opens on: the food's own, or per 100 g when it records
    /// no serving.
    init(food: FoodItem) {
        self.init(
            name: food.name,
            brand: food.brand,
            servingDescription: food.servingDescription,
            caloriesPer100g: food.caloriesPer100g,
            servingGrams: food.defaultServingG
        )
    }
}
