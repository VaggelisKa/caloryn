import XCTest
@testable import Caloryn

final class SettingsGoalSummaryTests: XCTestCase {
    // MARK: - Which rows appear

    func testOnlyNutrientsWithASavedGoalGetARow() {
        let summary = SettingsGoalSummary(
            targets: [.protein: 150, .fiber: 30],
            goalKinds: [:]
        )

        XCTAssertEqual(summary.nutrients, [.protein, .fiber])
    }

    func testRowsFollowTheCanonicalNutrientOrderNotTheDictionaryOrder() {
        let summary = SettingsGoalSummary(
            targets: [.sodium: 2.3, .protein: 150, .fat: 70, .carbs: 200],
            goalKinds: [:]
        )

        XCTAssertEqual(summary.nutrients, [.protein, .carbs, .fat, .sodium])
    }

    func testNoGoalsMeansNoRows() {
        XCTAssertTrue(SettingsGoalSummary(targets: [:], goalKinds: [:]).nutrients.isEmpty)
    }

    // MARK: - Row wording

    func testMinimumGoalReadsAsAFloor() {
        let summary = SettingsGoalSummary(targets: [.protein: 150], goalKinds: [.protein: .minimum])

        XCTAssertEqual(summary.text(for: .protein), "At least 150g")
    }

    func testTargetGoalReadsAsABareNumber() {
        let summary = SettingsGoalSummary(targets: [.carbs: 200], goalKinds: [.carbs: .target])

        XCTAssertEqual(summary.text(for: .carbs), "200g")
    }

    func testMaximumGoalReadsAsACeiling() {
        let summary = SettingsGoalSummary(targets: [.saturatedFat: 20], goalKinds: [.saturatedFat: .maximum])

        XCTAssertEqual(summary.text(for: .saturatedFat), "At most 20g")
    }

    func testMilligramNutrientsAreShownInMilligrams() {
        let summary = SettingsGoalSummary(targets: [.sodium: 2.3], goalKinds: [.sodium: .maximum])

        XCTAssertEqual(summary.text(for: .sodium), "At most 2300mg")
    }

    func testAMissingGoalKindFallsBackToTheNutrientDefault() {
        let summary = SettingsGoalSummary(targets: [.protein: 150, .sugars: 40], goalKinds: [:])

        XCTAssertEqual(summary.text(for: .protein), "At least 150g")
        XCTAssertEqual(summary.text(for: .sugars), "At most 40g")
    }

    func testANutrientWithoutAGoalReadsAsNotSet() {
        let summary = SettingsGoalSummary(targets: [:], goalKinds: [:])

        XCTAssertEqual(summary.text(for: .protein), "Not set")
    }

    // MARK: - Spoken labels

    func testSpokenLabelSpellsTheGramUnitOut() {
        let summary = SettingsGoalSummary(targets: [.protein: 150], goalKinds: [.protein: .minimum])

        XCTAssertEqual(summary.spokenText(for: .protein), "At least 150 grams")
    }

    func testSpokenLabelSpellsTheMilligramUnitOut() {
        let summary = SettingsGoalSummary(targets: [.sodium: 2.3], goalKinds: [.sodium: .maximum])

        XCTAssertEqual(summary.spokenText(for: .sodium), "At most 2300 milligrams")
    }

    func testSpokenLabelUsesTheSingularForOneUnit() {
        let summary = SettingsGoalSummary(targets: [.fiber: 1], goalKinds: [.fiber: .target])

        XCTAssertEqual(summary.spokenText(for: .fiber), "1 gram")
    }

    // MARK: - Adjustment row

    func testAdjustmentRowIsHiddenBehindAManualTarget() {
        XCTAssertFalse(SettingsGoalSummary.showsAdjustmentRow(isManualOverride: true))
        XCTAssertTrue(SettingsGoalSummary.showsAdjustmentRow(isManualOverride: false))
    }

    func testDeficitIsShownAsASubtraction() {
        XCTAssertEqual(SettingsGoalSummary.adjustmentLabel(calorieDeficit: 500), "-500 kcal")
    }

    func testSurplusIsShownAsAnAddition() {
        XCTAssertEqual(SettingsGoalSummary.adjustmentLabel(calorieDeficit: -250), "+250 kcal")
    }

    func testNoAdjustmentIsNamedMaintenance() {
        XCTAssertEqual(SettingsGoalSummary.adjustmentLabel(calorieDeficit: 0), "Maintenance")
    }

    /// The slider steps in whole 50s, so a fraction can only arrive from stored
    /// data — and it is truncated, not rounded.
    func testFractionalAdjustmentsAreTruncatedTowardZero() {
        XCTAssertEqual(SettingsGoalSummary.adjustmentLabel(calorieDeficit: 499.9), "-499 kcal")
        XCTAssertEqual(SettingsGoalSummary.adjustmentLabel(calorieDeficit: -499.9), "+499 kcal")
    }
}
