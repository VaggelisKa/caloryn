import Foundation
import Testing
@testable import Caloryn

// MARK: - Fixtures

private func makeInvariantBudget(
    consumed: Double = 1_800,
    staticTarget: Int = 2_000,
    bmr: Double = 1_600,
    calorieDeficit: Double = 300,
    activeEnergyKcal: Double = 0,
    samples: [DailyActiveEnergySample] = [],
    mode: EnergyCalculationMode = .lifestyleEstimate,
    isManualOverride: Bool = false,
    isActivityLoading: Bool = false,
    activityMessage: String? = nil,
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
        isActivityLoading: isActivityLoading,
        activityMessage: activityMessage,
        date: date
    )
}

private func makeInvariantSamples(
    kcal: Double,
    count: Int = 10,
    endingBefore date: Date = .now
) -> [DailyActiveEnergySample] {
    makeInvariantSamples(kcalValues: Array(repeating: kcal, count: count), endingBefore: date)
}

private func makeInvariantSamples(
    kcalValues: [Double],
    endingBefore date: Date = .now
) -> [DailyActiveEnergySample] {
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

/// A completed day well in the past, where downward adjustments are permitted.
private func completedPastDay(daysAgo: Int = 30) -> Date {
    Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date.now.startOfDay)!
}

private func futureDay(daysAhead: Int = 3) -> Date {
    Calendar.current.date(byAdding: .day, value: daysAhead, to: Date.now.startOfDay)!
}

private let activeEnergySweep: [Double] = [0, 25, 50, 120, 200, 299, 300, 301, 450, 600, 900, 1_500, 5_000]

// MARK: - Mode and readiness

@Suite("ActivityCalorieBudget readiness invariants")
struct ActivityCalorieBudgetReadinessInvariantTests {
    @Test(
        "Given the lifestyle estimate mode, when any activity data exists, then the budget stays a static estimate",
        arguments: activeEnergySweep
    )
    func lifestyleModeIgnoresActivityData(activeEnergy: Double) {
        let budget = makeInvariantBudget(
            activeEnergyKcal: activeEnergy,
            samples: makeInvariantSamples(kcal: 300, count: 20),
            mode: .lifestyleEstimate
        )

        #expect(budget.dynamicStatus == .staticEstimate)
        #expect(budget.baseTarget == budget.staticTarget)
        #expect(budget.adjustedTarget == budget.staticTarget)
        #expect(budget.dynamicAdjustment == 0)
        #expect(budget.activityBaselineKcal == nil)
        #expect(budget.dynamicStatusText == nil)
    }

    @Test(
        "Given every calculation mode, when no activity history exists, then the static target is preserved",
        arguments: EnergyCalculationMode.allCases
    )
    func everyModeFallsBackToTheStaticTargetWithoutHistory(mode: EnergyCalculationMode) {
        let budget = makeInvariantBudget(samples: [], mode: mode)

        #expect(budget.baseTarget == 2_000)
        #expect(budget.adjustedTarget == 2_000)
        #expect(budget.dynamicAdjustment == 0)
    }

