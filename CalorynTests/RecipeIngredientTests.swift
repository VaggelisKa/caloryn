import XCTest
@testable import Caloryn

@MainActor
final class RecipeIngredientTests: XCTestCase {
    func testConvenienceInitializerSnapshotsFoodItemNutritionAndProduceKind() {
        let food = makeTestFoodItem(
            name: "Carrots",
            brand: "Farm",
            caloriesPer100g: 41,
            proteinPer100g: 0.9,
            carbsPer100g: 9.6,
            fatPer100g: 0.2,
            fiberPer100g: 2.8,
            sugarsPer100g: 4.7,
            saturatedFatPer100g: 0.03,
            produceKind: .vegetable
        )

        let ingredient = RecipeIngredient(from: food, portionGrams: 150, sortOrder: 3)

        XCTAssertEqual(ingredient.name, "Carrots")
        XCTAssertEqual(ingredient.brand, "Farm")
        XCTAssertEqual(ingredient.portionGrams, 150)
        XCTAssertEqual(ingredient.sortOrder, 3)
        XCTAssertEqual(ingredient.produceKind, .vegetable)
        XCTAssertEqual(ingredient.calories, 61.5, accuracy: 0.001)
        XCTAssertEqual(ingredient.proteinG, 1.35, accuracy: 0.001)
        XCTAssertEqual(ingredient.carbsG, 14.4, accuracy: 0.001)
        XCTAssertEqual(ingredient.fatG, 0.3, accuracy: 0.001)
        XCTAssertEqual(ingredient.fiberG, 4.2, accuracy: 0.001)
        XCTAssertEqual(ingredient.sugarsG ?? -1, 7.05, accuracy: 0.001)
        XCTAssertEqual(ingredient.saturatedFatG ?? -1, 0.045, accuracy: 0.001)
    }

    func testOptionalIngredientNutrientsRemainNilWhenSourceIsMissing() {
        let ingredient = RecipeIngredient(
            name: "Water",
            portionGrams: 200,
            caloriesPer100g: 0,
            proteinPer100g: 0,
            carbsPer100g: 0,
            fatPer100g: 0,
            sortOrder: 0
        )

        XCTAssertNil(ingredient.sugarsG)
        XCTAssertNil(ingredient.sodiumG)
        XCTAssertNil(ingredient.alcoholG)
    }
}
