import XCTest
@testable import Caloryn

final class NutritionCalculatorTests: XCTestCase {
    func testBMRUsesMifflinStJeorSexOffsets() {
        XCTAssertEqual(
            NutritionCalculator.bmr(sex: .male, weightKg: 80, heightCm: 180, age: 40),
            1_730,
            accuracy: 0.001
        )
        XCTAssertEqual(
            NutritionCalculator.bmr(sex: .female, weightKg: 70, heightCm: 165, age: 30),
            1_420.25,
            accuracy: 0.001
        )
    }

    func testTDEEAppliesActivityMultiplier() {
        XCTAssertEqual(
            NutritionCalculator.tdee(bmr: 1_600, activity: .moderatelyActive),
            2_480,
            accuracy: 0.001
        )
    }

    func testMacroGramsConvertsCalorieRatioToGrams() {
        XCTAssertEqual(
            NutritionCalculator.macroGrams(calories: 2_000, ratio: 0.30, caloriesPerGram: 4),
            150,
            accuracy: 0.001
        )
        XCTAssertEqual(
            NutritionCalculator.macroGrams(calories: 2_000, ratio: 0.30, caloriesPerGram: 9),
            66.666,
            accuracy: 0.001
        )
    }

    func testDefaultTargetAppliesDeficitAndNeverDropsBelowFloor() {
        XCTAssertEqual(NutritionCalculator.defaultTarget(tdee: 2_350, deficit: 450), 1_900)
        XCTAssertEqual(NutritionCalculator.defaultTarget(tdee: 1_400, deficit: 500), 1_200)
    }
}