    @Test(
        "Given a growing run of valid days, when the required count is reached, then the budget becomes ready",
        arguments: Array(0...12)
    )
    func readinessSwitchesAtTheRequiredDayCount(count: Int) {
        let budget = makeInvariantBudget(
            activeEnergyKcal: 300,
            samples: makeInvariantSamples(kcal: 300, count: count),
            mode: .dynamicHealth
        )

        #expect(budget.validActivityDays == count)

        if count >= ActivityCalorieBudget.requiredDynamicActivityDays {
            #expect(budget.dynamicStatus == .ready)
            #expect(budget.activityBaselineKcal != nil)
        } else {
            #expect(
                budget.dynamicStatus == .learning(
                    validDays: count,
                    requiredDays: ActivityCalorieBudget.requiredDynamicActivityDays
                )
            )
            #expect(budget.activityBaselineKcal == nil)
            #expect(budget.baseTarget == budget.staticTarget)
        }
    }

    @Test(
        "Given samples around the validity threshold, when days are counted, then only 50 kcal or more counts",
        arguments: [0.0, 10.0, 49.0, 49.999, 50.0, 50.001, 300.0]
    )
    func onlySamplesAtOrAboveTheThresholdCount(kcal: Double) {
        let budget = makeInvariantBudget(
            activeEnergyKcal: 300,
            samples: makeInvariantSamples(kcal: kcal, count: 10),
            mode: .dynamicHealth
        )

        let expected = kcal >= ActivityCalorieBudget.minimumValidActiveEnergyKcal ? 10 : 0
        #expect(budget.validActivityDays == expected)
    }

    @Test("Given a mixed history, when days are counted, then sub-threshold days are excluded from the baseline")
    func subThresholdDaysAreExcludedFromTheBaseline() {
        let samples = makeInvariantSamples(kcalValues: [0, 10, 300, 300, 300, 300, 300, 300, 300, 5])
        let budget = makeInvariantBudget(
            activeEnergyKcal: 300,
            samples: samples,
            mode: .dynamicHealth
        )

        #expect(budget.validActivityDays == 7)
        #expect(budget.dynamicStatus == .ready)
        #expect(budget.activityBaselineKcal == 300)
    }

    @Test("Given a manual override, when dynamic mode is requested, then it reports unavailable and keeps the static target")
    func manualOverrideBlocksDynamicMode() {
        let budget = makeInvariantBudget(
            activeEnergyKcal: 900,
            samples: makeInvariantSamples(kcal: 300, count: 20),
            mode: .dynamicHealth,
            isManualOverride: true
        )

        guard case .unavailable = budget.dynamicStatus else {
            Issue.record("Expected an unavailable status, got \(budget.dynamicStatus)")
            return
        }
        #expect(budget.adjustedTarget == budget.staticTarget)
        #expect(budget.dynamicAdjustment == 0)
        #expect(budget.activityBaselineKcal == nil)
    }

    @Test("Given both a manual override and an activity message, when the status is read, then the override wins")
    func manualOverrideTakesPrecedenceOverActivityMessages() {
        let budget = makeInvariantBudget(
            samples: makeInvariantSamples(kcal: 300, count: 20),
            mode: .dynamicHealth,
            isManualOverride: true,
            activityMessage: "Health access denied."
        )

        #expect(
            budget.dynamicStatus
                == .unavailable("Auto-adjust calories is unavailable while a manual calorie target is set.")
        )
    }

    @Test("Given an activity message, when dynamic mode is requested, then the message surfaces as the status text")
    func activityMessageSurfacesAsUnavailable() {
        let budget = makeInvariantBudget(
            samples: makeInvariantSamples(kcal: 300, count: 20),
            mode: .dynamicHealth,
            activityMessage: "Health access denied."
        )

        #expect(budget.dynamicStatus == .unavailable("Health access denied."))
        #expect(budget.dynamicStatusText == "Health access denied.")
        #expect(budget.adjustedTarget == budget.staticTarget)
    }

    @Test("Given a ready budget, when the status text is read, then nothing is shown to the user")
    func readyBudgetsShowNoStatusText() {
        let budget = makeInvariantBudget(
            activeEnergyKcal: 300,
            samples: makeInvariantSamples(kcal: 300, count: 10),
            mode: .dynamicHealth
        )

        #expect(budget.dynamicStatus == .ready)
        #expect(budget.dynamicStatusText == nil)
    }

    @Test("Given no activity data at all, when dynamic mode is requested, then the waiting copy is shown")
    func emptyHistoryShowsTheWaitingCopy() {
        let budget = makeInvariantBudget(activeEnergyKcal: 0, samples: [], mode: .dynamicHealth)

        #expect(budget.hasAnyActiveEnergyData == false)
        #expect(budget.dynamicStatusText == ActivityCalorieBudget.connectedWaitingText)
    }

    @Test(
        "Given any non-zero activity signal, when presence is checked, then activity data is reported",
        arguments: [1.0, 25.0, 300.0]
    )
    func anyNonZeroSignalCountsAsActivityData(kcal: Double) {
        let fromToday = makeInvariantBudget(activeEnergyKcal: kcal, samples: [], mode: .dynamicHealth)
        #expect(fromToday.hasAnyActiveEnergyData)

        let fromHistory = makeInvariantBudget(
            activeEnergyKcal: 0,
            samples: makeInvariantSamples(kcal: kcal, count: 1),
            mode: .dynamicHealth
        )
        #expect(fromHistory.hasAnyActiveEnergyData)
    }
}

