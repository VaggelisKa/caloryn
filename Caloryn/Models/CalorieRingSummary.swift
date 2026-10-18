import Foundation

struct CalorieRingSummary: Equatable {
    enum Cue: Equatable {
        case none
        case updating
        case increase(Int)
        case reduction(Int)

        var text: String? {
            switch self {
            case .none:
                nil
            case .updating:
                "updating"
            case .increase(let increase):
                "+\(increase) dynamic"
            case .reduction(let adjustment):
                "\(adjustment) dynamic"
            }
        }

        var accessibilityLabel: String? {
            switch self {
            case .none, .updating:
                nil
            case .increase(let increase):
                "\(increase) calorie auto-adjust increase"
            case .reduction(let adjustment):
                "\(abs(adjustment)) calorie auto-adjust reduction"
            }
        }
    }

    let isOver: Bool
    let remaining: Int
    let overAmount: Int
    let roundedConsumed: Int
    let adjustedTarget: Int
    let dynamicIncrease: Int
    let dynamicAdjustment: Int
    let hasDynamicIncrease: Bool
    let hasDynamicReduction: Bool
    let isActivityLoading: Bool

    init(
        isOver: Bool,
        remaining: Int,
        overAmount: Int,
        roundedConsumed: Int,
        adjustedTarget: Int,
        dynamicIncrease: Int = 0,
        dynamicAdjustment: Int = 0,
        hasDynamicIncrease: Bool = false,
        hasDynamicReduction: Bool = false,
        isActivityLoading: Bool = false
    ) {
        self.isOver = isOver
        self.remaining = remaining
        self.overAmount = overAmount
        self.roundedConsumed = roundedConsumed
        self.adjustedTarget = adjustedTarget
        self.dynamicIncrease = dynamicIncrease
        self.dynamicAdjustment = dynamicAdjustment
        self.hasDynamicIncrease = hasDynamicIncrease
        self.hasDynamicReduction = hasDynamicReduction
        self.isActivityLoading = isActivityLoading
    }

    init(budget: ActivityCalorieBudget) {
        self.init(
            isOver: budget.isOver,
            remaining: budget.remaining,
            overAmount: budget.overAmount,
            roundedConsumed: budget.roundedConsumed,
            adjustedTarget: budget.adjustedTarget,
            dynamicIncrease: budget.dynamicIncrease,
            dynamicAdjustment: budget.dynamicAdjustment,
            hasDynamicIncrease: budget.hasDynamicIncrease,
            hasDynamicReduction: budget.hasDynamicReduction,
            isActivityLoading: budget.isActivityLoading
        )
    }

    var accent: NutritionDetailsSummary.CalorieAccent {
        NutritionDetailsSummary.calorieAccent(isOver: isOver)
    }

    var centerValue: Int {
        isOver ? overAmount : remaining
    }

    var centerCaption: String {
        isOver ? "over" : "remaining"
    }

    var eatenText: String {
        "\(roundedConsumed) eaten"
    }

    var cue: Cue {
        if isActivityLoading {
            return .updating
        }
        if hasDynamicIncrease {
            return .increase(dynamicIncrease)
        }
        if hasDynamicReduction {
            return .reduction(dynamicAdjustment)
        }
        return .none
    }

    var accessibilityLabel: String {
        let activityDescription = hasDynamicIncrease
            ? ", includes \(dynamicIncrease) calorie auto-adjust increase"
            : ""

        if isOver {
            return "Calorie ring, \(roundedConsumed) eaten, \(overAmount) calories over a \(adjustedTarget) calorie goal\(activityDescription)"
        }

        return "Calorie ring, \(remaining) remaining of \(adjustedTarget) calories, \(roundedConsumed) eaten\(activityDescription)"
    }

    var accessibilityValue: String {
        if isOver {
            return "\(roundedConsumed) eaten, \(overAmount) calories over target of \(adjustedTarget)"
        }

        return "\(roundedConsumed) eaten, \(remaining) remaining of \(adjustedTarget)"
    }

    static func accessibilityHint(isInteractive: Bool) -> String {
        isInteractive ? "Tap or long press to show nutrition details." : ""
    }
}
