import Foundation

enum HistoryMealLabel {
    static func rowTitle(for mealType: MealType) -> String {
        mealType == .snack ? "Snacks" : mealType.displayName
    }
}

enum HistoryCalorieDelta {
    static func signedText(_ difference: Int) -> String {
        if difference > 0 { return "+\(difference.magnitude.formatted())" }
        if difference < 0 { return "\u{2212}\(difference.magnitude.formatted())" }
        return "0"
    }
}

struct HistoryCalorieTrendFurthestFromGoal: Equatable {
    static let prefix = "Furthest from goal: "

    let periodText: String
    let calorieDifference: Int
    let unit: String?

    init?(periodText: String, calorieDifference: Int, unit: String?) {
        guard calorieDifference != 0 else { return nil }
        self.periodText = periodText
        self.calorieDifference = calorieDifference
        self.unit = unit
    }

    var deltaText: String {
        let signed = HistoryCalorieDelta.signedText(calorieDifference)
        guard let unit else { return signed }
        return "\(signed) \(unit)"
    }

    var suffix: String { ", \(deltaText)" }

    var text: String { Self.prefix + periodText + suffix }
}

struct HistoryCalorieTrendGoalLine: Equatable {
    enum Period: Equatable {
        case day
        case week
    }

    let calories: Double
    let target: Int
    let period: Period

    var valueText: String {
        calories.rounded().truncatedSafely.formatted()
    }

    var goalText: String {
        switch period {
        case .day:
            "of \(target.formatted()) kcal goal"
        case .week:
            "kcal / day of \(target.formatted()) goal"
        }
    }
}

struct HistoryCalorieTrendDayBreakdown {
    static let visibleFoodLimit = 3

    struct MealRow: Identifiable, Equatable {
        let mealType: MealType
        let calories: Double
        let shareOfDay: Double

        var id: String { mealType.id }
        var title: String { HistoryMealLabel.rowTitle(for: mealType) }
        var iconName: String { mealType.iconName }

        var hasCalories: Bool { calories > 0 }

        var caloriesText: String {
            hasCalories ? calories.rounded().truncatedSafely.kcalFormatted : "none"
        }
    }

    let isLogged: Bool
    let calorieDifference: Int
    let dailyCalorieTarget: Int
    let mealCalories: [MealType: Double]
    let foods: [HistoryFoodSummary]

    init(
        isLogged: Bool,
        calorieDifference: Int,
        dailyCalorieTarget: Int,
        mealCalories: [MealType: Double],
        foods: [HistoryFoodSummary]
    ) {
        self.isLogged = isLogged
        self.calorieDifference = calorieDifference
        self.dailyCalorieTarget = dailyCalorieTarget
        self.mealCalories = mealCalories
        self.foods = foods
    }

    var mealRows: [MealRow] {
        let calories = MealType.allCases.map { max(mealCalories[$0] ?? 0, 0) }
        let dayTotal = calories.reduce(0, +)
        return zip(MealType.allCases, calories).map { mealType, mealCalories in
            let share = dayTotal > 0 && dayTotal.isFinite ? mealCalories / dayTotal : 0
            return MealRow(mealType: mealType, calories: mealCalories, shareOfDay: min(max(share, 0), 1))
        }
    }

    var visibleFoods: [HistoryFoodSummary] {
        Array(foods.prefix(Self.visibleFoodLimit))
    }

    var hiddenFoodCount: Int {
        max(foods.count - visibleFoods.count, 0)
    }

    var overflowText: String? {
        guard hiddenFoodCount > 0 else { return nil }
        return "+ \(hiddenFoodCount) more"
    }

    var showsFoodSection: Bool {
        !visibleFoods.isEmpty
    }

    var foodSectionTitle: String {
        calorieDifference > 0 ? "Top contributors" : "Foods logged"
    }

    var unloggedText: String {
        "No food logged. Target was \(dailyCalorieTarget.formatted()) kcal."
    }

    static func entryCountText(_ count: Int) -> String {
        "\(count) \(count == 1 ? "entry" : "entries")"
    }
}

struct HistoryCalorieTrendWeekBreakdown {
    struct DaySwing: Equatable {
        let dateText: String
        let calorieDifference: Int
    }

    let weekStartText: String
    let loggedDays: Int
    let totalDays: Int
    let onTrackDays: Int
    let loggedDaySwings: [DaySwing]
    let foods: [HistoryFoodSummary]

    init(
        weekStartText: String,
        loggedDays: Int,
        totalDays: Int,
        onTrackDays: Int,
        loggedDaySwings: [DaySwing],
        foods: [HistoryFoodSummary]
    ) {
        self.weekStartText = weekStartText
        self.loggedDays = loggedDays
        self.totalDays = totalDays
        self.onTrackDays = onTrackDays
        self.loggedDaySwings = loggedDaySwings
        self.foods = foods
    }

    var hasLoggedDays: Bool { loggedDays > 0 }

    var headerText: String { "Week of \(weekStartText)" }

    var emptyText: String { "No food logged in this week." }

    var onTrackRatioText: String { "\(onTrackDays) of \(loggedDays)" }

    var coverageRatioText: String { "\(loggedDays) of \(totalDays)" }

    var furthestSwing: DaySwing? {
        loggedDaySwings.max { abs($0.calorieDifference) < abs($1.calorieDifference) }
    }

    var furthestFromGoal: HistoryCalorieTrendFurthestFromGoal? {
        guard let furthestSwing else { return nil }
        return HistoryCalorieTrendFurthestFromGoal(
            periodText: furthestSwing.dateText,
            calorieDifference: furthestSwing.calorieDifference,
            unit: nil
        )
    }

    var visibleFoods: [HistoryFoodSummary] {
        Array(foods.prefix(HistoryCalorieTrendDayBreakdown.visibleFoodLimit))
    }

    var showsFoodSection: Bool {
        !visibleFoods.isEmpty
    }
}