// MARK: - Baseline and base target

@Suite("ActivityCalorieBudget baseline invariants")
struct ActivityCalorieBudgetBaselineInvariantTests {
    @Test("Given an odd number of valid days, when the baseline is derived, then it is the middle value")
    func oddSampleCountUsesTheMiddleValue() {
        let budget = makeInvariantBudget(
            samples: makeInvariantSamples(kcalValues: [100, 200, 300, 400, 500, 600, 700]),
            mode: .dynamicHealth
        )

        #expect(budget.activityBaselineKcal == 400)
    }

    @Test("Given an even number of valid days, when the baseline is derived, then it averages the middle pair")
    func evenSampleCountAveragesTheMiddlePair() {
        let budget = makeInvariantBudget(
            samples: makeInvariantSamples(kcalValues: [100, 200, 300, 400, 500, 600, 700, 800]),
            mode: .dynamicHealth
        )

        #expect(budget.activityBaselineKcal == 450)
    }

    @Test("Given a single outlier day, when the baseline is derived, then the median resists it")
    func medianResistsOutliers() {
        let budget = makeInvariantBudget(
            samples: makeInvariantSamples(kcalValues: [300, 300, 300, 300, 300, 300, 20_000]),
            mode: .dynamicHealth
        )

        #expect(budget.activityBaselineKcal == 300)
    }

    @Test("Given more history than the window allows, when the baseline is derived, then only recent days are used")
    func baselineWindowIsCappedAtTheMostRecentDays() {
        let recent = Array(repeating: 300.0, count: ActivityCalorieBudget.maxDynamicActivityDays)
        let stale = Array(repeating: 5_000.0, count: 6)
        let budget = makeInvariantBudget(
            samples: makeInvariantSamples(kcalValues: recent + stale),
            mode: .dynamicHealth
        )

        #expect(budget.validActivityDays == recent.count + stale.count)
        #expect(budget.activityBaselineKcal == 300)
    }

    @Test("Given a sample order shuffle, when the baseline is derived, then the result is order independent")
    func baselineIsIndependentOfSampleOrder() {
        let values: [Double] = [120, 340, 260, 890, 410, 205, 615, 330]
        let ordered = makeInvariantSamples(kcalValues: values)
        let reversed = Array(ordered.reversed())

        let a = makeInvariantBudget(samples: ordered, mode: .dynamicHealth)
        let b = makeInvariantBudget(samples: reversed, mode: .dynamicHealth)

        #expect(a.activityBaselineKcal == b.activityBaselineKcal)
        #expect(a.baseTarget == b.baseTarget)
    }

    @Test("Given a ready budget, when the activity baseline rises, then the base target rises with it")
    func higherBaselineRaisesTheBaseTarget() {
        var previous = Int.min
        for baseline in stride(from: 100.0, through: 1_200.0, by: 100.0) {
            let budget = makeInvariantBudget(
                samples: makeInvariantSamples(kcal: baseline, count: 9),
                mode: .dynamicHealth
            )
            #expect(budget.baseTarget >= previous)
            previous = budget.baseTarget
        }
    }

    @Test(
        "Given a ready budget, when the base target is derived, then it equals BMR plus 10% TEF plus baseline minus the deficit",
        arguments: [1_400.0, 1_600.0, 1_800.0, 2_100.0], [0.0, 300.0, 500.0, 750.0]
    )
    func baseTargetReconcilesWithTheDocumentedFormula(bmr: Double, deficit: Double) {
        let baseline = 420.0
        let budget = makeInvariantBudget(
            bmr: bmr,
            calorieDeficit: deficit,
            samples: makeInvariantSamples(kcal: baseline, count: 9),
            mode: .dynamicHealth
        )

        let maintenance = bmr + bmr * ActivityCalorieBudget.thermicEffectOfFoodRatio + baseline
        let expected = NutritionCalculator.defaultTarget(energyExpenditure: maintenance, deficit: deficit)

        #expect(budget.baseTarget == expected)
    }

