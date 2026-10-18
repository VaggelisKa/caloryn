import Foundation

struct LibraryFoodRowSummary: Equatable {
    let name: String
    let detail: String?
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
