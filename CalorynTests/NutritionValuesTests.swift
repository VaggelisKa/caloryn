import XCTest
@testable import Caloryn

final class NutritionValuesTests: XCTestCase {
    func testScalingPreservesMissingOptionalNutrients() {
        let values = NutritionValues(
            calories: 200,
            proteinG: 10,
            carbsG: 30,
            fatG: 6,
            fiberG: 4,
            sugarsG: nil,
            sodiumG: 0.2
        )

        let scaled = values.scaled(by: 0.5)

        XCTAssertEqual(scaled.calories, 100, accuracy: 0.001)
        XCTAssertEqual(scaled.proteinG, 5, accuracy: 0.001)
        XCTAssertNil(scaled.sugarsG)
        XCTAssertEqual(scaled.sodiumG ?? -1, 0.1, accuracy: 0.001)
    }

    func testAggregatePer100gKeepsOptionalNilOnlyWhenAllInputsAreMissing() {
        let per100g = NutritionValues.per100g(
            fromPortions: [
                NutritionValues(
                    calories: 50,
                    proteinG: 1,
                    carbsG: 10,
                    fatG: 0,
                    fiberG: 2,
                    sugarsG: nil,
                    sodiumG: nil
                ),
                NutritionValues(
                    calories: 450,
                    proteinG: 0,
                    carbsG: 0,
                    fatG: 50,
                    fiberG: 0,
                    sugarsG: 8,
                    sodiumG: nil
                )
            ],
            totalGrams: 150
        )

        XCTAssertEqual(per100g.calories, 333.333, accuracy: 0.001)
        XCTAssertEqual(per100g.fatG, 33.333, accuracy: 0.001)
        XCTAssertEqual(per100g.sugarsG ?? -1, 5.333, accuracy: 0.001)
        XCTAssertNil(per100g.sodiumG)
    }
}
