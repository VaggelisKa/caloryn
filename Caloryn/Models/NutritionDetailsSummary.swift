import Foundation

struct NutritionDetailsSummary: Equatable {
    struct Entry: Equatable {
        let nutrition: NutritionValues
        let portionGrams: Double

        init(nutrition: NutritionValues, portionGrams: Double) {
            self.nutrition = nutrition
            self.portionGrams = portionGrams
        }
    }

    enum CalorieAccent: Equatable {
        case withinBudget
        case overBudget
    }

    let totalNutrition: NutritionValues
    let totalPortionGrams: Double
    let loggedItemCount: Int

    init(entries: [Entry]) {
        totalNutrition = entries.reduce(.zero) { $0 + $1.nutrition }
        totalPortionGrams = entries.reduce(0) { $0 + $1.portionGrams }
        loggedItemCount = entries.count
    }

    var totalCalories: Double {
        totalNutrition.calories
    }

    var loggedItemsUnitText: String {
        loggedItemCount == 1 ? "item" : "items"
    }

    static func calorieAccent(isOver: Bool) -> CalorieAccent {
        isOver ? .overBudget : .withinBudget
    }

    static func calorieSummaryLabel(isOver: Bool) -> String {
        isOver ? "Over" : "Remaining"
    }

    static func progressFraction(current: Double, target: Double) -> Double {
        guard target > 0 else { return 0 }
        return min(max(current / target, 0), 1)
    }
}
