import Foundation

struct HistoryRecurringCaloriePatternDetailSummary: Equatable {
    static let minusSign = "−"

    let kind: HistoryRecurringCaloriePatternKind
    let outcomeTargetText: String
    let weekdayName: String
    let mealType: MealType
    let supportingDayCount: Int
    let cohortDayCount: Int
    let outcomeComparisonCount: Int
    let outcomeComparisonDayCount: Int
    let mealComparisonDayCount: Int
    let mealDifferenceCalories: Double

    init(
        kind: HistoryRecurringCaloriePatternKind,
        outcomeTargetText: String,
        weekdayName: String,
        mealType: MealType,
        supportingDayCount: Int,
        cohortDayCount: Int,
        outcomeComparisonCount: Int,
        outcomeComparisonDayCount: Int,
        mealComparisonDayCount: Int,
        mealDifferenceCalories: Double
    ) {
        self.kind = kind
        self.outcomeTargetText = outcomeTargetText
        self.weekdayName = weekdayName
        self.mealType = mealType
        self.supportingDayCount = supportingDayCount
        self.cohortDayCount = cohortDayCount
        self.outcomeComparisonCount = outcomeComparisonCount
        self.outcomeComparisonDayCount = outcomeComparisonDayCount
        self.mealComparisonDayCount = mealComparisonDayCount
        self.mealDifferenceCalories = mealDifferenceCalories
    }

    var supportingTitle: String {
        switch kind {
        case .weekdayMeal:
            "Logged \(weekdayName)s"
        case .mealOnly:
            "\(outcomeTargetText.capitalized) days"
        }
    }

    var supportingValue: String {
        switch kind {
        case .weekdayMeal:
            "\(supportingDayCount) of \(cohortDayCount)"
        case .mealOnly:
            "\(supportingDayCount)"
        }
    }

    var supportingDetail: String {
        switch kind {
        case .weekdayMeal:
            outcomeTargetText
        case .mealOnly:
            "supporting logged days"
        }
    }

    var comparisonTitle: String { "Other logged days" }

    var comparisonValue: String {
        switch kind {
        case .weekdayMeal:
            "\(outcomeComparisonCount) of \(outcomeComparisonDayCount)"
        case .mealOnly:
            "\(mealComparisonDayCount)"
        }
    }

    var comparisonDetail: String {
        switch kind {
        case .weekdayMeal:
            outcomeTargetText
        case .mealOnly:
            "comparison logged days"
        }
    }

    var mealComparisonTitle: String { "\(mealType.displayName) comparison" }

    var mealDifferenceText: String {
        let magnitude = abs(mealDifferenceCalories).rounded().truncatedSafely.formatted()
        let sign = mealDifferenceCalories >= 0 ? "+" : Self.minusSign
        return "\(sign)\(magnitude) kcal"
    }

    var mealDifferenceCaption: String {
        "Average difference versus other eligible logged days"
    }
}

struct HistoryRecurringCaloriePatternDayRow: Equatable {
    let dateText: String
    let totalCalories: Double
    let dailyCalorieTarget: Int
    let mealCalories: Double
    let mealType: MealType
    let isExpanded: Bool

    init(
        dateText: String,
        totalCalories: Double,
        dailyCalorieTarget: Int,
        mealCalories: Double,
        mealType: MealType,
        isExpanded: Bool
    ) {
        self.dateText = dateText
        self.totalCalories = totalCalories
        self.dailyCalorieTarget = dailyCalorieTarget
        self.mealCalories = mealCalories
        self.mealType = mealType
        self.isExpanded = isExpanded
    }

    var mealName: String { HistoryMealLabel.rowTitle(for: mealType) }

    var totalsText: String {
        "\(totalCalories.rounded().truncatedSafely.formatted()) kcal logged, \(dailyCalorieTarget.formatted()) kcal target"
    }

    var mealCaloriesText: String {
        mealCalories.rounded().truncatedSafely.kcalFormatted
    }

    var accessibilityLabel: String {
        "\(dateText), \(totalCalories.rounded().truncatedSafely.formatted()) kcal logged, \(dailyCalorieTarget.formatted()) kcal target, \(mealName), \(mealCaloriesText)"
    }

    var accessibilityValue: String {
        isExpanded ? "Expanded" : "Collapsed"
    }

    var accessibilityHint: String {
        isExpanded ? "Collapses contributing foods" : "Expands contributing foods"
    }

    var expandedSectionTitle: String {
        "Foods logged in \(mealName.lowercased())"
    }

    var expandedEmptyText: String {
        "No \(mealName.lowercased()) calories were logged."
    }
}
