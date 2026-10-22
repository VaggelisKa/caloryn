import Foundation
import Testing
@testable import Caloryn

@Suite("CalorieBudget")
struct CalorieBudgetTests {
    @Test("Given a zero target, when the budget reports, then everything eaten is over")
    func zeroTargetIsSafe() {
        let budget = CalorieBudget(consumed: 500, target: 0)

        #expect(budget.remaining == 0)
        #expect(budget.overAmount == 500)
        #expect(budget.isOver)
    }

    @Test("Given a negative target, when the budget reports, then remaining stays clamped at zero")
    func negativeTargetIsClampedForDisplay() {
        let budget = CalorieBudget(consumed: 100, target: -500)

        #expect(budget.target == -500)
        #expect(budget.remaining == 0)
        #expect(budget.overAmount == 600)
    }

    @Test("Given fractional consumption just above the target, when the budget reports, then it is not over budget by zero")
    func fractionalOverConsumptionAgreesWithTheOverAmount() {
        let budget = CalorieBudget(consumed: 2_000.4, target: 2_000)

        #expect(budget.isOver == false)
        #expect(budget.overAmount == 0)
        #expect(budget.remaining == 0)
    }

    @Test("Given consumption just below the target, when the budget reports, then it is neither over nor has calories left")
    func fractionalUnderConsumptionRoundsRemainingToZero() {
        let budget = CalorieBudget(consumed: 1_999.6, target: 2_000)

        #expect(budget.isOver == false)
        #expect(budget.remaining == 0)
        #expect(budget.overAmount == 0)
    }

    @Test(
        "Given any consumption, when the budget reports, then over-budget agrees with the over amount",
        arguments: [0.0, 1_999.4, 1_999.6, 2_000.0, 2_000.4, 2_000.6, 2_001.0, 3_000.5]
    )
    func isOverAgreesWithTheOverAmount(consumed: Double) {
        let budget = CalorieBudget(consumed: consumed, target: 2_000)

        #expect(budget.isOver == (budget.overAmount > 0))
    }

    @Test("A profile's budget is its saved daily target, and carries its manual flag")
    func profileBudgetUsesTheSavedTarget() {
        let profile = UserProfile(
            age: 30,
            sex: .female,
            heightCm: 165,
            weightKg: 60,
            activityLevel: .moderatelyActive,
            dailyCalorieTarget: 1_850,
            manualOverride: true
        )

        let budget = profile.calorieBudget(consumed: 600)

        #expect(budget.target == 1_850)
        #expect(budget.remaining == 1_250)
        #expect(budget.isManualOverride)
    }
}
