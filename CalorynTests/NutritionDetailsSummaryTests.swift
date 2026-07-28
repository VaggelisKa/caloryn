import XCTest
@testable import Caloryn

final class NutritionDetailsSummaryTests: XCTestCase {
    // MARK: - Totals

    func testTotalsAddUpAcrossEntries() {
        let summary = NutritionDetailsSummary(entries: [
            makeEntry(calories: 310, proteinG: 12, portionGrams: 80),
            makeEntry(calories: 62, proteinG: 0.4, portionGrams: 120)
        ])

        XCTAssertEqual(summary.totalCalories, 372, accuracy: 0.0001)
        XCTAssertEqual(summary.totalNutrition.proteinG, 12.4, accuracy: 0.0001)
        XCTAssertEqual(summary.totalPortionGrams, 200, accuracy: 0.0001)
        XCTAssertEqual(summary.loggedItemCount, 2)
    }

    func testAnEmptyDayTotalsToZero() {
        let summary = NutritionDetailsSummary(entries: [])

        XCTAssertEqual(summary.totalCalories, 0)
        XCTAssertEqual(summary.totalPortionGrams, 0)
        XCTAssertEqual(summary.loggedItemCount, 0)
        XCTAssertEqual(summary.totalNutrition, .zero)
    }

    /// Sub-nutrients are optional, and an entry that records one must not be
    /// erased by an entry that records nothing.
    func testOptionalSubNutrientsSurviveBeingSummedWithEntriesThatLackThem() {
        let summary = NutritionDetailsSummary(entries: [
            makeEntry(nutrition: NutritionValues(calories: 100, starchG: 12)),
            makeEntry(nutrition: NutritionValues(calories: 50))
        ])

        XCTAssertEqual(summary.totalNutrition.starchG, 12)
    }

    func testASingleLoggedItemIsCountedInTheSingular() {
        XCTAssertEqual(NutritionDetailsSummary(entries: [makeEntry()]).loggedItemsUnitText, "item")
    }

    func testNoOrManyLoggedItemsAreCountedInThePlural() {
        XCTAssertEqual(NutritionDetailsSummary(entries: []).loggedItemsUnitText, "items")
        XCTAssertEqual(
            NutritionDetailsSummary(entries: [makeEntry(), makeEntry()]).loggedItemsUnitText,
            "items"
        )
    }

    // MARK: - Calories

    func testStayingInsideTheBudgetReadsAsRemaining() {
        XCTAssertEqual(NutritionDetailsSummary.calorieAccent(isOver: false), .withinBudget)
        XCTAssertEqual(NutritionDetailsSummary.calorieSummaryLabel(isOver: false), "Remaining")
    }

    func testGoingOverTheBudgetReadsAsOver() {
        XCTAssertEqual(NutritionDetailsSummary.calorieAccent(isOver: true), .overBudget)
        XCTAssertEqual(NutritionDetailsSummary.calorieSummaryLabel(isOver: true), "Over")
    }

    /// The accent, the label and the number all come from the budget's single
    /// over/under decision, so a sub-half-calorie overshoot cannot colour the
    /// screen "over" while reporting being over by nothing.
    func testTheAccentFollowsTheBudgetsOwnRoundedDecision() {
        let budget = makeBudget(consumed: 2_000.4, staticTarget: 2_000)

        XCTAssertFalse(budget.isOver)
        XCTAssertEqual(NutritionDetailsSummary.calorieAccent(isOver: budget.isOver), .withinBudget)
        XCTAssertEqual(budget.overAmount, 0)
    }

    // MARK: - Progress

    func testProgressRunsProportionallyBetweenNothingAndTheTarget() {
        XCTAssertEqual(NutritionDetailsSummary.progressFraction(current: 500, target: 2_000), 0.25)
        XCTAssertEqual(NutritionDetailsSummary.progressFraction(current: 0, target: 2_000), 0)
    }

    func testProgressIsCappedAtAFullBar() {
        XCTAssertEqual(NutritionDetailsSummary.progressFraction(current: 4_000, target: 2_000), 1)
    }

    func testProgressNeverRunsBackwardsOrDividesByAMissingTarget() {
        XCTAssertEqual(NutritionDetailsSummary.progressFraction(current: -100, target: 2_000), 0)
        XCTAssertEqual(NutritionDetailsSummary.progressFraction(current: 500, target: 0), 0)
        XCTAssertEqual(NutritionDetailsSummary.progressFraction(current: 500, target: -2_000), 0)
    }

    // MARK: - Auto-adjust visibility

    func testTheAutoAdjustCardIsHiddenOnAPlainDayWithNoActivity() {
        XCTAssertFalse(
            NutritionDetailsSummary.showsDynamicTDEE(
                isDynamicModeRequested: false,
                activeEnergyKcal: 0,
                dynamicAdjustment: 0,
                hasActivityMessage: false
            )
        )
    }

