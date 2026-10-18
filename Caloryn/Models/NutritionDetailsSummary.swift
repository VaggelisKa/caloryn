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

    enum StatusNoticeStyle: Equatable {
        case warning
        case informational
        case neutral
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

    static func showsDynamicTDEE(
        isDynamicModeRequested: Bool,
        activeEnergyKcal: Double,
        dynamicAdjustment: Int,
        hasActivityMessage: Bool
    ) -> Bool {
        isDynamicModeRequested
            || activeEnergyKcal > 0
            || dynamicAdjustment != 0
            || hasActivityMessage
    }

    static func baselineText(activityBaselineKcal: Double?) -> String {
        guard let activityBaselineKcal else {
            return "-"
        }

        return activityBaselineKcal.rounded().kcalFormatted
    }

    static func activeEnergyText(activeEnergyKcal: Double) -> String {
        activeEnergyKcal.rounded().kcalFormatted
    }

    static func dynamicAdjustmentText(_ adjustment: Int) -> String {
        if adjustment > 0 {
            return "+\(adjustment.kcalFormatted)"
        }
        if adjustment < 0 {
            return "-\(abs(adjustment).kcalFormatted)"
        }
        return "0 kcal"
    }

    static func isDynamicAdjustmentMuted(_ adjustment: Int) -> Bool {
        adjustment < 0
    }

    static func statusNoticeStyle(for status: ActivityCalorieBudget.DynamicStatus) -> StatusNoticeStyle {
        switch status {
        case .unavailable:
            .warning
        case .learning:
            .informational
        case .staticEstimate, .ready:
            .neutral
        }
    }
}
