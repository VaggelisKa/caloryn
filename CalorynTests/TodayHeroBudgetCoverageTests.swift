import Foundation
import Testing
@testable import Caloryn

@Suite("Today hero from a budget")
struct TodayHeroBudgetCoverageTests {
    private let us = Locale(identifier: "en_US")
    private let danish = Locale(identifier: "da_DK")

    private func budget(consumed: Double, target: Int = 2_000) -> CalorieBudget {
        CalorieBudget(consumed: consumed, target: target)
    }

    private func hero(_ meals: [MealType: Double], target: Int = 2_000, locale: Locale? = nil) -> TodayHeroSummary {
        let eaten = MealType.allCases.compactMap { meals[$0] }.reduce(0, +)
        return TodayHeroSummary(mealTotals: meals, budget: budget(consumed: eaten, target: target), locale: locale ?? us)
    }

    @Test("Under budget it counts down from the budget's target and lists each meal's own kcal")
    func underBudget() {
        let summary = hero([.breakfast: 382, .lunch: 463, .snack: 118])

        #expect(summary.isOver == false)
        #expect(summary.headline == 1_037)
        #expect(summary.headlineText == "1,037")
        #expect(summary.caption == "kcal left of 2,000")
        #expect(summary.eatenLine == "963 of 2,000 eaten")
        #expect(summary.donut.legend.map(summary.legendValue(for:)) == ["382", "463", "118", "not yet"])
        #expect(summary.donut.legend.map(summary.legendName(for:)) == ["Breakfast", "Lunch", "Snack", "Dinner"])
    }

    @Test("Eating exactly the budget leaves nothing and is not over")
    func exactlyOnBudget() {
        let summary = hero([.lunch: 800, .dinner: 1_200])

        #expect(summary.isOver == false)
        #expect(summary.headline == 0)
        #expect(summary.caption == "kcal left of 2,000")
        #expect(summary.eatenLine == "2,000 of 2,000 eaten")
        #expect(summary.donut.hasOverSector == false)
    }

    @Test("Half a kcal past the budget rounds up to one over, and the donut agrees")
    func halfAKcalOverRoundsUp() {
        let summary = hero([.breakfast: 1_000.25, .dinner: 1_000.25])

        #expect(summary.isOver)
        #expect(summary.headline == 1)
        #expect(summary.headlineText == "+1")
        #expect(summary.caption == "kcal over 2,000")
        #expect(summary.eatenLine == "2,001 of 2,000 eaten")
        #expect(summary.donut.isOver)
        #expect(summary.donut.legend.map(summary.legendValue(for:)) == ["1,000", "not yet", "not yet", "1,000", "1"])
        #expect(summary.donut.legend.last.map(summary.legendName(for:)) == "Over")
    }

    @Test("Just under half a kcal past the budget rounds down and is still on budget")
    func justUnderHalfAKcalOverRoundsDown() {
        let summary = hero([.dinner: 2_000.49])

        #expect(summary.isOver == false)
        #expect(summary.headline == 0)
        #expect(summary.caption == "kcal left of 2,000")
        #expect(summary.eatenLine == "2,000 of 2,000 eaten")
        #expect(summary.donut.isOver == false)
        #expect(summary.donut.legend.count == MealType.allCases.count)
    }

    @Test("Well over budget the headline is the signed overshoot")
    func wellOverBudget() {
        let summary = hero([.breakfast: 900, .dinner: 1_200, .snack: 640.4])

        #expect(summary.headline == 740)
        #expect(summary.headlineText == "+740")
        #expect(summary.eatenLine == "2,740 of 2,000 eaten")
        #expect(summary.donut.legend.last.map(summary.legendValue(for:)) == "740")
    }

    @Test("Nothing eaten shows the whole budget left and every meal not yet logged")
    func nothingEaten() {
        let summary = hero([:], target: 1_800)

        #expect(summary.headline == 1_800)
        #expect(summary.caption == "kcal left of 1,800")
        #expect(summary.eatenLine == "0 of 1,800 eaten")
        #expect(summary.donut.legend.map(summary.legendValue(for:)) == ["not yet", "not yet", "not yet", "not yet"])
    }

    @Test("A budget below the safety floor is printed as the budget gives it")
    func staticTargetIsTakenAsGiven() {
        let summary = hero([.lunch: 400], target: 1_000)

        #expect(summary.headline == 600)
        #expect(summary.caption == "kcal left of 1,000")
    }

    @Test("Figures are grouped for the reader's locale")
    func groupedForTheLocale() {
        let summary = hero([.breakfast: 1_250], target: 2_500, locale: danish)

        #expect(summary.headlineText == "1.250")
        #expect(summary.caption == "kcal left of 2.500")
        #expect(summary.eatenLine == "1.250 of 2.500 eaten")
        #expect(summary.legendValue(for: summary.donut.legend[0]) == "1.250")
    }
}
