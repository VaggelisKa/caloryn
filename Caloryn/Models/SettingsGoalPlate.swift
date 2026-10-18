import Foundation

/// The mini plate that leads the Settings goal group: what today has put on the plate the
/// goal sets, so the row reads as the same plate Today draws, not a decoration.
///
/// Takes each of today's entries as its meal and kcal rather than the `FoodLogEntry`, so the
/// rule is reachable without a store. `CalorieDonutSummary` does the rest.
enum SettingsGoalPlate {
    struct Entry: Equatable {
        let meal: MealType
        let calories: Double

        init(meal: MealType, calories: Double) {
            self.meal = meal
            self.calories = calories
        }
    }

    /// Each meal's kcal, summed. Snacks share one meal however many slots they were logged
    /// in, as they share one colour on the plate. A meal with nothing logged is absent.
    static func mealTotals(_ entries: [Entry]) -> [MealType: Double] {
        entries.reduce(into: [:]) { totals, entry in
            totals[entry.meal, default: 0] += entry.calories
        }
    }

    /// Everything eaten today, the `consumed` figure the day's budget is built from.
    static func eaten(_ entries: [Entry]) -> Double {
        entries.reduce(0) { $0 + $1.calories }
    }
}
