import Foundation

enum SettingsGoalPlate {
    struct Entry: Equatable {
        let meal: MealType
        let calories: Double

        init(meal: MealType, calories: Double) {
            self.meal = meal
            self.calories = calories
        }
    }

    static func mealTotals(_ entries: [Entry]) -> [MealType: Double] {
        entries.reduce(into: [:]) { totals, entry in
            totals[entry.meal, default: 0] += entry.calories
        }
    }

    static func eaten(_ entries: [Entry]) -> Double {
        entries.reduce(0) { $0 + $1.calories }
    }
}
