import Foundation
import Testing
@testable import Caloryn

/// Characterizes the log -> reminder-plan boundary that
/// `Caloryn/Services/DailyReminderBridge.swift` sits on top of.
///
/// `DailyReminderBridge` itself cannot be unit tested directly:
///
/// - Its `currentPlan` computation is a `private` computed property on the
///   `View` (not reachable even via `@testable import`), so it cannot be
///   invoked from a test.
/// - Its two `@AppStorage` properties (`dailyReminderEnabled`,
///   `dailyReminderMinutesFromMidnight`) bind to `UserDefaults.standard`
///   with no injectable suite, so hosting the real view in a test would
///   read/depend on ambient global state (and any mutation would pollute
///   real app defaults across test runs on the shared simulator).
/// - Its `scheduler` is a hardcoded `@State private var scheduler =
///   DailyReminderScheduler()`, which itself wraps the real
///   `UNUserNotificationCenter.current()` with no injection point (contrast
///   with `DailyReminderScheduler`'s own `ReminderNotificationCenter` seam,
///   which the existing `DailyReminderSchedulerTests` exploit). There is no
///   way to observe what the bridge would have scheduled without touching
///   the live notification center.
///
/// Per the task constraints, none of these seams were added to production
/// code. What *is* tested here, safely and deterministically, is the
/// production formula the bridge feeds into `DailyReminderPlanner`: turning
/// today's real `FoodLogEntry` values into `remainingToday`, using the real
/// `FoodLogEntry.calories` and `Date.isToday` production code. The
/// arithmetic combining them (lines 18-30 of DailyReminderBridge.swift) is
/// mirrored here in `remainingToday(from:target:now:)` because it is
/// private and cannot be called directly -- see the final report for this
/// gap. `DailyReminderPlanner.makePlan` itself is called for real, so this
/// complements (not duplicates) `DailyReminderPlannerTests`, which never
/// exercises `FoodLogEntry` at all.
@MainActor
struct DailyReminderBridgeTests {

    /// Mirrors `DailyReminderBridge.currentPlan`'s derivation of
    /// `remainingToday` (Caloryn/Services/DailyReminderBridge.swift:19-27).
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
        let food = makeTestFoodItem(caloriesPer100g: 500) // 100g portion -> 500 kcal
        let today = makeTestEntry(date: .now, foodItem: food, portionGrams: 100)

        let remaining = remainingToday(from: [today], target: 2_000, now: .now)

        #expect(remaining == 1_500)
    }

    @Test("Given today's entries sum above the target, when deriving remaining, then remaining floors at zero instead of going negative")
    func remainingFloorsAtZeroWhenTodayExceedsTarget() {
        let food = makeTestFoodItem(caloriesPer100g: 2_500) // 100g portion -> 2500 kcal
        let today = makeTestEntry(date: .now, foodItem: food, portionGrams: 100)

        let remaining = remainingToday(from: [today], target: 2_000, now: .now)

        #expect(remaining == 0)
    }

    @Test("Given today's consumption exceeds the target, when deriving the plan, then today's reminder is skipped for falling below the minimum threshold")
    func todaysReminderIsSkippedWhenGoalAlreadyExceeded() {
        // `Date.isToday` (used by the production formula) compares against the
        // real device clock, not an injected `now`, so the entry and the
        // planner's `now` must both be `.now` for the filtering to line up.
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
        // 100g of a 199.6 kcal/100g food is exactly 199.6 kcal -> rounds to 200.
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
