import XCTest
@testable import Caloryn

final class CalorieRingSummaryTests: XCTestCase {
    // MARK: - The figure in the centre

    func testAnUnderBudgetDayCountsDownWhatIsLeft() {
        let summary = makeSummary(isOver: false, remaining: 480, roundedConsumed: 1_520)

        XCTAssertEqual(summary.centerValue, 480)
        XCTAssertEqual(summary.centerCaption, "remaining")
        XCTAssertEqual(summary.eatenText, "1520 eaten")
    }

    func testAnOverBudgetDayCountsUpTheOvershoot() {
        let summary = makeSummary(isOver: true, overAmount: 130, roundedConsumed: 2_130)

        XCTAssertEqual(summary.centerValue, 130)
        XCTAssertEqual(summary.centerCaption, "over")
        XCTAssertEqual(summary.eatenText, "2130 eaten")
    }

    /// The ring shares the sheet's accent so one day cannot read as over on one
    /// screen and within budget on the other.
    func testTheAccentIsTheSameDecisionTheNutritionSheetMakes() {
        XCTAssertEqual(makeSummary(isOver: false).accent, .withinBudget)
        XCTAssertEqual(makeSummary(isOver: true).accent, .overBudget)
        XCTAssertEqual(
            makeSummary(isOver: true).accent,
            NutritionDetailsSummary.calorieAccent(isOver: true)
        )
    }

    // MARK: - The auto-adjust cue

    func testAQuietDayShowsNoCue() {
        XCTAssertEqual(makeSummary().cue, .none)
        XCTAssertNil(makeSummary().cue.text)
        XCTAssertNil(makeSummary().cue.accessibilityLabel)
    }

    func testAnAddedAllowanceIsShownAsASignedIncrease() {
        let cue = makeSummary(dynamicIncrease: 180, dynamicAdjustment: 180, hasDynamicIncrease: true).cue

        XCTAssertEqual(cue, .increase(180))
        XCTAssertEqual(cue.text, "+180 dynamic")
        XCTAssertEqual(cue.accessibilityLabel, "180 calorie auto-adjust increase")
    }

    func testAReductionCarriesItsOwnMinusSign() {
        let cue = makeSummary(dynamicAdjustment: -90, hasDynamicReduction: true).cue

        XCTAssertEqual(cue, .reduction(-90))
        XCTAssertEqual(cue.text, "-90 dynamic")
        XCTAssertEqual(cue.accessibilityLabel, "90 calorie auto-adjust reduction")
    }

    /// While activity is still being read the adjustment on screen belongs to
    /// the previous answer, so loading has to win over it.
    func testLoadingActivityWinsOverAnAdjustmentStillOnScreen() {
        let summary = makeSummary(
            dynamicIncrease: 180,
            dynamicAdjustment: 180,
            hasDynamicIncrease: true,
            isActivityLoading: true
        )

        XCTAssertEqual(summary.cue, .updating)
        XCTAssertEqual(summary.cue.text, "updating")
    }

    func testTheLoadingCueLeavesTheSpinnerToAnnounceItself() {
        XCTAssertNil(makeSummary(isActivityLoading: true).cue.accessibilityLabel)
    }

    // MARK: - VoiceOver

    func testTheLabelReadsWhatIsLeftAgainstTheTarget() {
        let summary = makeSummary(
            isOver: false,
            remaining: 480,
            roundedConsumed: 1_520,
            adjustedTarget: 2_000
        )

        XCTAssertEqual(
            summary.accessibilityLabel,
            "Calorie ring, 480 remaining of 2000 calories, 1520 eaten"
        )
        XCTAssertEqual(summary.accessibilityValue, "1520 eaten, 480 remaining of 2000")
    }

    func testTheLabelReadsTheOvershootAgainstTheTarget() {
        let summary = makeSummary(
            isOver: true,
            overAmount: 130,
            roundedConsumed: 2_130,
            adjustedTarget: 2_000
        )

        XCTAssertEqual(
            summary.accessibilityLabel,
            "Calorie ring, 2130 eaten, 130 calories over a 2000 calorie goal"
        )
        XCTAssertEqual(summary.accessibilityValue, "2130 eaten, 130 calories over target of 2000")
    }

    /// A target that moved has to be explained, or the number read out looks
    /// wrong against the goal the user set.
    func testAnAddedAllowanceIsExplainedInTheLabel() {
        let summary = makeSummary(
            isOver: false,
            remaining: 660,
            roundedConsumed: 1_520,
            adjustedTarget: 2_180,
            dynamicIncrease: 180,
            hasDynamicIncrease: true
        )

        XCTAssertTrue(summary.accessibilityLabel.hasSuffix(", includes 180 calorie auto-adjust increase"))
    }

    /// A reduction is not called out: the label would otherwise read as an
    /// accusation every time the day was quiet.
    func testAReductionIsNotSpelledOutInTheLabel() {
        let summary = makeSummary(dynamicAdjustment: -90, hasDynamicReduction: true)

        XCTAssertFalse(summary.accessibilityLabel.contains("auto-adjust"))
    }

    func testTheHintIsSilentWhenTheRingDoesNothing() {
        XCTAssertEqual(CalorieRingSummary.accessibilityHint(isInteractive: false), "")
        XCTAssertEqual(
            CalorieRingSummary.accessibilityHint(isInteractive: true),
            "Tap or long press to show nutrition details."
        )
    }

    // MARK: - Reading the budget

    /// Everything the ring says is the budget's answer, not a second derivation
    /// of it.
    func testTheBudgetsFiguresAreTakenAsGiven() {
        let budget = ActivityCalorieBudget(
            consumed: 2_130,
            staticTarget: 2_000,
            bmr: 1_700,
            calorieDeficit: 500,
            activeEnergyKcal: 0,
            recentActiveEnergySamples: [],
            calculationMode: .lifestyleEstimate,
            isManualOverride: false,
            isActivityLoading: false,
            activityMessage: nil,
            date: .now
        )
        let summary = CalorieRingSummary(budget: budget)

        XCTAssertEqual(summary.isOver, budget.isOver)
        XCTAssertEqual(summary.centerValue, budget.overAmount)
        XCTAssertEqual(summary.adjustedTarget, budget.adjustedTarget)
        XCTAssertEqual(summary.roundedConsumed, budget.roundedConsumed)
    }

    // MARK: - Helpers

    private func makeSummary(
        isOver: Bool = false,
        remaining: Int = 500,
        overAmount: Int = 0,
        roundedConsumed: Int = 1_500,
        adjustedTarget: Int = 2_000,
        dynamicIncrease: Int = 0,
        dynamicAdjustment: Int = 0,
        hasDynamicIncrease: Bool = false,
        hasDynamicReduction: Bool = false,
        isActivityLoading: Bool = false
    ) -> CalorieRingSummary {
        CalorieRingSummary(
            isOver: isOver,
            remaining: remaining,
            overAmount: overAmount,
            roundedConsumed: roundedConsumed,
            adjustedTarget: adjustedTarget,
            dynamicIncrease: dynamicIncrease,
            dynamicAdjustment: dynamicAdjustment,
            hasDynamicIncrease: hasDynamicIncrease,
            hasDynamicReduction: hasDynamicReduction,
            isActivityLoading: isActivityLoading
        )
    }
}
