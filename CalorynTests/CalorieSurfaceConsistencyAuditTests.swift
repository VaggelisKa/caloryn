import Foundation
import Testing
@testable import Caloryn

nonisolated private let auditUS = Locale(identifier: "en_US")
nonisolated private let auditPast = makeTestDate(year: 2020, month: 6, day: 15)
nonisolated private let auditFuture = makeTestDate(year: 2099, month: 6, day: 15)

nonisolated private let auditDayOffsets: [Double] = [-1, -0.6, -0.5, -0.4, 0, 0.4, 0.5, 0.6, 1]

private enum AuditBudgetKind: CaseIterable {
    case staticFloor
    case staticRound
    case staticOdd
    case manualOverride
    case dynamicIncrease
    case dynamicReduction
}

@MainActor
private func auditBudget(_ kind: AuditBudgetKind, consumed: Double) -> ActivityCalorieBudget {
    let samples: (Date) -> [DailyActiveEnergySample] = { date in
        (0 ..< 9).map { index in
            DailyActiveEnergySample(date: date.addingTimeInterval(-86_400 * Double(index + 1)), activeEnergyKcal: 300)
        }
    }
    func make(
        staticTarget: Int,
        activeEnergy: Double = 0,
        mode: EnergyCalculationMode = .lifestyleEstimate,
        manual: Bool = false,
        date: Date = auditPast
    ) -> ActivityCalorieBudget {
        ActivityCalorieBudget(
            consumed: consumed,
            staticTarget: staticTarget,
            bmr: 1_600,
            calorieDeficit: 300,
            activeEnergyKcal: activeEnergy,
            recentActiveEnergySamples: mode == .dynamicHealth ? samples(date) : [],
            calculationMode: mode,
            isManualOverride: manual,
            isActivityLoading: false,
            activityMessage: nil,
            date: date
        )
    }

    switch kind {
    case .staticFloor:
        return make(staticTarget: 1_200)
    case .staticRound:
        return make(staticTarget: 2_000)
    case .staticOdd:
        return make(staticTarget: 2_537)
    case .manualOverride:
        return make(staticTarget: 1_850, activeEnergy: 900, mode: .dynamicHealth, manual: true)
    case .dynamicIncrease:
        return make(staticTarget: 2_000, activeEnergy: 800, mode: .dynamicHealth, date: auditFuture)
    case .dynamicReduction:
        return make(staticTarget: 2_000, activeEnergy: 100, mode: .dynamicHealth, date: auditPast)
    }
}

@MainActor
private func auditEntries(total: Double) -> [SettingsGoalPlate.Entry] {
    guard total > 0 else { return [] }
    guard total >= 1_000 else { return [.init(meal: .lunch, calories: total)] }
    return [
        .init(meal: .snack, calories: 100),
        .init(meal: .breakfast, calories: 300),
        .init(meal: .lunch, calories: 600),
        .init(meal: .dinner, calories: total - 1_000),
    ]
}

private func auditTotals(around target: Int) -> [Double] {
    let target = Double(target)
    return [0, target / 2] + auditDayOffsets.map { target + $0 } + [target * 1.5, target * 3]
}

