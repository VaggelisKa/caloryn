import Foundation
import Testing
@testable import Caloryn

// Boundary audit of the calorie budget: the rounding every summary inherits, the clamp that
// keeps those figures inside `CalorieDomain`, and the budget's answers exactly at, and one
// calorie either side of, its target.
//
// Dynamic days are dated far in the past (2020) or far in the future (2099): the budget
// compares its date with the real clock to decide whether a day is complete, and a fixed
// date that far away gives the same answer on every run.

// MARK: - Fixtures

nonisolated private let auditCompletedDay = makeTestDate(year: 2020, month: 6, day: 15)
nonisolated private let auditFutureDay = makeTestDate(year: 2099, month: 6, day: 15)

@MainActor
private func auditBudget(
    consumed: Double = 0,
    staticTarget: Int = 2_000,
    bmr: Double = 1_600,
    calorieDeficit: Double = 300,
    activeEnergyKcal: Double = 0,
    samples: [DailyActiveEnergySample] = [],
    mode: EnergyCalculationMode = .lifestyleEstimate,
    isManualOverride: Bool = false,
    activityMessage: String? = nil,
    date: Date = auditCompletedDay
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
        activityMessage: activityMessage,
        date: date
    )
}

/// One sample a day for the `count` days before `date`. Only the order of the dates
/// matters to the budget (most recent first), so they are spaced by whole days of seconds
/// rather than through a calendar.
@MainActor
private func auditSamples(kcal: Double, count: Int, before date: Date) -> [DailyActiveEnergySample] {
    (0 ..< count).map { index in
        DailyActiveEnergySample(
            date: date.addingTimeInterval(-86_400 * Double(index + 1)),
            activeEnergyKcal: kcal
        )
    }
}

/// A fractional distance from the target and the whole calories it rounds to.
nonisolated private let auditTargetOffsets: [(Double, Int)] = [
    (-1, -1),
    (-0.6, -1),
    (-0.5, 0),
    (-0.4, 0),
    (0, 0),
    (0.4, 0),
    (0.5, 1),
    (0.6, 1),
    (1, 1),
]

// MARK: - Rounding and the calorie domain

@MainActor
@Suite("Calorie rounding and domain audit")
struct AuditCalorieRoundingTests {
    @Test(
        "Calorie figures round half away from zero, then stay inside the calorie domain",
        arguments: [
            (0.0, 0),
            (0.49, 0),
            (0.5, 1),
            (-0.49, 0),
            (-0.5, -1),
            (2.5, 3),
            (1_999.5, 2_000),
            (2_000.5, 2_001),
            (999_999_999.5, 1_000_000_000),
            (1_000_000_000.5, 1_000_000_000),
            (1e12, 1_000_000_000),
            (-1e12, -1_000_000_000),
            (Double(Int.max), 1_000_000_000),
            (-Double(Int.max), -1_000_000_000),
        ]
    )
    func roundedCaloriesRoundsAndClamps(value: Double, expected: Int) {
        #expect(value.roundedCalories == expected)
    }

    /// Pinned by `NonFiniteNumberSafetyTests` for the budget; this is the rounding rule
    /// underneath it, so a NaN or an infinity counts as nothing rather than as a billion.
    @Test("A figure that is not a number rounds to zero", arguments: [Double.nan, .infinity, -.infinity])
    func nonFiniteFiguresRoundToZero(value: Double) {
        #expect(value.roundedCalories == 0)
    }

    @Test(
        "The calorie domain clamps at a billion either way and passes everything inside it",
        arguments: [
            (Int.max, 1_000_000_000),
            (1_000_000_001, 1_000_000_000),
            (1_000_000_000, 1_000_000_000),
            (999_999_999, 999_999_999),
            (2_000, 2_000),
            (0, 0),
            (-999_999_999, -999_999_999),
            (-1_000_000_000, -1_000_000_000),
            (-1_000_000_001, -1_000_000_000),
            (Int.min, -1_000_000_000),
        ]
    )
    func domainClampsAtItsBounds(value: Int, expected: Int) {
        #expect(CalorieDomain.clamped(value) == expected)
    }
}

// MARK: - Exactly at, and either side of, the target

@MainActor
@Suite("Calorie budget target boundary audit")
struct AuditCalorieBudgetTargetBoundaryTests {
    @Test(
        "At, and within a calorie of, the target the budget reports from the rounded total",
        arguments: auditTargetOffsets
    )
    func boundaryAroundTheTarget(offset: Double, roundedOffset: Int) {
        for target in [1_200, 2_000, 2_537] {
            let budget = auditBudget(consumed: Double(target) + offset, staticTarget: target)

            #expect(budget.adjustedTarget == target)
            #expect(budget.roundedConsumed == target + roundedOffset)
            #expect(budget.remaining == max(0, -roundedOffset))
            #expect(budget.overAmount == max(0, roundedOffset))
            #expect(budget.isOver == (roundedOffset > 0))
        }
    }

