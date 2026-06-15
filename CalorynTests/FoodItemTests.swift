import XCTest
@testable import Caloryn

@MainActor
final class FoodItemTests: XCTestCase {
    func testCategoryTagsAreNormalizedAndInferProduceKind() {
        let food = makeTestFoodItem(
            categoryTags: [" EN:Apples ", "", "en:Fresh-Fruits"]
        )

        XCTAssertEqual(food.categoryTags, ["en:apples", "en:fresh-fruits"])
        XCTAssertEqual(food.produceKind, .fruit)
    }

    func testProcessedProduceCategoriesDoNotCountTowardVariety() {
        let food = makeTestFoodItem(
            categoryTags: ["en:vegetables", "en:soups"]
        )

        XCTAssertEqual(food.produceKind, .unclassified)
    }

    func testExplicitProduceKindOverridesCategoryInference() {
        let food = makeTestFoodItem(
            categoryTags: ["en:fruit-juices"],
            produceKind: .vegetable
        )

        XCTAssertEqual(food.produceKind, .vegetable)
    }

    func testNutritionScalesLinearlyByPortionGrams() {
        let food = makeTestFoodItem(
            caloriesPer100g: 240,
            proteinPer100g: 12,
            carbsPer100g: 30,
            fatPer100g: 8,
            fiberPer100g: 5,
            sugarsPer100g: 6,
            addedSugarsPer100g: 2,
            saturatedFatPer100g: 3,
            sodiumPer100g: 0.4
        )

        XCTAssertEqual(food.calories(forGrams: 75), 180, accuracy: 0.001)
        XCTAssertEqual(food.protein(forGrams: 75), 9, accuracy: 0.001)
        XCTAssertEqual(food.carbs(forGrams: 75), 22.5, accuracy: 0.001)
        XCTAssertEqual(food.fat(forGrams: 75), 6, accuracy: 0.001)
        XCTAssertEqual(food.fiber(forGrams: 75), 3.75, accuracy: 0.001)
        XCTAssertEqual(food.sugars(forGrams: 75) ?? -1, 4.5, accuracy: 0.001)
        XCTAssertEqual(food.addedSugars(forGrams: 75) ?? -1, 1.5, accuracy: 0.001)
        XCTAssertEqual(food.saturatedFat(forGrams: 75) ?? -1, 2.25, accuracy: 0.001)
        XCTAssertEqual(food.sodium(forGrams: 75) ?? -1, 0.3, accuracy: 0.001)
    }

    func testServingInfoParsesCountBasedServingDescriptions() throws {
        let food = makeTestFoodItem(
            defaultServingG: 100,
            servingDescription: "2 bars (100g)"
        )

        let servingInfo = try XCTUnwrap(food.servingInfo)
        XCTAssertEqual(servingInfo.unitName, "bar")
        XCTAssertEqual(servingInfo.pluralName, "bars")
        XCTAssertEqual(servingInfo.gramsPerUnit, 50, accuracy: 0.001)
        XCTAssertEqual(servingInfo.label(for: 1), "1 bar")
        XCTAssertEqual(servingInfo.label(for: 3), "3 bars")
    }

    func testServingInfoRejectsPlainWeightUnits() {
        let food = makeTestFoodItem(
            defaultServingG: 100,
            servingDescription: "100 g"
        )

        XCTAssertNil(food.servingInfo)
    }

    func testRecipeNutritionAggregatesIngredientWeightsPer100g() {
        let recipe = makeTestFoodItem(
            name: "Fruit Bowl",
            caloriesPer100g: 0,
            proteinPer100g: 0,
            carbsPer100g: 0,
            fatPer100g: 0,
            isCustom: true
        )
        recipe.recipeIngredients = [
            RecipeIngredient(
                name: "Apple",
                portionGrams: 100,
                caloriesPer100g: 50,
                proteinPer100g: 1,
                carbsPer100g: 10,
                fatPer100g: 0,
                fiberPer100g: 2,
                sugarsPer100g: 8,
                sortOrder: 0,
                produceKind: .fruit
            ),
            RecipeIngredient(
                name: "Nut Butter",
                portionGrams: 50,
                caloriesPer100g: 900,
                proteinPer100g: 0,
                carbsPer100g: 0,
                fatPer100g: 100,
                saturatedFatPer100g: 20,
                sortOrder: 1
            )
        ]

        recipe.updateRecipeNutritionFromIngredients()

        XCTAssertEqual(recipe.caloriesPer100g, 333.333, accuracy: 0.001)
        XCTAssertEqual(recipe.proteinPer100g, 0.666, accuracy: 0.001)
        XCTAssertEqual(recipe.carbsPer100g, 6.666, accuracy: 0.001)
        XCTAssertEqual(recipe.fatPer100g, 33.333, accuracy: 0.001)
        XCTAssertEqual(recipe.fiberPer100g, 1.333, accuracy: 0.001)
        XCTAssertEqual(recipe.sugarsPer100g ?? -1, 5.333, accuracy: 0.001)
        XCTAssertEqual(recipe.saturatedFatPer100g ?? -1, 6.666, accuracy: 0.001)
        XCTAssertNil(recipe.sodiumPer100g)
        XCTAssertEqual(recipe.defaultServingG, 150)
        XCTAssertTrue(recipe.isRecipe)
        XCTAssertFalse(recipe.isCustom)
        XCTAssertEqual(recipe.produceKind, .unclassified)
    }

    func testEmptyRecipeClearsNutritionAndServingMetadata() {
        let recipe = makeTestFoodItem(
            caloriesPer100g: 100,
            proteinPer100g: 10,
            carbsPer100g: 20,
            fatPer100g: 5,
            sugarsPer100g: 12,
            defaultServingG: 200,
            servingDescription: "1 bowl",
            categoryTags: ["en:apples"],
            isRecipe: true
        )
        recipe.recipeIngredients = []

        recipe.updateRecipeNutritionFromIngredients()

        XCTAssertEqual(recipe.caloriesPer100g, 0)
        XCTAssertEqual(recipe.proteinPer100g, 0)
        XCTAssertEqual(recipe.carbsPer100g, 0)
        XCTAssertEqual(recipe.fatPer100g, 0)
        XCTAssertNil(recipe.sugarsPer100g)
        XCTAssertNil(recipe.defaultServingG)
        XCTAssertNil(recipe.servingDescription)
        XCTAssertEqual(recipe.categoryTags, [])
        XCTAssertEqual(recipe.produceKind, .unclassified)
    }
}
