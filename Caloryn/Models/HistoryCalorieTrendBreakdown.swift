import Foundation

enum HistoryMealLabel {
    static func rowTitle(for mealType: MealType) -> String {
        mealType == .snack ? "Snacks" : mealType.displayName
    }
}

struct HistoryCalorieTrendDayBreakdown {
    static let visibleFoodLimit = 3

    struct MealRow: Identifiable, Equatable {
        let mealType: MealType
        let calories: Double

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
        MealType.allCases.map { mealType in
            MealRow(mealType: mealType, calories: mealCalories[mealType] ?? 0)
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

    var onTrackRatioText: String { "\(onTrackDays)/\(loggedDays)" }

    var coverageRatioText: String { "\(loggedDays)/\(totalDays)" }

    var biggestSwing: DaySwing? {
        loggedDaySwings.max { abs($0.calorieDifference) < abs($1.calorieDifference) }
    }

    var biggestSwingText: String? {
        guard let biggestSwing else { return nil }
        let delta = HistoryCalorieTrendProjection.deltaText(
            biggestSwing.calorieDifference,
            unit: "kcal"
        )
        return "Biggest swing: \(biggestSwing.dateText), \(delta)"
    }

    var visibleFoods: [HistoryFoodSummary] {
        Array(foods.prefix(HistoryCalorieTrendDayBreakdown.visibleFoodLimit))
    }

    var showsFoodSection: Bool {
        !visibleFoods.isEmpty
    }
}
