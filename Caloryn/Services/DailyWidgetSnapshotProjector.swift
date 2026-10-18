import Foundation

@MainActor
enum DailyWidgetSnapshotProjector {
    static func makeSnapshot(
        profile: UserProfile?,
        entries: [FoodLogEntry],
        activeEnergyKcal: Double = 0,
        recentActiveEnergySamples: [DailyActiveEnergySample] = [],
        isActivityLoading: Bool = false,
        activityMessage: String? = nil,
        activityRefreshedAt: Date? = nil,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> DailyWidgetSnapshot {
        guard let profile else {
            return .needsOnboarding(at: now, calendar: calendar)
        }

        let dayStart = calendar.startOfDay(for: now)
        let dayEntries = entries.filter { calendar.isDate($0.date, inSameDayAs: dayStart) }
        let consumedCalories = dayEntries.reduce(0) { $0 + $1.calories }
        let mealCalories = mealCalories(for: dayEntries)
        let budget = profile.activityBudget(
            consumed: consumedCalories,
            activeEnergyKcal: activeEnergyKcal,
            recentActiveEnergySamples: recentActiveEnergySamples,
            isActivityLoading: isActivityLoading,
            activityMessage: activityMessage,
            date: dayStart
        )

        return DailyWidgetSnapshot(
            generatedAt: now,
            dayStart: dayStart,
            state: .ready,
            calories: WidgetCalorieSummary(
                consumed: consumedCalories,
                baseTarget: budget.baseTarget,
                target: budget.adjustedTarget,
                dynamicAdjustment: budget.dynamicAdjustment,
                mealCalories: mealCalories
            ),
            usesDynamicTarget: profile.effectiveEnergyCalculationMode == .dynamicHealth,
            activityRefreshedAt: activityRefreshedAt
        )
    }

    static func mealCalories(for dayEntries: [FoodLogEntry]) -> [WidgetMeal: Double] {
        dayEntries.reduce(into: [:]) { totals, entry in
            totals[entry.mealType.widgetMeal, default: 0] += entry.calories
        }
    }
}
