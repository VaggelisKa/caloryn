import XCTest
@testable import Caloryn

final class ActivityCalorieBudgetTests: XCTestCase {
    func testLifestyleEstimateUsesTheStaticTargetOnly() {
        let budget = makeBudget(
            staticTarget: 2_000,
            activeEnergyKcal: 600,
            samples: baselineSamples(kcal: 300),
            mode: .lifestyleEstimate
        )

        XCTAssertEqual(budget.dynamicStatus, .staticEstimate)
        XCTAssertEqual(budget.baseTarget, 2_000)
        XCTAssertEqual(budget.adjustedTarget, 2_000)
        XCTAssertEqual(budget.dynamicAdjustment, 0)
        XCTAssertFalse(budget.hasDynamicIncrease)
        XCTAssertEqual(budget.baseProgressEnd, 1, accuracy: 0.001)
    }

    func testDynamicModeFallsBackWhileLearningFromTooFewValidDays() {
        let budget = makeBudget(
            staticTarget: 2_000,
            activeEnergyKcal: 600,
            samples: baselineSamples(kcal: 300, count: 4),
            mode: .dynamicHealth
        )

        XCTAssertEqual(budget.dynamicStatus, .learning(validDays: 4, requiredDays: 7))
        XCTAssertEqual(budget.baseTarget, 2_000)
        XCTAssertEqual(budget.adjustedTarget, 2_000)
        XCTAssertNil(budget.activityBaselineKcal)
        XCTAssertEqual(budget.dynamicStatusText, "Needs 7 active days to learn your baseline. 4 found so far.")
    }

    func testDynamicModeUsesMedianActiveEnergyBaselineAndThermicEffect() {
        let samples = baselineSamples(kcalValues: [200, 240, 260, 280, 300, 320, 340])
        let budget = makeBudget(
            staticTarget: 2_000,
            bmr: 1_600,
            calorieDeficit: 300,
            activeEnergyKcal: 280,
            samples: samples,
            mode: .dynamicHealth
        )

        XCTAssertEqual(budget.dynamicStatus, .ready)
        XCTAssertEqual(budget.activityBaselineKcal ?? 0, 280, accuracy: 0.001)
        XCTAssertEqual(budget.baseTarget, 1_740)
        XCTAssertEqual(budget.adjustedTarget, 1_740)
    }

    func testTodayOnlyAddsCaloriesAfterBeatingTheActivityBaseline() {
        let budget = makeBudget(
            activeEnergyKcal: 500,
            samples: baselineSamples(kcal: 300),
            mode: .dynamicHealth,
            date: .now
        )

        XCTAssertEqual(budget.dynamicAdjustment, 200)
        XCTAssertEqual(budget.dynamicIncrease, 200)
        XCTAssertTrue(budget.hasDynamicIncrease)
        XCTAssertEqual(budget.adjustedTarget, budget.baseTarget + 200)
    }

    func testTodayDoesNotReduceCaloriesBeforeBaselineIsReached() {
        let budget = makeBudget(
            activeEnergyKcal: 100,
            samples: baselineSamples(kcal: 300),
            mode: .dynamicHealth,
            date: .now
        )

        XCTAssertEqual(budget.dynamicAdjustment, 0)
        XCTAssertFalse(budget.hasDynamicReduction)
        XCTAssertEqual(budget.adjustedTarget, budget.baseTarget)
    }

    func testCompletedPastDaysCanReduceTheDynamicTarget() {
        let date = makeTestDate(year: 2026, month: 2, day: 14)
        let budget = makeBudget(
            activeEnergyKcal: 100,
            samples: baselineSamples(kcal: 300, before: date),
            mode: .dynamicHealth,
            date: date
        )

        XCTAssertEqual(budget.dynamicAdjustment, -200)
        XCTAssertTrue(budget.hasDynamicReduction)
        XCTAssertEqual(budget.adjustedTarget, budget.baseTarget - 200)
    }

