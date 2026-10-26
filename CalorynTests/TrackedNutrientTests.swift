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
        let us = Locale(identifier: "en_US")
        XCTAssertEqual(TrackedNutrientUnit.grams.formatted(12, locale: us), "12 g")
        XCTAssertEqual(TrackedNutrientUnit.grams.formatted(12.24, locale: us), "12.2 g")
        XCTAssertEqual(TrackedNutrientUnit.milligramsFromGrams.formatted(0.0015, locale: us), "2 mg")
        XCTAssertEqual(
            TrackedNutrientUnit.milligramsFromGrams.formatted(2.3, locale: Locale(identifier: "da_DK")),
            "2.300 mg"
        )
        XCTAssertEqual(TrackedNutrientUnit.milligramsFromGrams.inputFormatted(1.5), "1500")
        XCTAssertEqual(TrackedNutrientUnit.milligramsFromGrams.storedValue(fromInput: 1_500), 1.5)
    }

    func testSpokenFormattingSpellsTheUnitOutAndAgreesWithTheVisualNumber() {
        XCTAssertEqual(TrackedNutrientUnit.grams.spokenFormatted(66.7), "66.7 grams")
        XCTAssertEqual(TrackedNutrientUnit.grams.spokenFormatted(12), "12 grams")
        XCTAssertEqual(TrackedNutrientUnit.grams.spokenFormatted(1), "1 gram")
        XCTAssertEqual(TrackedNutrientUnit.milligramsFromGrams.spokenFormatted(0.0015), "2 milligrams")
        XCTAssertEqual(TrackedNutrientUnit.milligramsFromGrams.spokenFormatted(0.001), "1 milligram")
    }

    func testSpokenFormattingSurvivesValuesBeyondIntMax() {
        XCTAssertTrue(TrackedNutrientUnit.milligramsFromGrams.spokenFormatted(1e30).hasSuffix(" milligrams"))
        XCTAssertTrue(TrackedNutrientUnit.grams.spokenFormatted(1e30).hasSuffix(" grams"))
        XCTAssertTrue(TrackedNutrientUnit.grams.spokenFormatted(-1e30).hasSuffix(" grams"))
        XCTAssertFalse(TrackedNutrientUnit.grams.spokenFormatted(.infinity).isEmpty)
        XCTAssertFalse(TrackedNutrientUnit.grams.spokenFormatted(.nan).isEmpty)
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

        XCTAssertEqual(metric.formattedValue, "2 mg")
        XCTAssertEqual(metric.formattedTarget, "2 mg max")
        XCTAssertEqual(metric.targetSummary, "at most 2 mg")
        XCTAssertEqual(metric.progress, 1.0, accuracy: 0.001)
        XCTAssertEqual(metric.accessibilityLabel, "Sodium: 2 mg, at most 2 mg")
    }

    func testUnboundedGoalTargetsFormatWithoutTrapping() {
        let us = Locale(identifier: "en_US")
        XCTAssertEqual(
            TrackedNutrientUnit.milligramsFromGrams.formatted(1e30, locale: us),
            "\(Int.max.formatted(.number.locale(us))) mg"
        )
        XCTAssertEqual(TrackedNutrientUnit.grams.inputFormatted(1e30), "\(Int.max)")
        XCTAssertEqual(TrackedNutrientUnit.milligramsFromGrams.inputFormatted(1e30), "\(Int.max)")
    }
}