@MainActor
@Suite("Calorie summary cross-surface consistency audit")
struct AuditCalorieSurfaceConsistencyTests {
    @Test(
        "Ring, donut, hero, Settings plate and Nutrition Details agree on remaining and over",
        arguments: AuditBudgetKind.allCases
    )
    private func everySurfaceReportsTheSameDay(kind: AuditBudgetKind) {
        let target = auditBudget(kind, consumed: 0).adjustedTarget

        for total in auditTotals(around: target) {
            let entries = auditEntries(total: total)
            let budget = auditBudget(kind, consumed: SettingsGoalPlate.eaten(entries))
            let todayTotals = TodayHeroSummary.mealTotals(entries, mealType: \.meal, calories: \.calories)
            let ring = CalorieRingSummary(budget: budget)
            let hero = TodayHeroSummary(mealTotals: todayTotals, budget: budget, locale: auditUS)
            let settingsPlate = CalorieDonutSummary(mealTotals: SettingsGoalPlate.mealTotals(entries), budget: budget)
            let donut = hero.donut

            #expect(budget.adjustedTarget == target, "total \(total)")

            #expect(ring.isOver == budget.isOver, "total \(total)")
            #expect(hero.isOver == budget.isOver, "total \(total)")
            #expect(donut.isOver == budget.isOver, "total \(total)")
            #expect(donut.hasOverSector == budget.isOver, "total \(total)")

            let headline = budget.isOver ? budget.overAmount : budget.remaining
            #expect(ring.centerValue == headline, "total \(total)")
            #expect(hero.headline == headline, "total \(total)")
            #expect(donut.remainingKcal == budget.remaining, "total \(total)")
            #expect(donut.overKcal == budget.overAmount, "total \(total)")
            #expect(donut.eatenKcal == budget.roundedConsumed, "total \(total)")
            #expect(donut.budgetKcal == budget.adjustedTarget, "total \(total)")

            let overRows = donut.legend.filter { $0.key == .over }
            #expect(overRows == (budget.isOver ? [.over(kcal: budget.overAmount)] : []), "total \(total)")

            let ringTotal = donut.sectors.reduce(0) { $0 + $1.kcal }
            let expectedWhole = max(Double(budget.adjustedTarget), budget.consumed)
            #expect(abs(ringTotal - expectedWhole) < 1e-6, "total \(total)")

            let targetText = budget.adjustedTarget.formatted(.number.locale(auditUS))
            #expect(hero.caption == (budget.isOver ? "kcal over" : "kcal left of \(targetText)"), "total \(total)")
            #expect(
                hero.eatenLine == "\(budget.roundedConsumed.formatted(.number.locale(auditUS))) of \(targetText) eaten",
                "total \(total)"
            )
            #expect(
                NutritionDetailsSections.calorieTargetText(
                    adjustedTarget: budget.adjustedTarget,
                    isOver: budget.isOver,
                    overAmount: budget.overAmount,
                    locale: auditUS
                ) == (budget.isOver
                    ? "of \(targetText) kcal, \(budget.overAmount.formatted(.number.locale(auditUS))) over"
                    : "of \(targetText) kcal"),
                "total \(total)"
            )

