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

        XCTAssertEqual(summary.text(for: .protein), "At least 150 g")
    }

    func testTargetGoalReadsAsABareNumber() {
        let summary = SettingsGoalSummary(targets: [.carbs: 200], goalKinds: [.carbs: .target])

        XCTAssertEqual(summary.text(for: .carbs), "200 g")
    }

    func testMaximumGoalReadsAsACeiling() {
        let summary = SettingsGoalSummary(targets: [.saturatedFat: 20], goalKinds: [.saturatedFat: .maximum])

        XCTAssertEqual(summary.text(for: .saturatedFat), "At most 20 g")
    }

    func testMilligramNutrientsAreShownInMilligrams() {
        let summary = SettingsGoalSummary(targets: [.sodium: 2.3], goalKinds: [.sodium: .maximum])

        XCTAssertEqual(summary.text(for: .sodium, locale: Locale(identifier: "da_DK")), "At most 2.300 mg")
        XCTAssertEqual(summary.text(for: .sodium, locale: Locale(identifier: "en_US")), "At most 2,300 mg")
    }

    func testAMissingGoalKindFallsBackToTheNutrientDefault() {
        let summary = SettingsGoalSummary(targets: [.protein: 150, .sugars: 40], goalKinds: [:])

        XCTAssertEqual(summary.text(for: .protein), "At least 150 g")
        XCTAssertEqual(summary.text(for: .sugars), "At most 40 g")
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

    // MARK: - Headline

    func testTheHeadlineGroupsTheDailyTargetForTheLocale() {
        XCTAssertEqual(
            SettingsGoalSummary.dailyTargetText(2400, locale: Locale(identifier: "da_DK")),
            "2.400 kcal a day"
        )
        XCTAssertEqual(
            SettingsGoalSummary.dailyTargetText(2400, locale: Locale(identifier: "en_US")),
            "2,400 kcal a day"
        )
        XCTAssertEqual(
            SettingsGoalSummary.dailyTargetText(950, locale: Locale(identifier: "en_US")),
            "950 kcal a day"
        )
    }

    // MARK: - Where the number comes from

    /// A manual target is not derived from a deficit, so there is no adjustment to name.
    func testAManualTargetNamesNoAdjustment() {
        XCTAssertEqual(
            SettingsGoalSummary.goalSubtitle(calorieDeficit: 500, isManualOverride: true),
            "A number you set yourself"
        )
    }

    func testADeficitIsSaidAsUnderTheBurn() {
        XCTAssertEqual(
            SettingsGoalSummary.goalSubtitle(calorieDeficit: 500, isManualOverride: false),
            "About 500 under what you burn"
        )
    }

    func testASurplusIsSaidAsOverTheBurn() {
        XCTAssertEqual(
            SettingsGoalSummary.goalSubtitle(calorieDeficit: -250, isManualOverride: false),
            "About 250 over what you burn"
        )
    }

    func testNoAdjustmentIsSaidAsTheBurnItself() {
        XCTAssertEqual(
            SettingsGoalSummary.goalSubtitle(calorieDeficit: 0, isManualOverride: false),
            "About what you burn"
        )
    }

    /// The slider steps in whole 50s, so a fraction can only arrive from stored
    /// data — and it is truncated, not rounded.
    func testFractionalAdjustmentsAreTruncatedTowardZero() {
        XCTAssertEqual(
            SettingsGoalSummary.goalSubtitle(calorieDeficit: 499.9, isManualOverride: false),
            "About 499 under what you burn"
        )
        XCTAssertEqual(
            SettingsGoalSummary.goalSubtitle(calorieDeficit: -499.9, isManualOverride: false),
            "About 499 over what you burn"
        )
    }

    /// Under one kcal truncates to nothing, which is no adjustment rather than "About 0 under".
    func testASubCalorieAdjustmentIsNoAdjustment() {
        XCTAssertEqual(
            SettingsGoalSummary.goalSubtitle(calorieDeficit: 0.4, isManualOverride: false),
            "About what you burn"
        )
    }
}