    func testDynamicAdjustmentIsClamped() {
        let highBudget = makeBudget(
            activeEnergyKcal: 1_200,
            samples: baselineSamples(kcal: 300),
            mode: .dynamicHealth,
            date: .now
        )
        XCTAssertEqual(highBudget.dynamicAdjustment, 600)

        let pastDate = makeTestDate(year: 2026, month: 2, day: 14)
        let lowBudget = makeBudget(
            activeEnergyKcal: 0,
            samples: baselineSamples(kcal: 700, before: pastDate),
            mode: .dynamicHealth,
            date: pastDate
        )
        XCTAssertEqual(lowBudget.dynamicAdjustment, -300)
    }

    func testAdjustedTargetDoesNotFallBelowMinimumTarget() {
        let pastDate = makeTestDate(year: 2026, month: 2, day: 14)
        let budget = makeBudget(
            staticTarget: 1_200,
            bmr: 1_100,
            calorieDeficit: 500,
            activeEnergyKcal: 0,
            samples: baselineSamples(kcal: 300, before: pastDate),
            mode: .dynamicHealth,
            date: pastDate
        )

        XCTAssertEqual(budget.baseTarget, 1_200)
        XCTAssertEqual(budget.adjustedTarget, 1_200)
    }

    func testManualOverrideMakesDynamicModeUnavailable() {
        let budget = makeBudget(
            activeEnergyKcal: 600,
            samples: baselineSamples(kcal: 300),
            mode: .dynamicHealth,
            isManualOverride: true
        )

        XCTAssertEqual(
            budget.dynamicStatus,
            .unavailable("Auto-adjust calories is unavailable while a manual calorie target is set.")
        )
        XCTAssertEqual(budget.adjustedTarget, budget.staticTarget)
    }

    func testProgressCapsAtOneAndAHalfWhileDisplayedRingStopsAtOne() {
        let budget = makeBudget(consumed: 4_000, staticTarget: 2_000)

        XCTAssertEqual(budget.progress, 1.5, accuracy: 0.001)
        XCTAssertEqual(budget.displayedRingProgress, 1, accuracy: 0.001)
        XCTAssertEqual(budget.overAmount, 2_000)
    }

    func testZeroTargetBudgetDoesNotDivideByZero() {
        let budget = makeBudget(consumed: 50, staticTarget: 0, bmr: 0)

        XCTAssertEqual(budget.adjustedTarget, 0)
        XCTAssertEqual(budget.remaining, 0)
        XCTAssertEqual(budget.overAmount, 50)
        XCTAssertTrue(budget.isOver)
        XCTAssertEqual(budget.progress, 0, accuracy: 0.001)
        XCTAssertEqual(budget.baseProgressEnd, 1, accuracy: 0.001)
    }

    func testDynamicCopyNamesTheHealthSource() {
        XCTAssertEqual(ActivityCalorieBudget.dynamicEnergyPolicyText, "Apple Health activity")
        XCTAssertEqual(ActivityCalorieBudget.dynamicEnergyShortText, "Auto-adjust calories")
    }

    private func makeBudget(
        consumed: Double = 1_800,
        staticTarget: Int = 2_000,
        bmr: Double = 1_600,
        calorieDeficit: Double = 300,
        activeEnergyKcal: Double = 0,
        samples: [DailyActiveEnergySample] = [],
        mode: EnergyCalculationMode = .lifestyleEstimate,
        isManualOverride: Bool = false,
        date: Date = .now
    ) -> ActivityCalorieBudget {
        ActivityCalorieBudget(
            consumed: consumed,
            staticTarget: staticTarget,
            bmr: bmr,
            calorieDeficit: calorieDeficit,
            activeEnergyKcal: activeEnergyKcal,
            recentActiveEnergySamples: samples,
            calculationMode: mode,
            isManualOverride: isManualOverride,
            isActivityLoading: false,
            activityMessage: nil,
            date: date
        )
    }

    private func baselineSamples(kcal: Double, count: Int = 10, before date: Date = .now) -> [DailyActiveEnergySample] {
        baselineSamples(kcalValues: Array(repeating: kcal, count: count), before: date)
    }

    private func baselineSamples(kcalValues: [Double], before date: Date = .now) -> [DailyActiveEnergySample] {
        kcalValues.enumerated().compactMap { index, kcal in
            guard let sampleDate = Calendar.current.date(
                byAdding: .day,
                value: -(index + 1),
                to: date.startOfDay
            ) else {
                return nil
            }

            return DailyActiveEnergySample(date: sampleDate, activeEnergyKcal: kcal)
        }
    }
}
