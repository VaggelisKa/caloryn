import XCTest
@testable import Caloryn

final class RecipeLibraryRowSummaryTests: XCTestCase {
    func testASingleIngredientIsCountedInTheSingular() {
        XCTAssertEqual(makeSummary(ingredientCount: 1).ingredientLabel, "1 ingredient")
    }

    func testSeveralIngredientsAreCountedInThePlural() {
        XCTAssertEqual(makeSummary(ingredientCount: 4).ingredientLabel, "4 ingredients")
    }

    func testNoIngredientsIsCountedInThePlural() {
        XCTAssertEqual(makeSummary(ingredientCount: 0).ingredientLabel, "0 ingredients")
    }

    func testAMissingIngredientListCountsAsNoIngredients() {
        let summary = makeSummary(ingredientCount: nil)

        XCTAssertEqual(summary.ingredientCount, 0)
        XCTAssertEqual(summary.ingredientLabel, "0 ingredients")
    }

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

    func testANonFiniteCalorieFigureStillRendersAsText() {
        XCTAssertEqual(
            makeSummary(servingGrams: 100, caloriesPer100g: .nan).caloriesText,
            "0"
        )
    }

    func testTheDetailLineNamesTheIngredientsAndWeight() {
        let summary = makeSummary(
            servingGrams: 450,
            ingredientCount: 3,
            caloriesPer100g: 180,
            proteinPer100g: 8.4,
            carbsPer100g: 22,
            fatPer100g: 6
        )

        XCTAssertEqual(summary.detail, "3 ingredients, 450 g")
    }

    func testARecipeWithNoWeightLeavesTheGramFigureOut() {
        let summary = makeSummary(
            servingGrams: 0,
            ingredientCount: 1,
            caloriesPer100g: 180,
            proteinPer100g: 8.4,
            carbsPer100g: 22,
            fatPer100g: 6
        )

        XCTAssertEqual(summary.detail, "1 ingredient")
    }

    func testARecipeWithNoRecordedServingLeavesTheGramFigureOut() {
        let summary = makeSummary(servingGrams: nil, ingredientCount: 2)

        XCTAssertEqual(summary.detail, "2 ingredients")
    }

    func testTheWeightIsRoundedToWholeGrams() {
        XCTAssertEqual(makeSummary(servingGrams: 312.6).gramsText, "313 g")
    }

    func testTheRowIsNamedAfterTheRecipe() {
        XCTAssertEqual(makeSummary(name: "Sunday chilli").name, "Sunday chilli")
    }

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
