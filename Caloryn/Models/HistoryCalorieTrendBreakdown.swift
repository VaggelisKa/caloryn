import Foundation

/// How a meal is named in a History per-meal row.
///
/// Snacks are the one meal a single row can hold several of, so the row reads
/// plural where `MealType.displayName` reads singular. Two screens needed the
/// same exception, which is why it is here rather than in either of them.
enum HistoryMealLabel {
    static func rowTitle(for mealType: MealType) -> String {
        mealType == .snack ? "Snacks" : mealType.displayName
    }
}

/// What the calorie-trend drill-down says about a selected day.
///
/// Takes the day's totals and its per-meal calories rather than the day detail,
/// so the unlogged wording, the meal split and the food-driver framing are
/// reachable without entries or a store.
struct HistoryCalorieTrendDayBreakdown {
    /// Beyond this the list is summarised as a count; three rows is as much as
    /// the card can show without pushing the meal split off screen.
    static let visibleFoodLimit = 3

    struct MealRow: Identifiable, Equatable {
        let mealType: MealType
        let calories: Double

        var id: String { mealType.id }
        var title: String { HistoryMealLabel.rowTitle(for: mealType) }
        var iconName: String { mealType.iconName }

        /// A meal with no calories is still listed, so the split always has the
        /// same four rows — it just reads as absent rather than as zero.
        var hasCalories: Bool { calories > 0 }

        var caloriesText: String {
            hasCalories ? Int(calories.rounded()).kcalFormatted : "none"
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

    /// Every meal, in the canonical order, whether or not it was logged.
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

    /// Over target the foods are read as an explanation; at or under target
    /// there is nothing to explain, so they are just a list.
    var foodSectionTitle: String {
        calorieDifference > 0 ? "Top Contributors" : "Foods Logged"
    }

    var unloggedText: String {
        "No food logged. Target was \(dailyCalorieTarget.formatted()) kcal."
    }

    static func entryCountText(_ count: Int) -> String {
        "\(count) \(count == 1 ? "entry" : "entries")"
    }
}

/// What the calorie-trend drill-down says about a selected week.
///
/// The 90-day range plots one bar per calendar week, so a selection there is a
/// week rather than a day. Takes the week's counts and its days' swings — the
/// dates already rendered — rather than the week summary.
struct HistoryCalorieTrendWeekBreakdown {
    /// One logged day, reduced to what the biggest-swing rule needs.
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

    /// The furthest logged day from its own target, in either direction. An
    /// exact tie goes to the earlier day, so the reader is always sent to the
    /// first day the swing appeared.
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
