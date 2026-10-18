import Foundation
import Testing
@testable import Caloryn

@MainActor
struct DailyReminderBridgeTests {
    private func remainingToday(from entries: [FoodLogEntry], target: Int?, now: Date) -> Int? {
        let consumedToday = entries
            .filter { $0.date.isToday }
            .reduce(0) { $0 + $1.calories }
        return target.map { max(0, $0 - Int(consumedToday.rounded())) }
    }

    @Test("Given no entries logged today, when deriving the plan, then remaining equals the full target")
    func noEntriesTodayLeavesFullTargetRemaining() {
        let food = makeTestFoodItem(caloriesPer100g: 500)
        let yesterday = makeTestEntry(date: makeTestDate(year: 2020, month: 1, day: 1), foodItem: food, portionGrams: 100)

        let plan = DailyReminderPlanner.makePlan(
            isEnabled: true,
            remainingToday: remainingToday(from: [yesterday], target: 2_000, now: .now),
            fullDayTarget: 2_000
        )

        #expect(plan.first?.title == "🔥 2000 calories to go")
    }

    @Test("Given entries logged only on other days, when deriving remaining, then they are excluded from today's total")
    func entriesFromOtherDaysAreExcludedFromToday() {
        let food = makeTestFoodItem(caloriesPer100g: 900)
        let farInThePast = makeTestEntry(date: makeTestDate(year: 2020, month: 1, day: 1), foodItem: food, portionGrams: 100)

        let remaining = remainingToday(from: [farInThePast], target: 2_000, now: .now)

        #expect(remaining == 2_000)
    }

    @Test("Given today's entries sum below the target, when deriving remaining, then remaining is the exact difference")
    func todaysEntriesReduceRemainingByConsumedAmount() {
        let food = makeTestFoodItem(caloriesPer100g: 500)
        let today = makeTestEntry(date: .now, foodItem: food, portionGrams: 100)

        let remaining = remainingToday(from: [today], target: 2_000, now: .now)

        #expect(remaining == 1_500)
    }

    @Test("Given today's entries sum above the target, when deriving remaining, then remaining floors at zero instead of going negative")
    func remainingFloorsAtZeroWhenTodayExceedsTarget() {
        let food = makeTestFoodItem(caloriesPer100g: 2_500)
        let today = makeTestEntry(date: .now, foodItem: food, portionGrams: 100)

        let remaining = remainingToday(from: [today], target: 2_000, now: .now)

        #expect(remaining == 0)
    }

    @Test("Given today's consumption exceeds the target, when deriving the plan, then today's reminder is skipped for falling below the minimum threshold")
    func todaysReminderIsSkippedWhenGoalAlreadyExceeded() {
        let now = Date.now
        let food = makeTestFoodItem(caloriesPer100g: 2_500)
        let today = makeTestEntry(date: now, foodItem: food, portionGrams: 100)

        let plan = DailyReminderPlanner.makePlan(
            isEnabled: true,
            remainingToday: remainingToday(from: [today], target: 2_000, now: now),
            fullDayTarget: 2_000,
            now: now
        )

        let todaysIdentifier = DailyReminderPlanner.identifier(for: now)
        #expect(!plan.contains { $0.identifier == todaysIdentifier })
    }

    @Test("Given fractional total calories logged today, when deriving remaining, then the total rounds before subtracting")
    func fractionalCaloriesRoundBeforeSubtracting() {
        let food = makeTestFoodItem(caloriesPer100g: 199.6)
        let today = makeTestEntry(date: .now, foodItem: food, portionGrams: 100)

        let remaining = remainingToday(from: [today], target: 2_000, now: .now)

        #expect(remaining == 1_800)
    }

    @Test("Given multiple entries logged today across meals, when deriving remaining, then their calories are summed together")
    func multipleTodayEntriesAreSummed() {
        let breakfast = makeTestEntry(date: .now, mealType: .breakfast, foodItem: makeTestFoodItem(caloriesPer100g: 300), portionGrams: 100)
        let lunch = makeTestEntry(date: .now, mealType: .lunch, foodItem: makeTestFoodItem(caloriesPer100g: 400), portionGrams: 100)
        let dinner = makeTestEntry(date: .now, mealType: .dinner, foodItem: makeTestFoodItem(caloriesPer100g: 300), portionGrams: 100)

        let remaining = remainingToday(from: [breakfast, lunch, dinner], target: 2_000, now: .now)

        #expect(remaining == 1_000)
    }

    @Test("Given no profile target, when deriving the plan, then no reminders are planned at all")
    func missingTargetProducesNoReminders() {
        let plan = DailyReminderPlanner.makePlan(
            isEnabled: true,
            remainingToday: remainingToday(from: [], target: nil, now: .now),
            fullDayTarget: nil
        )

        #expect(plan.isEmpty)
    }
}
