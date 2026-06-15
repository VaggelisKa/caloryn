import XCTest
@testable import Caloryn

final class ActivityCalorieBudgetTests: XCTestCase {
    func testDisabledAdjustmentUsesBaseTargetOnly() {
        let budget = ActivityCalorieBudget(
            consumed: 1_800,
            baseTarget: 2_000,
            activeEnergyKcal: 500,
            isActivityAdjustmentEnabled: false,
            isActivityLoading: false,
            activityMessage: nil
        )

        XCTAssertEqual(budget.activityCredit, 500)
        XCTAssertEqual(budget.adjustedTarget, 2_000)
        XCTAssertEqual(budget.remaining, 200)
        XCTAssertEqual(budget.overAmount, 0)
        XCTAssertFalse(budget.isOver)
        XCTAssertFalse(budget.hasActivityCredit)
        XCTAssertEqual(budget.baseProgressEnd, 1, accuracy: 0.001)
    }

    func testEnabledAdjustmentCreditsAllActiveEnergyBeforeRemainingCalories() {
        let budget = ActivityCalorieBudget(
            consumed: 1_850,
            baseTarget: 2_000,
            activeEnergyKcal: 500,
            isActivityAdjustmentEnabled: true,
            isActivityLoading: false,
            activityMessage: nil
        )

        XCTAssertEqual(budget.activityCredit, 500)
        XCTAssertEqual(budget.adjustedTarget, 2_500)
        XCTAssertEqual(budget.remaining, 650)
        XCTAssertEqual(budget.overAmount, 0)
        XCTAssertFalse(budget.isOver)
        XCTAssertTrue(budget.hasActivityCredit)
        XCTAssertEqual(budget.baseProgressEnd, 2_000.0 / 2_500.0, accuracy: 0.001)
    }

    func testNegativeActiveEnergyDoesNotReduceTheDailyTarget() {
        let budget = ActivityCalorieBudget(
            consumed: 1_500,
            baseTarget: 2_000,
            activeEnergyKcal: -200,
            isActivityAdjustmentEnabled: true,
            isActivityLoading: false,
            activityMessage: nil
        )

        XCTAssertEqual(budget.activityCredit, 0)
        XCTAssertEqual(budget.adjustedTarget, 2_000)
        XCTAssertEqual(budget.remaining, 500)
        XCTAssertFalse(budget.hasActivityCredit)
        XCTAssertEqual(budget.baseProgressEnd, 1, accuracy: 0.001)
    }

    func testOverTargetMathUsesTheHealthAdjustedTarget() {
        let budget = ActivityCalorieBudget(
            consumed: 2_700,
            baseTarget: 2_000,
            activeEnergyKcal: 500,
            isActivityAdjustmentEnabled: true,
            isActivityLoading: false,
            activityMessage: nil
        )

        XCTAssertEqual(budget.adjustedTarget, 2_500)
        XCTAssertEqual(budget.remaining, 0)
        XCTAssertEqual(budget.overAmount, 200)
        XCTAssertTrue(budget.isOver)
        XCTAssertEqual(budget.displayedRingProgress, 1, accuracy: 0.001)
    }

    func testProgressCapsAtOneAndAHalfWhileDisplayedRingStopsAtOne() {
        let budget = ActivityCalorieBudget(
            consumed: 4_000,
            baseTarget: 2_000,
            activeEnergyKcal: 0,
            isActivityAdjustmentEnabled: false,
            isActivityLoading: false,
            activityMessage: nil
        )

        XCTAssertEqual(budget.progress, 1.5, accuracy: 0.001)
        XCTAssertEqual(budget.displayedRingProgress, 1, accuracy: 0.001)
        XCTAssertEqual(budget.overAmount, 2_000)
    }

    func testZeroTargetBudgetDoesNotDivideByZero() {
        let budget = ActivityCalorieBudget(
            consumed: 50,
            baseTarget: 0,
            activeEnergyKcal: 0,
            isActivityAdjustmentEnabled: false,
            isActivityLoading: false,
            activityMessage: nil
        )

        XCTAssertEqual(budget.adjustedTarget, 0)
        XCTAssertEqual(budget.remaining, 0)
        XCTAssertEqual(budget.overAmount, 50)
        XCTAssertTrue(budget.isOver)
        XCTAssertEqual(budget.progress, 0, accuracy: 0.001)
        XCTAssertEqual(budget.baseProgressEnd, 1, accuracy: 0.001)
    }

    func testHealthCreditCopyNamesTheHealthSource() {
        XCTAssertEqual(ActivityCalorieBudget.activeEnergyCreditPolicyText, "Apple Health Active Energy")
        XCTAssertEqual(ActivityCalorieBudget.activeEnergyCreditShortText, "Active Energy credit")
    }
}
