import Foundation

struct HistoryRecurringCaloriePatternDetailSummary: Equatable {
    struct Stat: Equatable, Identifiable {
        let value: String
        let label: String

        var id: String { label }
    }

    struct MealBar: Equatable, Identifiable {
        let label: String
        let valueText: String
        let ratio: Double
        let isPatternDays: Bool

        var id: Bool { isPatternDays }
    }

    let kind: HistoryRecurringCaloriePatternKind
    let outcome: HistoryRecurringCalorieOutcome
    let weekdayName: String
    let mealType: MealType
    let supportingDayCount: Int
    let cohortDayCount: Int
    let outcomeComparisonCount: Int
    let outcomeComparisonDayCount: Int
    let eligibleDayCount: Int
    let windowDayCount: Int
    let supportingMealAverageCalories: Double
    let comparisonMealAverageCalories: Double

    init(
        kind: HistoryRecurringCaloriePatternKind,
        outcome: HistoryRecurringCalorieOutcome,
        weekdayName: String,
        mealType: MealType,
        supportingDayCount: Int,
        cohortDayCount: Int,
        outcomeComparisonCount: Int,
        outcomeComparisonDayCount: Int,
        eligibleDayCount: Int,
        windowDayCount: Int,
        supportingMealAverageCalories: Double,
        comparisonMealAverageCalories: Double
    ) {
        self.kind = kind
        self.outcome = outcome
        self.weekdayName = weekdayName
        self.mealType = mealType
        self.supportingDayCount = supportingDayCount
        self.cohortDayCount = cohortDayCount
        self.outcomeComparisonCount = outcomeComparisonCount
        self.outcomeComparisonDayCount = outcomeComparisonDayCount
        self.eligibleDayCount = eligibleDayCount
        self.windowDayCount = windowDayCount
        self.supportingMealAverageCalories = supportingMealAverageCalories
        self.comparisonMealAverageCalories = comparisonMealAverageCalories
    }

    var mealTitle: String {
        HistoryRecurringCaloriePatternWording.mealName(for: mealType)
    }

    var differenceLead: String {
        let verb = HistoryRecurringCaloriePatternWording.agreeing(with: mealType, singular: "is", plural: "are")
        let patternAverage = HistoryRecurringCaloriePatternWording.calories(supportingMealAverageCalories)
        let otherAverage = HistoryRecurringCaloriePatternWording.calories(comparisonMealAverageCalories)
        return "\(mealTitle) \(verb) the difference: \(patternAverage) kcal on \(patternDaysName), \(otherAverage) on other days."
    }

    var basisText: String {
        let dayUnit = eligibleDayCount == 1 ? "day" : "days"
        return "Last \(windowDayCount) days · \(eligibleDayCount) logged \(dayUnit)"
    }

    var outcomeTitle: String { outcome.goalTitle }

    var outcomeStats: [Stat] {
        switch kind {
        case .weekdayMeal:
            [
                Stat(
                    value: "\(supportingDayCount) of \(cohortDayCount)",
                    label: HistoryRecurringCaloriePatternWording.weekdayPlural(weekdayName)
                ),
                Stat(
                    value: "\(outcomeComparisonCount) of \(outcomeComparisonDayCount)",
                    label: "other days"
                ),
            ]
        case .mealOnly:
            [
                Stat(
                    value: "\(supportingDayCount) of \(eligibleDayCount)",
                    label: "logged days"
                ),
            ]
        }
    }

    var mealBars: [MealBar] {
        let peak = max(supportingMealAverageCalories, comparisonMealAverageCalories)
        return [
            MealBar(
                label: daysListTitle,
                valueText: kcalText(supportingMealAverageCalories),
                ratio: ratio(supportingMealAverageCalories, of: peak),
                isPatternDays: true
            ),
            MealBar(
                label: "Other days",
                valueText: kcalText(comparisonMealAverageCalories),
                ratio: ratio(comparisonMealAverageCalories, of: peak),
                isPatternDays: false
            ),
        ]
    }

    var daysListTitle: String {
        patternDaysName.prefix(1).uppercased() + patternDaysName.dropFirst()
    }

    private var patternDaysName: String {
        HistoryRecurringCaloriePatternWording.patternDaysName(
            kind: kind,
            weekdayName: weekdayName,
            outcome: outcome,
            supportingDayCount: supportingDayCount,
            cohortDayCount: cohortDayCount
        )
    }

    private func kcalText(_ calories: Double) -> String {
        "\(HistoryRecurringCaloriePatternWording.calories(calories)) kcal"
    }

    private func ratio(_ value: Double, of peak: Double) -> Double {
        guard peak > 0 else { return 0 }
        return min(1, max(0, value / peak))
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

    var mealName: String { HistoryRecurringCaloriePatternWording.mealName(for: mealType) }

    var totals: HistoryRecurringCaloriePatternPhrase {
        HistoryRecurringCaloriePatternPhrase(runs: [
            .emphasised(loggedText),
            .plain(" of \(dailyCalorieTarget.formatted()) goal"),
        ])
    }

    var mealCaloriesText: String {
        "\(HistoryRecurringCaloriePatternWording.calories(mealCalories)) kcal"
    }

    var accessibilityLabel: String {
        "\(dateText), \(loggedText) of \(dailyCalorieTarget.formatted()) kcal goal, \(mealName), \(mealCaloriesText)"
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

    private var loggedText: String {
        HistoryRecurringCaloriePatternWording.calories(totalCalories)
    }
}