            #expect(settingsPlate == donut, "total \(total)")
        }
    }

    @Test(
        "Half a calorie either side of the target is decided once and read the same everywhere",
        arguments: [(-0.5, false, 0, 0), (0.5, true, 0, 1), (-0.6, false, 1, 0), (0.4, false, 0, 0)]
    )
    func halfCalorieBoundary(offset: Double, isOver: Bool, remaining: Int, over: Int) {
        let entries = [SettingsGoalPlate.Entry(meal: .dinner, calories: 2_000 + offset)]
        let budget = auditBudget(.staticRound, consumed: SettingsGoalPlate.eaten(entries))
        let hero = TodayHeroSummary(
            mealTotals: SettingsGoalPlate.mealTotals(entries),
            budget: budget,
            locale: auditUS
        )

        #expect(hero.isOver == isOver)
        #expect(hero.ring.remaining == remaining)
        #expect(hero.ring.overAmount == over)
        #expect(hero.donut.remainingKcal == remaining)
        #expect(hero.donut.overKcal == over)
        #expect(hero.headline == (isOver ? over : remaining))
    }

    @Test("A day with nothing logged reads as the whole budget left on every surface")
    func nothingLoggedEverywhere() {
        for kind in AuditBudgetKind.allCases {
            let budget = auditBudget(kind, consumed: SettingsGoalPlate.eaten([]))
            let hero = TodayHeroSummary(mealTotals: SettingsGoalPlate.mealTotals([]), budget: budget, locale: auditUS)

            #expect(hero.headline == budget.adjustedTarget)
            #expect(hero.donut.sectors == [.init(kind: .remaining, kcal: Double(budget.adjustedTarget))])
            #expect(hero.donut.legend.allSatisfy { !$0.isLogged })
            #expect(hero.donut.legend.map { hero.legendValue(for: $0) } == ["not yet", "not yet", "not yet", "not yet"])
        }
    }

    @Test("Black coffee alone is logged on the plate but leaves every figure at the full budget")
    func zeroCalorieDay() {
        let entries = [SettingsGoalPlate.Entry(meal: .breakfast, calories: 0)]
        let budget = auditBudget(.staticRound, consumed: SettingsGoalPlate.eaten(entries))
        let hero = TodayHeroSummary(mealTotals: SettingsGoalPlate.mealTotals(entries), budget: budget, locale: auditUS)

        #expect(hero.headline == 2_000)
        #expect(hero.donut.sectors == [.init(kind: .remaining, kcal: 2_000)])
        #expect(hero.legendValue(for: hero.donut.legend[0]) == "0")
        #expect(hero.eatenLine == "0 of 2,000 eaten")
    }

    @Test("A total summed in a different order still rounds the same on the donut as on the hero")
    func summationOrderCannotSplitTheRounding() {
        let entries: [SettingsGoalPlate.Entry] = [
            .init(meal: .breakfast, calories: 0.1),
            .init(meal: .lunch, calories: 0.05),
            .init(meal: .breakfast, calories: 1_999.35),
        ]
        let budget = ActivityCalorieBudget(
            consumed: SettingsGoalPlate.eaten(entries),
            staticTarget: 1_999,
            bmr: 1_600,
            calorieDeficit: 300,
            activeEnergyKcal: 0,
            recentActiveEnergySamples: [],
            calculationMode: .lifestyleEstimate,
            isManualOverride: false,
            isActivityLoading: false,
            activityMessage: nil,
            date: auditPast
        )
        let hero = TodayHeroSummary(
            mealTotals: SettingsGoalPlate.mealTotals(entries),
            budget: budget,
            locale: auditUS
        )

        #expect(SettingsGoalPlate.eaten(entries) == 1_999.5)
        #expect(hero.ring.roundedConsumed == 2_000)
        #expect(hero.isOver)
        #expect(hero.headline == 1)
        #expect(hero.caption == "kcal over")
        #expect(hero.donut.eatenKcal == 2_000)
        #expect(hero.donut.overKcal == 1)
        #expect(hero.donut.legend.last == .over(kcal: 1))
    }
}

@MainActor
@Suite("Calorie ring arc audit")
struct AuditCalorieRingArcTests {
    private func drawnLength(_ progress: CalorieRingProgress) -> Double {
        [progress.baseArc, progress.dynamicArc]
            .filter(\.isVisible)
            .reduce(0) { $0 + ($1.end - $1.start) }
    }

    @Test(
        "The arcs draw exactly the fill, never past a full turn, and meet at the seam",
        arguments: [-0.25, 0, 0.0099, 0.01, 0.3, 0.5, 0.779_999, 0.78, 0.780_001, 0.95, 1]
    )
    func arcsDrawTheFill(fill: Double) {
        for seam in [0.5, 0.78, 1.0] {
            for hasIncrease in [false, true] {
                let ring = CalorieRingProgress(animatedProgress: fill, baseProgressEnd: seam, hasDynamicIncrease: hasIncrease)
                let expected = fill < CalorieRingProgress.minimumVisibleProgress ? 0 : min(fill, 1)
                let context = "fill \(fill), seam \(seam), increase \(hasIncrease)"

                #expect(abs(drawnLength(ring) - expected) < 1e-12, "\(context)")
                #expect(ring.baseArc.start == 0, "\(context)")
                #expect(ring.baseArc.isVisible == (fill >= CalorieRingProgress.minimumVisibleProgress), "\(context)")
                for arc in [ring.baseArc, ring.dynamicArc, ring.dynamicTrack] where arc.isVisible {
                    #expect(arc.end >= arc.start, "\(context)")
                    #expect(arc.end <= 1, "\(context)")
                }
                #expect(ring.dynamicTrack.isVisible == hasIncrease, "\(context)")
                #expect(ring.dynamicTrack.start == seam, "\(context)")
                #expect(ring.dynamicTrack.end == (hasIncrease ? 1 : seam), "\(context)")
                #expect(ring.dynamicArc.isVisible == (hasIncrease && fill > seam), "\(context)")
                if ring.dynamicArc.isVisible {
                    #expect(ring.baseArc.end == ring.dynamicArc.start, "\(context)")
                }
                if hasIncrease {
                    #expect(ring.baseArc.end <= seam, "\(context)")
                }
            }
        }
    }