    @Test("Exactly on the target the day is neither over nor has anything left")
    func exactlyOnTheTarget() {
        let budget = auditBudget(consumed: 2_000, staticTarget: 2_000)

        #expect(budget.isOver == false)
        #expect(budget.remaining == 0)
        #expect(budget.overAmount == 0)
        #expect(budget.progress == 1)
        #expect(budget.displayedRingProgress == 1)
    }

    @Test("One whole calorie either side of the target is one calorie left or one calorie over")
    func oneCalorieEitherSide() {
        let under = auditBudget(consumed: 1_999, staticTarget: 2_000)
        let over = auditBudget(consumed: 2_001, staticTarget: 2_000)

        #expect(under.remaining == 1)
        #expect(under.overAmount == 0)
        #expect(under.isOver == false)
        #expect(over.remaining == 0)
        #expect(over.overAmount == 1)
        #expect(over.isOver)
    }

    @Test("A target saved past the calorie domain is clamped before anything is subtracted from it")
    func staticTargetIsClampedIntoTheDomain() {
        let high = auditBudget(consumed: 0, staticTarget: 5_000_000_000)
        let low = auditBudget(consumed: 0, staticTarget: -5_000_000_000)

        #expect(high.baseTarget == CalorieDomain.maximum)
        #expect(high.remaining == CalorieDomain.maximum)
        #expect(low.baseTarget == CalorieDomain.minimum)
        #expect(low.remaining == 0)
        #expect(low.overAmount == -CalorieDomain.minimum)
    }
}

// MARK: - Progress

@MainActor
@Suite("Calorie budget progress audit")
struct AuditCalorieBudgetProgressTests {
    @Test(
        "Progress is consumed over target, capped at one and a half, and the ring at a full turn",
        arguments: [
            (0.0, 0.0, 0.0),
            (1.0, 0.0005, 0.0005),
            (1_000.0, 0.5, 0.5),
            (1_999.6, 0.9998, 0.9998),
            (2_000.0, 1.0, 1.0),
            (2_000.4, 1.0002, 1.0),
            (2_999.0, 1.4995, 1.0),
            (3_000.0, 1.5, 1.0),
            (3_001.0, 1.5, 1.0),
            (1e30, 1.5, 1.0),
        ]
    )
    func progressIsClamped(consumed: Double, expectedProgress: Double, expectedRing: Double) {
        let budget = auditBudget(consumed: consumed, staticTarget: 2_000)

        #expect(abs(budget.progress - expectedProgress) < 1e-12)
        #expect(abs(budget.displayedRingProgress - expectedRing) < 1e-12)
    }

    /// The budget caps progress from above only. Nothing below zero is drawn because the
    /// ring hides its base arc under one per cent (`CalorieRingProgress`), so the figure is
    /// pinned here and the drawing is checked in the consistency audit.
    @Test("A negative total gives a negative progress rather than being floored at zero")
    func negativeTotalIsNotFloored() {
        let budget = auditBudget(consumed: -500, staticTarget: 2_000)

        #expect(budget.progress == -0.25)
        #expect(budget.displayedRingProgress == -0.25)
        #expect(budget.remaining == 2_500)
        #expect(budget.isOver == false)
    }

    @Test(
        "A target at or below zero reports no progress and a full base segment",
        arguments: [0, -1, -2_000]
    )
    func nonPositiveTargetHasNoProgress(target: Int) {
        let budget = auditBudget(consumed: 500, staticTarget: target)

        #expect(budget.progress == 0)
        #expect(budget.displayedRingProgress == 0)
        #expect(budget.baseProgressEnd == 1)
        #expect(budget.overAmount == 500 - target)
    }

    @Test("Without an auto-adjust increase the base segment is the whole ring")
    func baseSegmentIsWholeWithoutAnIncrease() {
        let lifestyle = auditBudget(consumed: 900, staticTarget: 2_000)
        let reduced = auditBudget(
            activeEnergyKcal: 0,
            samples: auditSamples(kcal: 300, count: 9, before: auditCompletedDay),
            mode: .dynamicHealth,
            date: auditCompletedDay
        )

        #expect(lifestyle.baseProgressEnd == 1)
        #expect(reduced.hasDynamicReduction)
        // The base target is larger than the reduced one, so its share is clamped to the ring.
        #expect(reduced.baseProgressEnd == 1)
    }

    @Test("With an increase the base segment ends at the base target's share of the adjusted one")
    func baseSegmentEndsAtTheBaseShare() {
        let budget = auditBudget(
            activeEnergyKcal: 800,
            samples: auditSamples(kcal: 300, count: 9, before: auditFutureDay),
            mode: .dynamicHealth,
            date: auditFutureDay
        )

        // 1,600 + 160 TEF + 300 baseline − 300 deficit = 1,760, plus the 500 above baseline.
        #expect(budget.baseTarget == 1_760)
        #expect(budget.adjustedTarget == 2_260)
        #expect(budget.baseProgressEnd == 1_760.0 / 2_260.0)
    }
}

