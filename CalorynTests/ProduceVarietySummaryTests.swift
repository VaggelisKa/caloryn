import XCTest
@testable import Caloryn

@MainActor
final class ProduceVarietySummaryTests: XCTestCase {
    func testSummaryCountsUniqueFruitAndVegetablesIgnoringDuplicatesAndZeroPortions() {
        let apple = makeTestEntry(
            foodItem: makeTestFoodItem(name: "Apples", produceKind: .fruit),
            portionGrams: 100
        )
        let duplicateApple = makeTestEntry(
            foodItem: makeTestFoodItem(name: "apple", produceKind: .fruit),
            portionGrams: 50
        )
        let carrot = makeTestEntry(
            foodItem: makeTestFoodItem(name: "Carrots", produceKind: .vegetable),
            portionGrams: 80
        )
        let zeroPortionBanana = makeTestEntry(
            foodItem: makeTestFoodItem(name: "Banana", produceKind: .fruit),
            portionGrams: 0
        )
        let unclassified = makeTestEntry(
            foodItem: makeTestFoodItem(name: "Bread", produceKind: .unclassified),
            portionGrams: 100
        )

        let summary = ProduceVarietySummary(
            entries: [apple, duplicateApple, carrot, zeroPortionBanana, unclassified]
        )

        XCTAssertEqual(summary.totalCount, 2)
        XCTAssertEqual(summary.fruitCount, 1)
        XCTAssertEqual(summary.vegetableCount, 1)
        XCTAssertEqual(summary.breakdownText, "1 fruit, 1 vegetable")
        XCTAssertEqual(summary.previewText, "Apples, Carrots")
        XCTAssertEqual(summary.items.map(\.kind), [.fruit, .vegetable])
    }

    func testRecipeEntriesCountIngredientProduceInsteadOfRecipeShell() {
        let recipe = makeTestFoodItem(
            name: "Smoothie",
            produceKind: .unclassified,
            isRecipe: true
        )
        recipe.recipeIngredients = [
            RecipeIngredient(
                name: "Spinaches",
                portionGrams: 30,
                caloriesPer100g: 23,
                proteinPer100g: 2.9,
                carbsPer100g: 3.6,
                fatPer100g: 0.4,
                sortOrder: 0,
                produceKind: .vegetable
            ),
            RecipeIngredient(
                name: "Strawberries",
                portionGrams: 80,
                caloriesPer100g: 32,
                proteinPer100g: 0.7,
                carbsPer100g: 7.7,
                fatPer100g: 0.3,
                sortOrder: 1,
                produceKind: .fruit
            ),
            RecipeIngredient(
                name: "Protein Powder",
                portionGrams: 25,
                caloriesPer100g: 400,
                proteinPer100g: 80,
                carbsPer100g: 10,
                fatPer100g: 5,
                sortOrder: 2,
                produceKind: .unclassified
            )
        ]
        let entry = makeTestEntry(foodItem: recipe, portionGrams: 300)

        let summary = ProduceVarietySummary(entries: [entry])

        XCTAssertEqual(summary.totalCount, 2)
        XCTAssertEqual(summary.fruitCount, 1)
        XCTAssertEqual(summary.vegetableCount, 1)
        XCTAssertEqual(summary.items.map(\.name), ["Strawberries", "Spinaches"])
    }

    func testEmptySummaryUsesEmptyCopy() {
        let summary = ProduceVarietySummary(entries: [])

        XCTAssertEqual(summary.totalCount, 0)
        XCTAssertEqual(summary.breakdownText, "No fruit or veg logged")
        XCTAssertNil(summary.previewText)
    }
}
