import Foundation

/// What one saved recipe's row in the My Foods library says about itself.
///
/// Takes the recipe's serving size, its ingredient count and its per-100g
/// macros rather than the `FoodItem`, because that is all the row depends on.
/// A recipe with no serving size recorded still has macros worth showing, so
/// the gram figure drops out of the detail line rather than the line reading
/// "0g".
struct RecipeLibraryRowSummary: Equatable {
    let name: String
    let totalGrams: Double
    let ingredientCount: Int
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double

    /// A recipe with no recorded serving weighs nothing, and one with no
    /// ingredient list has no ingredients — both are absences, not errors.
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

    // MARK: - Detail line

    /// One ingredient is one ingredient, not "1 ingredients".
    var ingredientLabel: String {
        ingredientCount == 1 ? "1 ingredient" : "\(ingredientCount) ingredients"
    }

    var macroLabel: String {
        "\(protein.macroFormatted) P · \(carbs.macroFormatted) C · \(fat.macroFormatted) F"
    }

    var gramsText: String {
        "\(totalGrams.rounded().truncatedSafely)g"
    }

    /// A recipe that weighs nothing skips the gram figure rather than claiming
    /// "0g".
    var detail: String {
        guard totalGrams > 0 else {
            return "\(ingredientLabel) · \(macroLabel)"
        }

        return "\(ingredientLabel) · \(gramsText) · \(macroLabel)"
    }

    // MARK: - Trailing total

    var caloriesText: String {
        "\(calories.rounded().truncatedSafely)"
    }
}

extension RecipeLibraryRowSummary {
    /// The library hands over a stored recipe; the facts it carries are the
    /// same ones the value-based initialiser wants.
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