    @Test("Given a known BMR and baseline, when the base target is derived, then the golden value is produced")
    func goldenBaseTarget() {
        let budget = makeInvariantBudget(
            bmr: 1_800,
            calorieDeficit: 500,
            samples: makeInvariantSamples(kcal: 500, count: 9),
            mode: .dynamicHealth
        )

        // 1800 + 180 (TEF) + 500 (baseline) - 500 (deficit) = 1980
        #expect(budget.baseTarget == 1_980)
    }
}

// MARK: - Daily adjustment

@Suite("ActivityCalorieBudget daily adjustment invariants")
struct ActivityCalorieBudgetAdjustmentInvariantTests {
    @Test(
        "Given a completed past day, when active energy varies, then the adjustment stays inside the clamp",
        arguments: activeEnergySweep
    )
    func adjustmentAlwaysHonoursTheClamp(activeEnergy: Double) {
        let day = completedPastDay()
        let budget = makeInvariantBudget(
            activeEnergyKcal: activeEnergy,
            samples: makeInvariantSamples(kcal: 300, count: 9, endingBefore: day),
            mode: .dynamicHealth,
            date: day
        )

        #expect(budget.dynamicAdjustment >= ActivityCalorieBudget.minimumDailyDelta)
        #expect(budget.dynamicAdjustment <= ActivityCalorieBudget.maximumDailyDelta)
    }

    @Test("Given a completed past day, when active energy rises, then the adjusted target never falls")
    func adjustedTargetIsMonotonicInActiveEnergy() {
        let day = completedPastDay()
        let samples = makeInvariantSamples(kcal: 300, count: 9, endingBefore: day)

        var previousAdjustment = Int.min
        var previousTarget = Int.min
        for activeEnergy in stride(from: 0.0, through: 2_000.0, by: 50.0) {
            let budget = makeInvariantBudget(
                activeEnergyKcal: activeEnergy,
                samples: samples,
                mode: .dynamicHealth,
                date: day
            )
            #expect(budget.dynamicAdjustment >= previousAdjustment)
            #expect(budget.adjustedTarget >= previousTarget)
            previousAdjustment = budget.dynamicAdjustment
            previousTarget = budget.adjustedTarget
        }
    }

    @Test(
        "Given an incomplete day, when active energy is below the baseline, then no calories are removed",
        arguments: [0.0, 50.0, 150.0, 299.0]
    )
    func incompleteDaysNeverRemoveCalories(activeEnergy: Double) {
        for day in [Date.now, futureDay()] {
            let budget = makeInvariantBudget(
                activeEnergyKcal: activeEnergy,
                samples: makeInvariantSamples(kcal: 300, count: 9, endingBefore: day),
                mode: .dynamicHealth,
                date: day
            )

            #expect(budget.dynamicAdjustment == 0)
            #expect(budget.hasDynamicReduction == false)
            #expect(budget.adjustedTarget == budget.baseTarget)
        }
    }

    @Test(
        "Given an incomplete day, when active energy beats the baseline, then the surplus is added",
        arguments: [301.0, 400.0, 750.0]
    )
    func incompleteDaysAddTheSurplus(activeEnergy: Double) {
        for day in [Date.now, futureDay()] {
            let budget = makeInvariantBudget(
                activeEnergyKcal: activeEnergy,
                samples: makeInvariantSamples(kcal: 300, count: 9, endingBefore: day),
                mode: .dynamicHealth,
                date: day
            )

            #expect(budget.dynamicAdjustment == Int((activeEnergy - 300).rounded()))
            #expect(budget.hasDynamicIncrease)
            #expect(budget.adjustedTarget == budget.baseTarget + budget.dynamicAdjustment)
        }
    }

    @Test("Given a fractional surplus, when the adjustment is derived, then it rounds half away from zero")
    func fractionalAdjustmentsRoundHalfAwayFromZero() {
        let baselineValues: [Double] = [100, 200, 300, 400, 500, 600, 700, 800] // median 450

        let increase = makeInvariantBudget(
            activeEnergyKcal: 650.5,
            samples: makeInvariantSamples(kcalValues: baselineValues),
            mode: .dynamicHealth,
            date: .now
        )
        #expect(increase.dynamicAdjustment == 201)

        let day = completedPastDay()
        let decrease = makeInvariantBudget(
            activeEnergyKcal: 249.5,
            samples: makeInvariantSamples(kcalValues: baselineValues, endingBefore: day),
            mode: .dynamicHealth,
            date: day
        )
        #expect(decrease.dynamicAdjustment == -201)
    }

