import Foundation

struct RecipeLibraryRowSummary: Equatable {
    let name: String
    let totalGrams: Double
    let ingredientCount: Int
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double

    init(
        name: String,
        servingGrams: Double?,
        ingredientCount: Int?,
        caloriesPer100g: Double,
        proteinPer100g: Double,
        carbsPer100g: Double,
        fatPer100g: Double
    ) {
        self.name = name
        let grams = servingGrams ?? 0
        totalGrams = grams
        self.ingredientCount = ingredientCount ?? 0
        calories = caloriesPer100g * grams / 100
        protein = proteinPer100g * grams / 100
        carbs = carbsPer100g * grams / 100
        fat = fatPer100g * grams / 100
    }

    var ingredientLabel: String {
        ingredientCount == 1 ? "1 ingredient" : "\(ingredientCount) ingredients"
    }

    var gramsText: String {
        "\(totalGrams.rounded().truncatedSafely) g"
    }

    var detail: String {
        guard totalGrams > 0 else {
            return ingredientLabel
        }

        return "\(ingredientLabel), \(gramsText)"
    }

    var caloriesText: String {
        "\(calories.rounded().truncatedSafely)"
    }
}

extension RecipeLibraryRowSummary {
    init(recipe: FoodItem) {
        self.init(
            name: recipe.name,
            servingGrams: recipe.defaultServingG,
            ingredientCount: recipe.recipeIngredients?.count,
            caloriesPer100g: recipe.caloriesPer100g,
            proteinPer100g: recipe.proteinPer100g,
            carbsPer100g: recipe.carbsPer100g,
            fatPer100g: recipe.fatPer100g
        )
    }
}
