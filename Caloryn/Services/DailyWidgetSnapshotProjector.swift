import Foundation

@MainActor
enum DailyWidgetSnapshotProjector {
    static func makeSnapshot(
        profile: UserProfile?,
        entries: [FoodLogEntry],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> DailyWidgetSnapshot {
        guard let profile else {
            return .needsOnboarding(at: now, calendar: calendar)
        }

        let dayStart = calendar.startOfDay(for: now)
        let dayEntries = DayFoodLogSelection.entries(entries, on: dayStart, calendar: calendar, date: \.date)
        let consumedCalories = dayEntries.reduce(0) { $0 + $1.calories }
        let mealCalories = mealCalories(for: dayEntries)
        let budget = profile.calorieBudget(consumed: consumedCalories)

        return DailyWidgetSnapshot(
            generatedAt: now,
            dayStart: dayStart,
            state: .ready,
            calories: WidgetCalorieSummary(
                consumed: consumedCalories,
                target: budget.target,
                mealCalories: mealCalories
            )
        )
    }

    static func mealCalories(for dayEntries: [FoodLogEntry]) -> [WidgetMeal: Double] {
        dayEntries.reduce(into: [:]) { totals, entry in
            totals[entry.mealType.widgetMeal, default: 0] += entry.calories
        }
    }
}