    @Test("Given an exceptional activity day, when the adjustment is derived, then it is capped at the maximum")
    func hugeSurplusIsCapped() {
        let budget = makeInvariantBudget(
            activeEnergyKcal: 10_000,
            samples: makeInvariantSamples(kcal: 300, count: 9),
            mode: .dynamicHealth,
            date: .now
        )

        #expect(budget.dynamicAdjustment == ActivityCalorieBudget.maximumDailyDelta)
    }

    @Test("Given a completely inactive past day, when the adjustment is derived, then it is capped at the minimum")
    func hugeShortfallIsCapped() {
        let day = completedPastDay()
        let budget = makeInvariantBudget(
            activeEnergyKcal: 0,
            samples: makeInvariantSamples(kcal: 2_000, count: 9, endingBefore: day),
            mode: .dynamicHealth,
            date: day
        )

        #expect(budget.dynamicAdjustment == ActivityCalorieBudget.minimumDailyDelta)
    }

    @Test(
        "Given a ready budget, when the adjustment is applied, then increase and reduction are mutually exclusive",
        arguments: activeEnergySweep
    )
    func increaseAndReductionAreMutuallyExclusive(activeEnergy: Double) {
        let day = completedPastDay()
        let budget = makeInvariantBudget(
            activeEnergyKcal: activeEnergy,
            samples: makeInvariantSamples(kcal: 300, count: 9, endingBefore: day),
            mode: .dynamicHealth,
            date: day
        )

        #expect(!(budget.hasDynamicIncrease && budget.hasDynamicReduction))
        #expect(budget.dynamicIncrease == max(0, budget.dynamicAdjustment))
        #expect(budget.dynamicIncrease >= 0)
    }

    @Test(
        "Given a ready budget with a low base, when a reduction applies, then the adjusted target holds the safety floor",
        arguments: [900.0, 1_000.0, 1_100.0]
    )
    func adjustedTargetHoldsTheSafetyFloor(bmr: Double) {
        let day = completedPastDay()
        let budget = makeInvariantBudget(
            staticTarget: 1_200,
            bmr: bmr,
            calorieDeficit: 500,
            activeEnergyKcal: 0,
            samples: makeInvariantSamples(kcal: 400, count: 9, endingBefore: day),
            mode: .dynamicHealth,
            date: day
        )

        #expect(budget.adjustedTarget >= ActivityCalorieBudget.minimumTarget)
    }

    @Test(
        "Given identical inputs, when two budgets are built, then they are equal and derive identical numbers",
        arguments: activeEnergySweep
    )
    func budgetsAreDeterministic(activeEnergy: Double) {
        let day = completedPastDay()
        let samples = makeInvariantSamples(kcal: 300, count: 9, endingBefore: day)

        let first = makeInvariantBudget(
            activeEnergyKcal: activeEnergy, samples: samples, mode: .dynamicHealth, date: day
        )
        let second = makeInvariantBudget(
            activeEnergyKcal: activeEnergy, samples: samples, mode: .dynamicHealth, date: day
        )

        #expect(first == second)
        #expect(first.baseTarget == second.baseTarget)
        #expect(first.adjustedTarget == second.adjustedTarget)
        #expect(first.dynamicAdjustment == second.dynamicAdjustment)
        #expect(first.activityBaselineKcal == second.activityBaselineKcal)
    }
}

// MARK: - Consumption reporting

@Suite("ActivityCalorieBudget consumption invariants")
struct ActivityCalorieBudgetConsumptionInvariantTests {
    @Test(
        "Given any consumption, when remaining and over are derived, then they reconcile with the adjusted target",
        arguments: [0.0, 500.0, 1_199.0, 1_999.0, 2_000.0, 2_001.0, 3_400.0, 9_999.0]
    )
    func remainingAndOverReconcileWithTheTarget(consumed: Double) {
        let budget = makeInvariantBudget(consumed: consumed, staticTarget: 2_000)

        #expect(budget.remaining >= 0)
        #expect(budget.overAmount >= 0)
        #expect(budget.remaining == 0 || budget.overAmount == 0)
        #expect(budget.remaining - budget.overAmount == budget.adjustedTarget - budget.roundedConsumed)
    }

