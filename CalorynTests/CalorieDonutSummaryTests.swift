import Foundation
import Testing
@testable import Caloryn

struct CalorieDonutSummaryTests {
    @Test("Under budget, meals fill the ring in meal order and the rest of the budget is one sector")
    func underBudget() {
        let summary = CalorieDonutSummary(
            mealTotals: [.snack: 118, .lunch: 463, .breakfast: 382],
            budget: 2_000,
            isOver: false
        )

        #expect(summary.sectors == [
            .init(kind: .meal(.breakfast), kcal: 382),
            .init(kind: .meal(.lunch), kcal: 463),
            .init(kind: .meal(.snack), kcal: 118),
            .init(kind: .remaining, kcal: 1_037),
        ])
        #expect(summary.remainingKcal == 1_037)
        #expect(summary.overKcal == 0)
        #expect(summary.eatenKcal == 963)
        #expect(summary.budgetKcal == 2_000)
        #expect(summary.hasOverSector == false)
    }

    @Test("The legend lists every meal in meal order, with an unlogged one marked as not yet")
    func legendListsEveryMeal() {
        let summary = CalorieDonutSummary(
            mealTotals: [.snack: 118, .lunch: 463, .breakfast: 382],
            budget: 2_000,
            isOver: false
        )

        #expect(summary.legend == [
            .init(meal: .breakfast, kcal: 382, isLogged: true),
            .init(meal: .lunch, kcal: 463, isLogged: true),
            .init(meal: .snack, kcal: 118, isLogged: true),
            .init(meal: .dinner, kcal: 0, isLogged: false),
        ])
    }

    @Test("A single meal is one sector followed by what is left")
    func singleMeal() {
        let summary = CalorieDonutSummary(mealTotals: [.dinner: 650.4], budget: 2_000, isOver: false)

        #expect(summary.sectors.map(\.kind) == [.meal(.dinner), .remaining])
        #expect(summary.sectors[0].kcal == 650.4)
        #expect(abs(summary.sectors[1].kcal - 1_349.6) < 0.000_1)
        #expect(summary.remainingKcal == 1_350)
        #expect(summary.legend.filter(\.isLogged).map(\.meal) == [.dinner])
    }

    @Test("Exactly on budget, the meals close the ring with no remaining sector")
    func exactlyOnBudget() {
        let summary = CalorieDonutSummary(
            mealTotals: [.breakfast: 600, .lunch: 700, .dinner: 700],
            budget: 2_000,
            isOver: false
        )

        #expect(summary.sectors.map(\.kind) == [.meal(.breakfast), .meal(.lunch), .meal(.dinner)])
        #expect(summary.sectors.map(\.kcal).reduce(0, +) == 2_000)
        #expect(summary.remainingKcal == 0)
        #expect(summary.overKcal == 0)
    }

    @Test("A sub-calorie overshoot the budget calls on target draws no over sector")
    func subCalorieOvershootFollowsTheBudget() {
        let summary = CalorieDonutSummary(mealTotals: [.lunch: 2_000.4], budget: 2_000, isOver: false)

        #expect(summary.sectors.map(\.kind) == [.meal(.lunch)])
        #expect(summary.remainingKcal == 0)
        #expect(summary.overKcal == 0)
    }

    @Test("Over budget, the ring is everything eaten and the overshoot is a final ink sector")
    func overBudget() {
        let summary = CalorieDonutSummary(
            mealTotals: [.breakfast: 382, .lunch: 463, .dinner: 1_377, .snack: 118],
            budget: 2_000,
            isOver: true
        )

        #expect(summary.sectors.map(\.kind) == [
            .meal(.breakfast), .meal(.lunch), .meal(.snack), .meal(.dinner), .over,
        ])

        let total = summary.sectors.map(\.kcal).reduce(0, +)
        #expect(abs(total - 2_340) < 0.000_1)
        #expect(summary.sectors.last?.kcal == 340)

        let mealShare = summary.sectors.dropLast().map(\.kcal).reduce(0, +)
        #expect(abs(mealShare - 2_000) < 0.000_1)

        #expect(summary.overKcal == 340)
        #expect(summary.remainingKcal == 0)
        #expect(summary.eatenKcal == 2_340)
        #expect(summary.hasOverSector)
    }

    @Test("Over budget, each meal keeps its share of what was eaten relative to the others")
    func overBudgetKeepsMealProportions() {
        let summary = CalorieDonutSummary(
            mealTotals: [.breakfast: 500, .dinner: 1_500],
            budget: 1_600,
            isOver: true
        )

        let breakfast = summary.sectors.first { $0.kind == .meal(.breakfast) }?.kcal ?? 0
        let dinner = summary.sectors.first { $0.kind == .meal(.dinner) }?.kcal ?? 0
        #expect(abs(dinner / breakfast - 3) < 0.000_1)
        #expect(abs(breakfast - 400) < 0.000_1)
        #expect(abs(dinner - 1_200) < 0.000_1)
    }

    @Test("Over budget, the legend still prints each meal's own total, never the scaled sector")
    func overBudgetLegendIsUnscaled() {
        let summary = CalorieDonutSummary(
            mealTotals: [.breakfast: 382, .lunch: 463, .dinner: 1_377, .snack: 118],
            budget: 2_000,
            isOver: true
        )

        #expect(summary.legend.prefix(4).map(\.kcal) == [382, 463, 118, 1_377])
    }

    @Test("Over budget, the legend ends with an Over row carrying the overshoot")
    func overBudgetLegendGainsAnOverRow() {
        let summary = CalorieDonutSummary(
            mealTotals: [.breakfast: 382, .lunch: 463, .dinner: 1_377, .snack: 118],
            budget: 2_000,
            isOver: true
        )

        #expect(summary.legend.map(\.key) == [
            .meal(.breakfast), .meal(.lunch), .meal(.snack), .meal(.dinner), .over,
        ])
        #expect(summary.legend.last == .over(kcal: 340))
        #expect(summary.legend.last?.meal == nil)
    }

    @Test("Under or on budget, the legend has no Over row")
    func underBudgetLegendHasNoOverRow() {
        let under = CalorieDonutSummary(mealTotals: [.lunch: 963], budget: 2_000, isOver: false)
        let onTheLine = CalorieDonutSummary(mealTotals: [.lunch: 2_000.4], budget: 2_000, isOver: false)

        #expect(!under.legend.contains { $0.key == .over })
        #expect(!onTheLine.legend.contains { $0.key == .over })
        #expect(under.legend.count == MealType.allCases.count)
    }

    @Test("The amounts round the way the budget does: each figure first, then the difference")
    func amountsRoundLikeTheBudget() {
        let summary = CalorieDonutSummary(mealTotals: [.lunch: 962.5], budget: 2_000, isOver: false)

        #expect(summary.eatenKcal == 963)
        #expect(summary.remainingKcal == 1_037)
    }

    @Test("With nothing logged the ring is all remaining and every meal is not yet")
    func nothingLogged() {
        let summary = CalorieDonutSummary(mealTotals: [:], budget: 2_000, isOver: false)

        #expect(summary.sectors == [.init(kind: .remaining, kcal: 2_000)])
        #expect(summary.legend.map(\.isLogged) == [false, false, false, false])
        #expect(summary.legend.map(\.meal) == [.breakfast, .lunch, .snack, .dinner])
        #expect(summary.remainingKcal == 2_000)
        #expect(summary.eatenKcal == 0)
    }

    @Test("A meal logged at zero kcal is logged but draws no sector")
    func zeroKcalMealIsLoggedWithoutASector() {
        let summary = CalorieDonutSummary(mealTotals: [.breakfast: 0], budget: 2_000, isOver: false)

        #expect(summary.sectors.map(\.kind) == [.remaining])
        #expect(summary.legend.first == .init(meal: .breakfast, kcal: 0, isLogged: true))
    }

    @Test("A zero budget with nothing eaten has nothing to draw")
    func zeroBudgetNothingEaten() {
        let summary = CalorieDonutSummary(mealTotals: [:], budget: 0, isOver: false)

        #expect(summary.sectors.isEmpty)
        #expect(summary.remainingKcal == 0)
        #expect(summary.overKcal == 0)
    }

    @Test("A zero budget makes everything eaten the overshoot")
    func zeroBudgetWithFoodIsAllOver() {
        let summary = CalorieDonutSummary(mealTotals: [.lunch: 300], budget: 0, isOver: true)

        #expect(summary.sectors == [.init(kind: .over, kcal: 300)])
        #expect(summary.overKcal == 300)
        #expect(summary.legend[1] == .init(meal: .lunch, kcal: 300, isLogged: true))
        #expect(summary.legend.last == .over(kcal: 300))
    }

    @Test(
        "A non-finite or negative budget counts as zero",
        arguments: [Double.nan, .infinity, -.infinity, -500]
    )
    func invalidBudgetCountsAsZero(budget: Double) {
        let empty = CalorieDonutSummary(mealTotals: [:], budget: budget, isOver: false)
        #expect(empty.sectors.isEmpty)
        #expect(empty.budgetKcal == 0)

        let eaten = CalorieDonutSummary(mealTotals: [.dinner: 450], budget: budget, isOver: true)
        #expect(eaten.sectors == [.init(kind: .over, kcal: 450)])
        #expect(eaten.overKcal == 450)
    }

    @Test(
        "A non-finite or negative meal total counts as nothing eaten",
        arguments: [Double.nan, .infinity, -.infinity, -120]
    )
    func invalidMealTotalCountsAsZero(total: Double) {
        let summary = CalorieDonutSummary(
            mealTotals: [.breakfast: total, .lunch: 500],
            budget: 2_000,
            isOver: false
        )

        #expect(summary.sectors == [
            .init(kind: .meal(.lunch), kcal: 500),
            .init(kind: .remaining, kcal: 1_500),
        ])
        #expect(summary.legend[0] == .init(meal: .breakfast, kcal: 0, isLogged: true))
        #expect(summary.eatenKcal == 500)
    }

    @Test("Absurd totals stay finite rather than summing to infinity")
    func absurdTotalsStayFinite() {
        let summary = CalorieDonutSummary(
            mealTotals: [.breakfast: .greatestFiniteMagnitude, .lunch: .greatestFiniteMagnitude],
            budget: 2_000,
            isOver: true
        )

        #expect(summary.sectors.allSatisfy { $0.kcal.isFinite && $0.kcal > 0 })
        #expect(summary.hasOverSector)
    }

    @Test("The budget's own target and over decision are taken as given")
    func readsTheBudget() {
        let budget = CalorieBudget(consumed: 2_130, target: 2_000)
        let summary = CalorieDonutSummary(mealTotals: [.lunch: 1_000, .dinner: 1_130], budget: budget)
        let ring = CalorieRingSummary(budget: budget)

        #expect(summary.isOver == ring.isOver)
        #expect(summary.budgetKcal == ring.target)
        #expect(summary.overKcal == ring.overAmount)
        #expect(summary.eatenKcal == ring.roundedConsumed)
    }
}