    @Test("Fed from a budget, the ring draws what the budget's progress says, for every kind of day")
    func budgetFedRingDrawsTheBudgetsProgress() {
        for kind in AuditBudgetKind.allCases {
            let target = auditBudget(kind, consumed: 0).adjustedTarget
            for total in auditTotals(around: target) + [-500] {
                let budget = auditBudget(kind, consumed: total)
                let ring = CalorieRingProgress(budget: budget, animatedProgress: budget.displayedRingProgress)
                let fill = budget.displayedRingProgress
                let expected = fill < CalorieRingProgress.minimumVisibleProgress ? 0 : fill

                #expect(abs(drawnLength(ring) - expected) < 1e-12, "\(kind) total \(total)")
                #expect(ring.dynamicTrack.isVisible == budget.hasDynamicIncrease, "\(kind) total \(total)")
                #expect(ring.baseArc.end <= 1, "\(kind) total \(total)")
            }
        }
    }

    @Test("A negative total, which the budget does not floor, leaves the ring undrawn")
    func negativeTotalLeavesTheRingEmpty() {
        let budget = auditBudget(.staticRound, consumed: -500)
        let ring = CalorieRingProgress(budget: budget, animatedProgress: budget.displayedRingProgress)

        #expect(budget.displayedRingProgress < 0)
        #expect(ring.baseArc.isVisible == false)
        #expect(ring.dynamicArc.isVisible == false)
        #expect(drawnLength(ring) == 0)
    }
}

@MainActor
@Suite("Calorie donut identity audit")
struct AuditCalorieDonutIdentityTests {
    @Test("A day the budget calls over has nothing remaining on the donut, whatever the meals add up to")
    func overDecisionWinsOverTheMealSum() {
        let donut = CalorieDonutSummary(mealTotals: [.lunch: 500], budget: 2_000, isOver: true)

        #expect(donut.isOver)
        #expect(donut.eatenKcal == 500)
        #expect(donut.budgetKcal == 2_000)
        #expect(donut.remainingKcal == 0)
        #expect(donut.overKcal == 0)
        #expect(donut.sectors == [.init(kind: .meal(.lunch), kcal: 500)])
        #expect(donut.hasOverSector == false)
    }

    @Test("Every sector and legend row has its own identity, named after what it draws")
    func identitiesAreUniqueAndDescriptive() {
        let days: [([MealType: Double], Double, Bool)] = [
            ([:], 2_000, false),
            ([.breakfast: 300, .lunch: 600, .dinner: 700, .snack: 100], 2_000, false),
            ([.breakfast: 300, .lunch: 600, .dinner: 1_400, .snack: 100], 2_000, true),
            ([.dinner: 500], 0, true),
        ]

        for (totals, budget, isOver) in days {
            let donut = CalorieDonutSummary(mealTotals: totals, budget: budget, isOver: isOver)

            #expect(donut.sectors.map(\.id) == donut.sectors.map(\.kind))
            #expect(Set(donut.sectors.map(\.id)).count == donut.sectors.count)
            #expect(donut.legend.map(\.id) == donut.legend.map(\.key))
            #expect(Set(donut.legend.map(\.id)).count == donut.legend.count)
        }
    }
}
