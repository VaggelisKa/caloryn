import XCTest
@testable import Caloryn

final class RecipeLibraryRowSummaryTests: XCTestCase {
    // MARK: - Ingredient label

    /// One ingredient is one ingredient, not "1 ingredients".
    func testASingleIngredientIsCountedInTheSingular() {
        XCTAssertEqual(makeSummary(ingredientCount: 1).ingredientLabel, "1 ingredient")
    }

    func testSeveralIngredientsAreCountedInThePlural() {
        XCTAssertEqual(makeSummary(ingredientCount: 4).ingredientLabel, "4 ingredients")
    }

    /// Zero takes the plural too, so a recipe still being written reads
    /// "0 ingredients".
    func testNoIngredientsIsCountedInThePlural() {
        XCTAssertEqual(makeSummary(ingredientCount: 0).ingredientLabel, "0 ingredients")
    }

    // MARK: - Absent facts

    /// A recipe whose ingredient list was never loaded has no ingredients,
    /// which is an absence rather than an error.
    func testAMissingIngredientListCountsAsNoIngredients() {
        let summary = makeSummary(ingredientCount: nil)

        XCTAssertEqual(summary.ingredientCount, 0)
        XCTAssertEqual(summary.ingredientLabel, "0 ingredients")
    }

    /// Likewise a recipe with no recorded serving weighs nothing, so every
    /// macro scaled from it comes out at zero.
    func testAMissingServingSizeWeighsNothing() {
        let summary = makeSummary(
            servingGrams: nil,
            caloriesPer100g: 250,
            proteinPer100g: 10,
            carbsPer100g: 20,
            fatPer100g: 5
        )

        XCTAssertEqual(summary.totalGrams, 0, accuracy: 0.0001)
        XCTAssertEqual(summary.calories, 0, accuracy: 0.0001)
        XCTAssertEqual(summary.protein, 0, accuracy: 0.0001)
        XCTAssertEqual(summary.carbs, 0, accuracy: 0.0001)
        XCTAssertEqual(summary.fat, 0, accuracy: 0.0001)
    }

    // MARK: - Macros

    /// The row shows the whole recipe, so its per-100g figures are scaled to
    /// the serving the recipe actually makes.
    func testMacrosAreScaledFromPerHundredGramsToTheWholeRecipe() {
        let summary = makeSummary(
            servingGrams: 450,
            caloriesPer100g: 180,
            proteinPer100g: 8.4,
            carbsPer100g: 22,
            fatPer100g: 6
        )

        XCTAssertEqual(summary.calories, 810, accuracy: 0.0001)
        XCTAssertEqual(summary.protein, 37.8, accuracy: 0.0001)
        XCTAssertEqual(summary.carbs, 99, accuracy: 0.0001)
        XCTAssertEqual(summary.fat, 27, accuracy: 0.0001)
    }

    func testTheTrailingTotalIsRoundedToWholeCalories() {
        XCTAssertEqual(
            makeSummary(servingGrams: 250, caloriesPer100g: 180.3).caloriesText,
            "451"
        )
    }

    /// A nutrition figure that never became a number must come out as text
    /// rather than trapping.
    func testANonFiniteCalorieFigureStillRendersAsText() {
        XCTAssertEqual(
            makeSummary(servingGrams: 100, caloriesPer100g: .nan).caloriesText,
            "0"
        )
    }

    // MARK: - Detail line

    func testTheDetailLineNamesTheIngredientsWeightAndMacros() {
        let summary = makeSummary(
            servingGrams: 450,
            ingredientCount: 3,
            caloriesPer100g: 180,
            proteinPer100g: 8.4,
            carbsPer100g: 22,
            fatPer100g: 6
        )

        XCTAssertEqual(summary.detail, "3 ingredients · 450g · 37.8g P · 99g C · 27g F")
    }

    /// A recipe that weighs nothing skips the gram figure rather than claiming
    /// "0g".
    func testARecipeWithNoWeightLeavesTheGramFigureOut() {
        let summary = makeSummary(
            servingGrams: 0,
            ingredientCount: 1,
            caloriesPer100g: 180,
            proteinPer100g: 8.4,
            carbsPer100g: 22,
            fatPer100g: 6
        )

        XCTAssertEqual(summary.detail, "1 ingredient · 0g P · 0g C · 0g F")
    }

    func testARecipeWithNoRecordedServingLeavesTheGramFigureOut() {
        let summary = makeSummary(servingGrams: nil, ingredientCount: 2)

        XCTAssertEqual(summary.detail, "2 ingredients · 0g P · 0g C · 0g F")
    }

    func testTheWeightIsRoundedToWholeGrams() {
        XCTAssertEqual(makeSummary(servingGrams: 312.6).gramsText, "313g")
    }

    // MARK: - Name

    func testTheRowIsNamedAfterTheRecipe() {
        XCTAssertEqual(makeSummary(name: "Sunday chilli").name, "Sunday chilli")
    }

    // MARK: - Helpers

    private func makeSummary(
        name: String = "Recipe",
        servingGrams: Double? = 100,
        ingredientCount: Int? = 2,
        caloriesPer100g: Double = 100,
        proteinPer100g: Double = 1,
        carbsPer100g: Double = 1,
        fatPer100g: Double = 1
    ) -> RecipeLibraryRowSummary {
        RecipeLibraryRowSummary(
            name: name,
            servingGrams: servingGrams,
            ingredientCount: ingredientCount,
            caloriesPer100g: caloriesPer100g,
            proteinPer100g: proteinPer100g,
            carbsPer100g: carbsPer100g,
            fatPer100g: fatPer100g
        )
    }
}
