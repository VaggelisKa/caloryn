import Foundation

enum HistoryMealLabel {
    static func rowTitle(for mealType: MealType) -> String {
        mealType == .snack ? "Snacks" : mealType.displayName
    }
}

enum HistoryCalorieTrendPeriod: Equatable {
    case day
    case week
}

struct HistoryCalorieTrendStat: Identifiable, Equatable {
    let value: String
    let label: String
    let spokenLabel: String

    init(value: String, label: String, spokenLabel: String? = nil) {
        self.value = value
        self.label = label
        self.spokenLabel = spokenLabel ?? "\(value) \(label)"
    }

    var id: String { label }
}

struct HistoryCalorieTrendFurthestFromGoal: Equatable {
    static let prefix = "Furthest from goal: "

    let periodText: String
    let calorieDifference: Int
    let period: HistoryCalorieTrendPeriod

    init?(periodText: String, calorieDifference: Int, period: HistoryCalorieTrendPeriod) {
        guard calorieDifference != 0 else { return nil }
        self.periodText = periodText
        self.calorieDifference = calorieDifference
        self.period = period
    }

    var suffix: String {
        let unit = period == .day ? "kcal" : "kcal a day"
        let direction = calorieDifference > 0 ? "over" : "under"
        return ", \(calorieDifference.magnitude.formatted()) \(unit) \(direction)"
    }

    var text: String { Self.prefix + periodText + suffix }
}

struct HistoryCalorieTrendGoalLine: Equatable {
    let calories: Double
    let target: Int
    let period: HistoryCalorieTrendPeriod

    var valueText: String {
        calories.rounded().truncatedSafely.formatted()
    }

    var goalText: String {
        switch period {
        case .day:
            "of \(target.formatted()) kcal goal"
        case .week:
            "kcal a day vs a \(target.formatted()) kcal goal"
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
        "No food logged. Goal was \(dailyCalorieTarget.formatted()) kcal."
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

    var onTrack: HistoryCalorieTrendStat {
        HistoryCalorieTrendStat(value: "\(onTrackDays) of \(loggedDays)", label: "logged days on track")
    }

    var coverage: HistoryCalorieTrendStat {
        HistoryCalorieTrendStat(value: "\(loggedDays) of \(totalDays)", label: "days logged")
    }

    var stats: [HistoryCalorieTrendStat] {
        [onTrack, coverage]
    }

    var furthestSwing: DaySwing? {
        loggedDaySwings.max { abs($0.calorieDifference) < abs($1.calorieDifference) }
    }

    var furthestFromGoal: HistoryCalorieTrendFurthestFromGoal? {
        guard let furthestSwing else { return nil }
        return HistoryCalorieTrendFurthestFromGoal(
            periodText: furthestSwing.dateText,
            calorieDifference: furthestSwing.calorieDifference,
            period: .day
        )
    }

    var visibleFoods: [HistoryFoodSummary] {
        Array(foods.prefix(HistoryCalorieTrendDayBreakdown.visibleFoodLimit))
    }

    var showsFoodSection: Bool {
        !visibleFoods.isEmpty
    }
}