// MARK: - Auto-adjust

@MainActor
@Suite("Calorie budget auto-adjust audit")
struct AuditCalorieBudgetAutoAdjustTests {
    @Test("Whether auto-adjust was asked for follows the mode the budget was given, not its readiness")
    func dynamicModeRequestedFollowsTheMode() {
        #expect(auditBudget(mode: .dynamicHealth).isDynamicModeRequested)
        #expect(auditBudget(mode: .dynamicHealth, isManualOverride: true).isDynamicModeRequested)
        #expect(auditBudget(mode: .dynamicHealth, activityMessage: "Denied").isDynamicModeRequested)
        #expect(auditBudget(mode: .lifestyleEstimate).isDynamicModeRequested == false)
    }

    @Test(
        "A profile's budget asks for auto-adjust only when its effective mode is Apple Health",
        arguments: [
            (false, EnergyCalculationMode.dynamicHealth, true),
            (false, EnergyCalculationMode.lifestyleEstimate, false),
            (true, EnergyCalculationMode.dynamicHealth, false),
            (true, EnergyCalculationMode.lifestyleEstimate, false),
        ]
    )
    func profileBudgetRequestsDynamicModeFromTheEffectiveMode(
        isManualOverride: Bool,
        storedMode: EnergyCalculationMode,
        expected: Bool
    ) {
        let profile = UserProfile(
            age: 30,
            sex: .female,
            heightCm: 165,
            weightKg: 62,
            activityLevel: .lightlyActive,
            manualOverride: isManualOverride,
            energyCalculationMode: storedMode
        )
        let budget = profile.activityBudget(
            consumed: 0,
            activeEnergyKcal: 0,
            recentActiveEnergySamples: [],
            isActivityLoading: false,
            activityMessage: nil,
            date: auditCompletedDay
        )

        #expect(budget.isDynamicModeRequested == expected)
    }

    @Test(
        "Learning copy counts valid days, and only an empty history reads as waiting",
        arguments: [
            (0, 30.0, "Needs 7 active days to learn your baseline. 0 found so far."),
            (0, 0.0, "Auto-adjust is on. Waiting for Active Energy data."),
            (1, 0.0, "Needs 7 active days to learn your baseline. 1 found so far."),
            (6, 0.0, "Needs 7 active days to learn your baseline. 6 found so far."),
        ]
    )
    func learningCopy(validDays: Int, activeEnergyToday: Double, expected: String) {
        let budget = auditBudget(
            activeEnergyKcal: activeEnergyToday,
            samples: auditSamples(kcal: 300, count: validDays, before: auditCompletedDay),
            mode: .dynamicHealth
        )

        #expect(budget.dynamicStatusText == expected)
    }

    @Test("History that is all below the validity threshold still counts as data, so it is not 'waiting'")
    func subThresholdHistoryIsNotWaiting() {
        let budget = auditBudget(
            activeEnergyKcal: 0,
            samples: auditSamples(kcal: 49, count: 10, before: auditCompletedDay),
            mode: .dynamicHealth
        )

        #expect(budget.validActivityDays == 0)
        #expect(budget.hasAnyActiveEnergyData)
        #expect(budget.dynamicStatusText == "Needs 7 active days to learn your baseline. 0 found so far.")
    }

    @Test("Seven valid days is exactly enough: the learning copy disappears and the baseline exists")
    func sevenDaysIsExactlyEnough() {
        let budget = auditBudget(
            samples: auditSamples(kcal: 300, count: ActivityCalorieBudget.requiredDynamicActivityDays, before: auditCompletedDay),
            mode: .dynamicHealth
        )

        #expect(budget.dynamicStatus == .ready)
        #expect(budget.dynamicStatusText == nil)
        #expect(budget.activityBaselineKcal == 300)
    }

    /// For a ready budget the two flags are exactly "the target moved up" and "the target
    /// moved down" — never set for an adjustment the floor or the domain swallowed.
    @Test(
        "A ready budget flags an increase or a reduction exactly when the target moved",
        arguments: [800.0, 1_000.0, 1_300.0, 1_600.0, 2_200.0, 1e12]
    )
    func flagsFollowTheTargetsMovement(bmr: Double) {
        for date in [auditCompletedDay, auditFutureDay] {
            for activeEnergy in [0.0, 100.0, 299.0, 300.0, 301.0, 450.0, 900.0, 5_000.0] {
                let budget = auditBudget(
                    bmr: bmr,
                    calorieDeficit: 500,
                    activeEnergyKcal: activeEnergy,
                    samples: auditSamples(kcal: 300, count: 9, before: date),
                    mode: .dynamicHealth,
                    date: date
                )

                #expect(budget.dynamicStatus == .ready)
                #expect(budget.hasDynamicIncrease == (budget.adjustedTarget > budget.baseTarget))
                #expect(budget.hasDynamicReduction == (budget.adjustedTarget < budget.baseTarget))
                #expect(budget.adjustedTarget >= ActivityCalorieBudget.minimumTarget)
                #expect(budget.adjustedTarget <= CalorieDomain.maximum)
                if budget.hasDynamicIncrease {
                    #expect(budget.adjustedTarget - budget.baseTarget == budget.dynamicIncrease)
                }
            }
        }
    }

