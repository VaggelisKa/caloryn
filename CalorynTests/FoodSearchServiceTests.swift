import XCTest
@testable import Caloryn

@MainActor
final class FoodSearchServiceTests: XCTestCase {
    func testProductDecodingAcceptsStringNumbersBrandArraysAndServingFallbacks() throws {
        let product = try decodeProduct(
            """
            {
              "code": "123456",
              "product_name": "Protein Bar",
              "brands": ["Brand A", "Brand B"],
              "serving_size": "1 bar (50g)",
              "serving_quantity": "50",
              "quantity": "6 x 50 g",
              "nutrition_grades": "B",
              "categories_tags": ["en:snacks"],
              "nutriments": {
                "energy-kcal_100g": 220,
                "proteins_100g": 20,
                "carbohydrates_100g": 30,
                "fat_100g": 8
              }
            }
            """
        )

        XCTAssertEqual(product.id, "123456")
        XCTAssertEqual(product.brands, "Brand A, Brand B")
        XCTAssertEqual(product.servingQuantityG, 50)
        XCTAssertEqual(product.formattedServingDescription, "1 bar (50g)")
        XCTAssertEqual(product.effectiveServingInfo.defaultServingG, 50)
        XCTAssertEqual(product.effectiveServingInfo.servingDescription, "1 bar (50g)")
        XCTAssertEqual(product.caloriesPerServing ?? -1, 110, accuracy: 0.001)
    }

    func testProductServingInfoFallsBackToPackQuantityString() throws {
        let product = try decodeProduct(
            """
            {
              "code": "987654",
              "product_name": "Small Pack",
              "quantity": "1 oz (28 g)",
              "nutriments": {
                "energy-kcal_100g": 500
              }
            }
            """
        )

        XCTAssertEqual(product.effectiveServingInfo.defaultServingG, 28)
        XCTAssertEqual(product.effectiveServingInfo.servingDescription, "1 pack (28g)")
        XCTAssertEqual(product.caloriesPerServing ?? -1, 140, accuracy: 0.001)
    }

    func testCreateFoodItemMapsNutritionServingNutriscoreAndProduceKind() throws {
        let product = try decodeProduct(
            """
            {
              "code": "111",
              "product_name": "Apple Pack",
              "brands": "Fresh Farm",
              "product_quantity": "350",
              "nutrition_grades": "Z",
              "categories_tags": ["en:apples"],
              "nutriments": {
                "energy-kcal_100g": 52,
                "proteins_100g": 0.3,
                "carbohydrates_100g": 14,
                "fat_100g": 0.2,
                "fiber_100g": 2.4,
                "sugars_100g": 10.4,
                "sodium_100g": 0.001
              }
            }
            """
        )

        let food = FoodSearchService().createFoodItem(from: product)

        XCTAssertEqual(food.name, "Apple Pack")
        XCTAssertEqual(food.brand, "Fresh Farm")
        XCTAssertEqual(food.barcode, "111")
        XCTAssertEqual(food.caloriesPer100g, 52)
        XCTAssertEqual(food.proteinPer100g, 0.3)
        XCTAssertEqual(food.carbsPer100g, 14)
        XCTAssertEqual(food.fatPer100g, 0.2)
        XCTAssertEqual(food.fiberPer100g, 2.4)
        XCTAssertEqual(food.sugarsPer100g, 10.4)
        XCTAssertEqual(food.sodiumPer100g, 0.001)
        XCTAssertEqual(food.defaultServingG, 350)
        XCTAssertEqual(food.servingDescription, "1 pack (350g)")
        XCTAssertNil(food.nutriscoreGrade)
        XCTAssertEqual(food.produceKind, .fruit)
    }

    func testClearResultsCancelsSearchState() throws {
        let service = FoodSearchService()
        service.searchResults = [
            try decodeProduct(
                """
                {
                  "code": "1",
                  "product_name": "Food",
                  "nutriments": {
                    "energy-kcal_100g": 100
                  }
                }
                """
            )
        ]
        service.isSearching = true
        service.errorMessage = "Network failed"

        service.clearResults()

        XCTAssertTrue(service.searchResults.isEmpty)
        XCTAssertFalse(service.isSearching)
        XCTAssertNil(service.errorMessage)
    }

    private func decodeProduct(_ json: String) throws -> OpenFoodFactsProduct {
        try JSONDecoder().decode(OpenFoodFactsProduct.self, from: Data(json.utf8))
    }
}
