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

    func testSummaryPreservesProduceAfterFoodDeletionDetachesRelationship() {
        let apple = makeTestEntry(
            foodItem: makeTestFoodItem(name: "Apple", produceKind: .fruit),
            portionGrams: 100
        )
        let carrot = makeTestEntry(
            foodItem: makeTestFoodItem(name: "Carrot", produceKind: .vegetable),
            portionGrams: 80
        )

        // Deleting a saved food detaches the relationship while keeping the entry.
        apple.foodItem = nil
        carrot.foodItem = nil

        let summary = ProduceVarietySummary(entries: [apple, carrot])

        XCTAssertEqual(summary.totalCount, 2)
        XCTAssertEqual(summary.fruitCount, 1)
        XCTAssertEqual(summary.vegetableCount, 1)
        XCTAssertEqual(summary.items.map(\.name), ["Apple", "Carrot"])
    }

    func testSummaryIgnoresRetroactiveFoodEdits() {
        let food = makeTestFoodItem(name: "Apple", produceKind: .fruit)
        let entry = makeTestEntry(foodItem: food, portionGrams: 100)

        food.produceKind = .unclassified
        food.name = "Apple Pie"

        let summary = ProduceVarietySummary(entries: [entry])

        XCTAssertEqual(summary.totalCount, 1)
        XCTAssertEqual(summary.fruitCount, 1)
        XCTAssertEqual(summary.items.map(\.name), ["Apple"])
    }

    func testRecipeEntryPreservesIngredientProduceAfterRecipeEditAndDeletion() {
        let recipe = makeTestFoodItem(
            name: "Smoothie",
            produceKind: .unclassified,
            isRecipe: true
        )
        recipe.recipeIngredients = [
            RecipeIngredient(
                name: "Spinach",
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
            )
        ]
        let editedEntry = makeTestEntry(foodItem: recipe, portionGrams: 110)
        let deletedEntry = makeTestEntry(foodItem: recipe, portionGrams: 110)

        // Later the recipe's ingredients change and the recipe itself is deleted.
        recipe.recipeIngredients = []
        deletedEntry.foodItem = nil

        let editedSummary = ProduceVarietySummary(entries: [editedEntry])
        let deletedSummary = ProduceVarietySummary(entries: [deletedEntry])

        XCTAssertEqual(editedSummary.fruitCount, 1)
        XCTAssertEqual(editedSummary.vegetableCount, 1)
        XCTAssertEqual(deletedSummary.fruitCount, 1)
        XCTAssertEqual(deletedSummary.vegetableCount, 1)
    }

    func testLegacyEntryWithoutSnapshotFallsBackToLiveRelationship() {
        let food = makeTestFoodItem(name: "Apple", produceKind: .fruit)
        let legacyEntry = makeLegacyTestEntry(foodItem: food, portionGrams: 100)

        let summary = ProduceVarietySummary(entries: [legacyEntry])

        XCTAssertEqual(summary.totalCount, 1)
        XCTAssertEqual(summary.fruitCount, 1)
    }

    func testLegacyEntryWithDetachedFoodContributesNothing() {
        let legacyEntry = makeLegacyTestEntry(
            foodItem: makeTestFoodItem(name: "Apple", produceKind: .fruit),
            portionGrams: 100
        )
        legacyEntry.foodItem = nil

        let summary = ProduceVarietySummary(entries: [legacyEntry])

        // Legacy entries never captured quality data; once the saved food is
        // gone we surface nothing rather than fabricating a classification.
        XCTAssertEqual(summary.totalCount, 0)
    }

    func testEmptySummaryUsesEmptyCopy() {
        let summary = ProduceVarietySummary(entries: [])

        XCTAssertEqual(summary.totalCount, 0)
        XCTAssertEqual(summary.breakdownText, "No fruit or veg logged")
        XCTAssertNil(summary.previewText)
    }
}