    @Test(
        "Given any consumption, when progress is derived, then it stays inside the display bounds",
        arguments: [0.0, 100.0, 1_000.0, 2_000.0, 2_500.0, 6_000.0]
    )
    func progressStaysInsideDisplayBounds(consumed: Double) {
        let budget = makeInvariantBudget(consumed: consumed, staticTarget: 2_000)

        #expect(budget.progress >= 0)
        #expect(budget.progress <= 1.5)
        #expect(budget.displayedRingProgress >= 0)
        #expect(budget.displayedRingProgress <= 1)
        #expect(budget.baseProgressEnd >= 0)
        #expect(budget.baseProgressEnd <= 1)
    }

    @Test("Given more consumption, when progress is derived, then it never decreases")
    func progressIsMonotonicInConsumption() {
        var previous = -Double.infinity
        for consumed in stride(from: 0.0, through: 5_000.0, by: 100.0) {
            let budget = makeInvariantBudget(consumed: consumed, staticTarget: 2_000)
            #expect(budget.progress >= previous)
            previous = budget.progress
        }
    }

    @Test("Given a zero target, when progress is derived, then no division by zero occurs")
    func zeroTargetIsSafe() {
        let budget = makeInvariantBudget(consumed: 500, staticTarget: 0, bmr: 0)

        #expect(budget.progress == 0)
        #expect(budget.displayedRingProgress == 0)
        #expect(budget.baseProgressEnd == 1)
        #expect(budget.remaining == 0)
        #expect(budget.overAmount == 500)
    }

    @Test("Given a negative static target, when the budget reports, then remaining stays clamped at zero")
    func negativeTargetIsClampedForDisplay() {
        let budget = makeInvariantBudget(consumed: 100, staticTarget: -500, bmr: 0)

        #expect(budget.adjustedTarget == -500)
        #expect(budget.remaining == 0)
        #expect(budget.overAmount == 600)
        #expect(budget.progress == 0)
    }

    @Test("Given a ready budget with an increase, when the ring is drawn, then the base segment ends before the full ring")
    func baseSegmentEndsBeforeTheFullRingWhenBoosted() {
        let budget = makeInvariantBudget(
            activeEnergyKcal: 700,
            samples: makeInvariantSamples(kcal: 300, count: 9),
            mode: .dynamicHealth,
            date: .now
        )

        #expect(budget.hasDynamicIncrease)
        #expect(budget.baseProgressEnd < 1)
        #expect(budget.baseProgressEnd > 0)
    }

    @Test("Given fractional consumption just above the target, when the budget reports, then it is not over budget by zero")
    func fractionalOverConsumptionAgreesWithTheOverAmount() {
        // A sub-half-calorie overshoot rounds down to the target, so no over-budget treatment.
        let budget = makeInvariantBudget(consumed: 2_000.4, staticTarget: 2_000)

        #expect(budget.isOver == false)
        #expect(budget.overAmount == 0)
        #expect(budget.remaining == 0)
    }

    @Test("Given consumption just below the target, when the budget reports, then it is neither over nor has calories left")
    func fractionalUnderConsumptionRoundsRemainingToZero() {
        let budget = makeInvariantBudget(consumed: 1_999.6, staticTarget: 2_000)

        #expect(budget.isOver == false)
        #expect(budget.remaining == 0)
        #expect(budget.overAmount == 0)
    }

    @Test(
        "Given any consumption, when the budget reports, then over-budget agrees with the over amount",
        arguments: [0.0, 1_999.4, 1_999.6, 2_000.0, 2_000.4, 2_000.6, 2_001.0, 3_000.5]
    )
    func isOverAgreesWithTheOverAmount(consumed: Double) {
        let budget = makeInvariantBudget(consumed: consumed, staticTarget: 2_000)

        #expect(budget.isOver == (budget.overAmount > 0))
    }
}