    func testTheAutoAdjustCardShowsWhileTheModeIsOn() {
        XCTAssertTrue(
            NutritionDetailsSummary.showsDynamicTDEE(
                isDynamicModeRequested: true,
                activeEnergyKcal: 0,
                dynamicAdjustment: 0,
                hasActivityMessage: false
            )
        )
    }

    /// A day that already recorded activity, moved its target, or has something
    /// to say about why activity is missing still explains itself after the mode
    /// is switched off.
    func testTheAutoAdjustCardStillExplainsADayAfterTheModeIsSwitchedOff() {
        XCTAssertTrue(
            NutritionDetailsSummary.showsDynamicTDEE(
                isDynamicModeRequested: false,
                activeEnergyKcal: 420,
                dynamicAdjustment: 0,
                hasActivityMessage: false
            )
        )
        XCTAssertTrue(
            NutritionDetailsSummary.showsDynamicTDEE(
                isDynamicModeRequested: false,
                activeEnergyKcal: 0,
                dynamicAdjustment: -90,
                hasActivityMessage: false
            )
        )
        XCTAssertTrue(
            NutritionDetailsSummary.showsDynamicTDEE(
                isDynamicModeRequested: false,
                activeEnergyKcal: 0,
                dynamicAdjustment: 0,
                hasActivityMessage: true
            )
        )
    }

    // MARK: - Auto-adjust text

    func testTheBaselineIsADashUntilThereIsOne() {
        XCTAssertEqual(NutritionDetailsSummary.baselineText(activityBaselineKcal: nil), "-")
    }

    func testTheBaselineIsRoundedToWholeCalories() {
        XCTAssertEqual(NutritionDetailsSummary.baselineText(activityBaselineKcal: 284.6), "285 kcal")
        XCTAssertEqual(NutritionDetailsSummary.activeEnergyText(activeEnergyKcal: 430.2), "430 kcal")
    }

    func testAnIncreaseIsSignedAndAReductionIsNegated() {
        XCTAssertEqual(NutritionDetailsSummary.dynamicAdjustmentText(180), "+180 kcal")
        XCTAssertEqual(NutritionDetailsSummary.dynamicAdjustmentText(-90), "-90 kcal")
    }

    func testNoAdjustmentIsWrittenWithoutASign() {
        XCTAssertEqual(NutritionDetailsSummary.dynamicAdjustmentText(0), "0 kcal")
    }

    func testOnlyAReductionIsMuted() {
        XCTAssertTrue(NutritionDetailsSummary.isDynamicAdjustmentMuted(-1))
        XCTAssertFalse(NutritionDetailsSummary.isDynamicAdjustmentMuted(0))
        XCTAssertFalse(NutritionDetailsSummary.isDynamicAdjustmentMuted(1))
    }

    // MARK: - Status notice

    func testAnUnavailableAutoAdjustReadsAsAWarning() {
        XCTAssertEqual(
            NutritionDetailsSummary.statusNoticeStyle(for: .unavailable("No Health access")),
            .warning
        )
    }

    func testStillLearningReadsAsInformation() {
        XCTAssertEqual(
            NutritionDetailsSummary.statusNoticeStyle(for: .learning(validDays: 3, requiredDays: 7)),
            .informational
        )
    }

    func testAWorkingOrUnusedAutoAdjustReadsPlainly() {
        XCTAssertEqual(NutritionDetailsSummary.statusNoticeStyle(for: .ready), .neutral)
        XCTAssertEqual(NutritionDetailsSummary.statusNoticeStyle(for: .staticEstimate), .neutral)
    }

    // MARK: - Helpers

    private func makeEntry(
        calories: Double = 0,
        proteinG: Double = 0,
        portionGrams: Double = 0
    ) -> NutritionDetailsSummary.Entry {
        NutritionDetailsSummary.Entry(
            nutrition: NutritionValues(calories: calories, proteinG: proteinG),
            portionGrams: portionGrams
        )
    }

    private func makeEntry(
        nutrition: NutritionValues,
        portionGrams: Double = 100
    ) -> NutritionDetailsSummary.Entry {
        NutritionDetailsSummary.Entry(nutrition: nutrition, portionGrams: portionGrams)
    }

    private func makeBudget(consumed: Double, staticTarget: Int) -> ActivityCalorieBudget {
        ActivityCalorieBudget(
            consumed: consumed,
            staticTarget: staticTarget,
            bmr: 1_600,
            calorieDeficit: 0,
            activeEnergyKcal: 0,
            recentActiveEnergySamples: [],
            calculationMode: .lifestyleEstimate,
            isManualOverride: false,
            isActivityLoading: false,
            activityMessage: nil,
            date: .now
        )
    }
}