    @Test("A day far past the baseline adds at most 600, and one far under it takes off at most 300")
    func dailyAdjustmentIsCappedBothWays() {
        // 1,600 + 160 TEF + 300 baseline − 300 deficit = 1,760; 1,500 active is 1,200 above.
        let busy = auditBudget(
            activeEnergyKcal: 1_500,
            samples: auditSamples(kcal: 300, count: 9, before: auditFutureDay),
            mode: .dynamicHealth,
            date: auditFutureDay
        )
        // 2,000 + 200 TEF + 900 baseline − 300 deficit = 2,800; 50 active is 850 below.
        let quiet = auditBudget(
            bmr: 2_000,
            activeEnergyKcal: 50,
            samples: auditSamples(kcal: 900, count: 9, before: auditCompletedDay),
            mode: .dynamicHealth,
            date: auditCompletedDay
        )

        #expect(busy.dynamicAdjustment == 600)
        #expect(busy.dynamicIncrease == 600)
        #expect(busy.adjustedTarget == 2_360)
        #expect(CalorieRingSummary(budget: busy).cue == .increase(600))
        #expect(quiet.baseTarget == 2_800)
        #expect(quiet.dynamicAdjustment == -300)
        #expect(quiet.adjustedTarget == 2_500)
        #expect(CalorieRingSummary(budget: quiet).cue == .reduction(-300))
    }

    @Test("At the top of the calorie domain an increase is computed but cannot move the target")
    func increaseSwallowedByTheDomain() {
        let budget = auditBudget(
            bmr: 1e12,
            activeEnergyKcal: 900,
            samples: auditSamples(kcal: 300, count: 9, before: auditFutureDay),
            mode: .dynamicHealth,
            date: auditFutureDay
        )

        #expect(budget.baseTarget == CalorieDomain.maximum)
        #expect(budget.dynamicIncrease == 600)
        #expect(budget.adjustedTarget == CalorieDomain.maximum)
        #expect(budget.hasDynamicIncrease == false)
        #expect(CalorieRingSummary(budget: budget).cue == .none)
    }

    @Test("At the safety floor a reduction is computed but cannot move the target, so no cue shows")
    func reductionSwallowedByTheFloor() {
        // 1,000 + 100 TEF + 300 baseline − 500 deficit = 900, floored to 1,200.
        let budget = auditBudget(
            bmr: 1_000,
            calorieDeficit: 500,
            activeEnergyKcal: 0,
            samples: auditSamples(kcal: 300, count: 9, before: auditCompletedDay),
            mode: .dynamicHealth,
            date: auditCompletedDay
        )

        #expect(budget.baseTarget == 1_200)
        #expect(budget.dynamicAdjustment == -300)
        #expect(budget.adjustedTarget == 1_200)
        #expect(budget.hasDynamicReduction == false)
        #expect(CalorieRingSummary(budget: budget).cue == .none)
    }

    @Test("Partly above the floor, a reduction's cue and Nutrition Details report the full adjustment")
    func partlyFlooredReductionReportsTheUnflooredAdjustment() {
        // 1,000 + 100 TEF + 300 baseline − 100 deficit = 1,300; a −300 day can only reach 1,200.
        let budget = auditBudget(
            bmr: 1_000,
            calorieDeficit: 100,
            activeEnergyKcal: 0,
            samples: auditSamples(kcal: 300, count: 9, before: auditCompletedDay),
            mode: .dynamicHealth,
            date: auditCompletedDay
        )
        let cue = CalorieRingSummary(budget: budget).cue

        #expect(budget.baseTarget == 1_300)
        #expect(budget.adjustedTarget == 1_200)
        #expect(budget.hasDynamicReduction)
        // Current behaviour, suspected bug: the target only dropped by 100, but the cue and
        // the Nutrition Details row both report the unfloored −300 adjustment.
        #expect(budget.dynamicAdjustment == -300)
        #expect(cue == .reduction(-300))
        #expect(cue.text == "-300 dynamic")
        #expect(NutritionDetailsSummary.dynamicAdjustmentText(budget.dynamicAdjustment) == "-300 kcal")
    }
}
