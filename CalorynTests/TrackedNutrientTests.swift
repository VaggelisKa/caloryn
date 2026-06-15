import XCTest
@testable import Caloryn

@MainActor
final class TrackedNutrientTests: XCTestCase {
    func testSelectedNutrientsRemoveDuplicatesAndPadToMinimumSelection() {
        XCTAssertEqual(
            TrackedNutrient.selected(from: "fiber,fiber"),
            [.fiber, .protein, .carbs]
        )
        XCTAssertEqual(
            TrackedNutrient.selected(from: ""),
            [.protein, .carbs, .fat]
        )
    }

    func testRawSelectionPreservesGivenOrder() {
        XCTAssertEqual(
            TrackedNutrient.rawSelection(from: [.fat, .protein, .sodium]),
            "fat,protein,sodium"
        )
    }

    func testUnitFormattingConvertsStoredGramValuesToMilligramInputs() {
        XCTAssertEqual(TrackedNutrientUnit.grams.formatted(12), "12g")
        XCTAssertEqual(TrackedNutrientUnit.grams.formatted(12.25), "12.2g")
        XCTAssertEqual(TrackedNutrientUnit.milligramsFromGrams.formatted(0.0015), "2mg")
        XCTAssertEqual(TrackedNutrientUnit.milligramsFromGrams.inputFormatted(1.5), "1500")
        XCTAssertEqual(TrackedNutrientUnit.milligramsFromGrams.storedValue(fromInput: 1_500), 1.5)
    }

    func testNutrientValuesSumRequiredAndOptionalEntryValues() {
        let first = makeTestEntry(
            foodItem: makeTestFoodItem(
                proteinPer100g: 10,
                carbsPer100g: 20,
                fatPer100g: 5,
                fiberPer100g: 3,
                sugarsPer100g: 4,
                sodiumPer100g: 0.1
            ),
            portionGrams: 100
        )
        let second = makeTestEntry(
            foodItem: makeTestFoodItem(
                proteinPer100g: 5,
                carbsPer100g: 10,
                fatPer100g: 2,
                fiberPer100g: 1,
                sugarsPer100g: nil,
                sodiumPer100g: 0.05
            ),
            portionGrams: 200
        )

        XCTAssertEqual(TrackedNutrient.protein.value(in: [first, second]), 20, accuracy: 0.001)
        XCTAssertEqual(TrackedNutrient.carbs.value(in: [first, second]), 40, accuracy: 0.001)
        XCTAssertEqual(TrackedNutrient.fat.value(in: [first, second]), 9, accuracy: 0.001)
        XCTAssertEqual(TrackedNutrient.fiber.value(in: [first, second]), 5, accuracy: 0.001)
        XCTAssertEqual(TrackedNutrient.sugars.value(in: [first, second]), 4, accuracy: 0.001)
        XCTAssertEqual(TrackedNutrient.sodium.value(in: [first, second]), 0.2, accuracy: 0.001)
    }

    func testTrackedNutrientMetricFormatsTargetSummaryAndProgress() {
        let metric = TrackedNutrientMetric(
            nutrient: .sodium,
            value: 0.002,
            target: 0.0015,
            goalKind: .maximum
        )

        XCTAssertEqual(metric.formattedValue, "2mg")
        XCTAssertEqual(metric.formattedTarget, "2mg max")
        XCTAssertEqual(metric.targetSummary, "at most 2mg")
        XCTAssertEqual(metric.progress, 1.0, accuracy: 0.001)
        XCTAssertEqual(metric.accessibilityLabel, "Sodium: 2mg, at most 2mg")
    }
}
