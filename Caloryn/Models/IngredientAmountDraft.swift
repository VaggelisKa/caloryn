import Foundation

struct IngredientAmountDraft: Equatable {
    let nutritionPer100g: NutritionValues

    var gramsText: String

    init(nutritionPer100g: NutritionValues, initialGrams: Double) {
        self.nutritionPer100g = nutritionPer100g
        gramsText = Self.fieldText(forGrams: initialGrams)
    }

    var grams: Double {
        gramsText.decimalInputValue ?? 0
    }

    var canSave: Bool {
        grams > 0
    }

    var previewNutrition: NutritionValues {
        nutritionPer100g.scaled(by: grams / 100)
    }

    var previewCalories: Double { previewNutrition.calories }
    var previewProtein: Double { previewNutrition.proteinG }
    var previewCarbs: Double { previewNutrition.carbsG }
    var previewFat: Double { previewNutrition.fatG }

    static func fieldText(forGrams value: Double) -> String {
        guard value.isFinite else { return "" }
        return value.rounded() == value ? "\(value.truncatedSafely)" : String(format: "%.1f", value)
    }
}
