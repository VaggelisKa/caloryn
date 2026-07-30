import Foundation

/// The evidence wording on the recurring-calorie pattern drill-down.
///
/// The two pattern kinds count different things: a weekday pattern compares a
/// cohort of same-weekday days against the rest, while a meal-only pattern has
/// no cohort and simply counts the days on each side. Every label on the
/// evidence card turns on that distinction, so it is taken as a fact along with
/// the counts, and no view re-derives it.
struct HistoryRecurringCaloriePatternDetailSummary: Equatable {
    /// Chosen so a negative difference reads as a true minus sign rather than
    /// a hyphen, which renders too short beside the digits.
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

    // MARK: - Supporting group

    var supportingTitle: String {
        switch kind {
        case .weekdayMeal:
            "Logged \(weekdayName)s"
        case .mealOnly:
            "\(outcomeTargetText.capitalized) days"
        }
    }

    /// A weekday pattern's supporting days are a share of that weekday's
    /// cohort; a meal-only pattern's are a bare count with nothing to divide by.
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

    // MARK: - Comparison group

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

    // MARK: - Meal comparison

    /// Singular here: this heading names the meal, not a row of several.
    var mealComparisonTitle: String { "\(mealType.displayName) Comparison" }

    /// Zero reads as "+0 kcal" — the sign is about direction of the pattern,
    /// and a pattern with no difference never reaches this screen.
    var mealDifferenceText: String {
        let magnitude = abs(mealDifferenceCalories).rounded().truncatedSafely.formatted()
        let sign = mealDifferenceCalories >= 0 ? "+" : Self.minusSign
        return "\(sign)\(magnitude) kcal"
    }

    var mealDifferenceCaption: String {
        "Average difference versus other eligible logged days"
    }
}

/// One supporting-day row on the recurring-calorie pattern drill-down.
///
/// Takes the day's already-formatted date alongside its numbers: the date
/// wording ("Today", "Yesterday", "Mon, 3 Feb") is a calendar decision the row
/// has no business repeating.
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
        "\(totalCalories.rounded().truncatedSafely.formatted()) kcal logged · \(dailyCalorieTarget.formatted()) kcal target"
    }

    var mealCaloriesText: String {
        mealCalories.rounded().truncatedSafely.kcalFormatted
    }

    /// The row is one element to VoiceOver: read piecemeal it is four
    /// unattributed numbers.
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
