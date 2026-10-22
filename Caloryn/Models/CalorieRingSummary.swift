import Foundation

struct CalorieRingSummary: Equatable {
    let isOver: Bool
    let remaining: Int
    let overAmount: Int
    let roundedConsumed: Int
    let target: Int

    init(
        isOver: Bool,
        remaining: Int,
        overAmount: Int,
        roundedConsumed: Int,
        target: Int
    ) {
        self.isOver = isOver
        self.remaining = remaining
        self.overAmount = overAmount
        self.roundedConsumed = roundedConsumed
        self.target = target
    }

    init(budget: CalorieBudget) {
        self.init(
            isOver: budget.isOver,
            remaining: budget.remaining,
            overAmount: budget.overAmount,
            roundedConsumed: budget.roundedConsumed,
            target: budget.target
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

    var accessibilityLabel: String {
        if isOver {
            return "Calorie ring, \(roundedConsumed) eaten, \(overAmount) calories over a \(target) calorie goal"
        }

        return "Calorie ring, \(remaining) remaining of \(target) calories, \(roundedConsumed) eaten"
    }

    var accessibilityValue: String {
        if isOver {
            return "\(roundedConsumed) eaten, \(overAmount) calories over target of \(target)"
        }

        return "\(roundedConsumed) eaten, \(remaining) remaining of \(target)"
    }

    static func accessibilityHint(isInteractive: Bool) -> String {
        isInteractive ? "Tap or long press to show nutrition details." : ""
    }
}
