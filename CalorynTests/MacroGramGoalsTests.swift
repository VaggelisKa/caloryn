import Foundation
import Testing
@testable import Caloryn

@Suite("Macro gram goals")
struct MacroGramGoalsTests {
    @Test("Typed grams report the calories they account for and their share of the calorie target")
    func summaryAndShares() {
        let goals = MacroGramGoals(proteinText: "150", carbText: "180", fatText: "50")

        #expect(goals.isValid)
        #expect(goals.accountedCalories == 1_770)
        #expect(goals.sharePercent(for: .protein, calorieTarget: 1_800) == 33)
        #expect(goals.sharePercent(for: .carbs, calorieTarget: 1_800) == 40)
        #expect(goals.sharePercent(for: .fat, calorieTarget: 1_800) == 25)
        #expect(
            goals.accountSummary(calorieTarget: 1_800, locale: Locale(identifier: "en_US"))
                == "Macros account for 1,770 of 1,800 kcal"
        )
    }

    @Test("A decimal comma is a gram goal")
    func decimalCommaIsAGramGoal() {
        let goals = MacroGramGoals(proteinText: "150,5", carbText: "180", fatText: "50")

        #expect(goals.grams(for: .protein) == 150.5)
        #expect(goals.isValid)
    }

    @Test("Zero, blank, and non-numeric text are not a gram goal", arguments: ["", "0", "-5", "abc", "1e3"])
    func invalidTextIsNotAGoal(text: String) {
        let goals = MacroGramGoals(proteinText: text, carbText: "180", fatText: "50")

        #expect(goals.grams(for: .protein) == nil)
        #expect(!goals.isValid)
        #expect(goals.accountSummary(calorieTarget: 1_800) == nil)
        #expect(goals.snappedRatios() == nil)
    }

    @Test("Snapping turns gram goals into a split that totals 100%")
    func snappingTotalsOneHundredPercent() {
        let goals = MacroGramGoals(proteinText: "150", carbText: "180", fatText: "50")
        let snapped = goals.snappedRatios()

        #expect(snapped != nil)
        let total = (snapped?.protein ?? 0) + (snapped?.carbs ?? 0) + (snapped?.fat ?? 0)
        #expect(abs(total - 1) < 1e-12)
        #expect(abs((snapped?.protein ?? 0) - (600.0 / 1_770)) < 1e-12)
    }
}
