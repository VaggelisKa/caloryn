import Foundation
import Testing
@testable import Caloryn

/// What the calorie-trend drill-down says about a selected day or week: the
/// meal split, the food-driver framing, the unlogged wording and the
/// biggest-swing rule. Dates arrive already formatted, so nothing here depends
/// on the device calendar.
@Suite("History calorie trend breakdown")
struct HistoryCalorieTrendBreakdownTests {

    // MARK: - Meal split

    @Test("given a day with two meals logged, when splitting it, then all four meals still get a row")
    func everyMealGetsARowInCanonicalOrder() {
        let breakdown = makeDay(mealCalories: [.breakfast: 400, .dinner: 700])

        #expect(breakdown.mealRows.map(\.mealType) == [.breakfast, .lunch, .dinner, .snack])
        #expect(breakdown.mealRows.map(\.calories) == [400, 0, 700, 0])
    }

    @Test("given a meal with no calories, when rendering its row, then it reads as absent rather than as zero")
    func anEmptyMealReadsAsAbsent() {
        let breakdown = makeDay(mealCalories: [.breakfast: 400])
        let lunch = breakdown.mealRows.first { $0.mealType == .lunch }

        #expect(lunch?.hasCalories == false)
        #expect(lunch?.caloriesText == "none")
    }

    @Test("given a logged meal, when rendering its row, then its calories are rounded to whole kcal")
    func aLoggedMealRoundsToWholeKcal() {
        let breakdown = makeDay(mealCalories: [.breakfast: 400.6])
        let breakfast = breakdown.mealRows.first { $0.mealType == .breakfast }

        #expect(breakfast?.hasCalories == true)
        #expect(breakfast?.caloriesText == "401 kcal")
    }

    @Test("given snacks, when titling their row, then the row reads plural")
    func theSnackRowReadsPlural() {
        let titles = makeDay(mealCalories: [:]).mealRows.map(\.title)

        #expect(titles == ["Breakfast", "Lunch", "Dinner", "Snacks"])
    }

    // MARK: - Food drivers

    @Test("given a day over target, when titling the food list, then it reads as an explanation")
    func overTargetTheFoodsExplainTheOverage() {
        #expect(makeDay(calorieDifference: 320).foodSectionTitle == "Top Contributors")
    }

    @Test(
        "given a day at or under target, when titling the food list, then it is just a list",
        arguments: [0, -1, -450]
    )
    func atOrUnderTargetTheFoodsAreJustAList(difference: Int) {
        #expect(makeDay(calorieDifference: difference).foodSectionTitle == "Foods Logged")
    }

    @Test("given more foods than fit, when listing them, then the rest are summarised as a count")
    func extraFoodsAreSummarisedAsACount() {
        let breakdown = makeDay(foods: makeFoods(count: 7))

        #expect(breakdown.visibleFoods.count == 3)
        #expect(breakdown.hiddenFoodCount == 4)
        #expect(breakdown.overflowText == "+ 4 more")
    }

    @Test("given exactly the visible limit, when listing foods, then there is no overflow line")
    func exactlyTheLimitHasNoOverflowLine() {
        let breakdown = makeDay(foods: makeFoods(count: 3))

        #expect(breakdown.visibleFoods.count == 3)
        #expect(breakdown.hiddenFoodCount == 0)
        #expect(breakdown.overflowText == nil)
    }

    @Test("given no foods, when deciding on the food section, then it is hidden entirely")
    func noFoodsHidesTheSection() {
        let breakdown = makeDay(foods: [])

        #expect(breakdown.showsFoodSection == false)
        #expect(breakdown.overflowText == nil)
    }

    @Test(
        "given a food's entry count, when labelling it, then one entry reads singular",
        arguments: [(1, "1 entry"), (2, "2 entries"), (0, "0 entries")]
    )
    func entryCountsArePluralisedOnOne(count: Int, expected: String) {
        #expect(HistoryCalorieTrendDayBreakdown.entryCountText(count) == expected)
    }

    // MARK: - Unlogged day

    @Test("given a day with nothing logged, when describing it, then the day's own target is named")
    func anUnloggedDayNamesItsOwnTarget() {
        let breakdown = makeDay(isLogged: false, dailyCalorieTarget: 950)

        #expect(breakdown.isLogged == false)
        #expect(breakdown.unloggedText == "No food logged. Target was 950 kcal.")
    }

    // MARK: - Selected week

    @Test("given a week with nothing logged, when describing it, then it says so rather than showing zeroes")
    func anEmptyWeekSaysSo() {
        let breakdown = makeWeek(loggedDays: 0, totalDays: 7, swings: [])

        #expect(breakdown.hasLoggedDays == false)
        #expect(breakdown.emptyText == "No food logged in this week.")
        #expect(breakdown.biggestSwingText == nil)
    }

    @Test("given a week, when heading it, then it is named by its first day")
    func aWeekIsNamedByItsFirstDay() {
        #expect(makeWeek(weekStartText: "3 Feb").headerText == "Week of 3 Feb")
    }

    @Test("given a week's counts, when showing them, then on-track is out of logged days and coverage out of all days")
    func theWeeksTwoRatiosCountDifferentDenominators() {
        let breakdown = makeWeek(loggedDays: 5, totalDays: 7, onTrackDays: 3)

        #expect(breakdown.onTrackRatioText == "3/5")
        #expect(breakdown.coverageRatioText == "5/7")
    }

    @Test("given logged days, when naming the biggest swing, then distance from target wins regardless of direction")
    func theBiggestSwingIgnoresDirection() {
        let breakdown = makeWeek(swings: [
            .init(dateText: "Mon, 3 Feb", calorieDifference: 300),
            .init(dateText: "Tue, 4 Feb", calorieDifference: -900),
            .init(dateText: "Wed, 5 Feb", calorieDifference: 120)
        ])

        #expect(breakdown.biggestSwing?.dateText == "Tue, 4 Feb")
        #expect(breakdown.biggestSwingText == "Biggest swing: Tue, 4 Feb, 900 kcal under")
    }

    @Test("given two equal swings, when naming the biggest, then the earlier day wins")
    func anExactTieNamesTheEarlierDay() {
        let breakdown = makeWeek(swings: [
            .init(dateText: "Mon, 3 Feb", calorieDifference: 400),
            .init(dateText: "Tue, 4 Feb", calorieDifference: -400)
        ])

        #expect(breakdown.biggestSwing?.dateText == "Mon, 3 Feb")
    }

    @Test("given a day exactly on target, when naming the biggest swing, then it reads as on target")
    func aWeekWhereEveryDayHitTargetReadsAsOnTarget() {
        let breakdown = makeWeek(swings: [.init(dateText: "Mon, 3 Feb", calorieDifference: 0)])

        #expect(breakdown.biggestSwingText == "Biggest swing: Mon, 3 Feb, On target")
    }

    @Test("given a week's foods, when listing them, then the same three-row limit applies")
    func theWeeksFoodListUsesTheSameLimit() {
        let breakdown = makeWeek(foods: makeFoods(count: 5))

        #expect(breakdown.visibleFoods.count == HistoryCalorieTrendDayBreakdown.visibleFoodLimit)
        #expect(breakdown.showsFoodSection)
    }

    // MARK: - Helpers

    private func makeDay(
        isLogged: Bool = true,
        calorieDifference: Int = 0,
        dailyCalorieTarget: Int = 2_000,
        mealCalories: [MealType: Double] = [:],
        foods: [HistoryFoodSummary] = []
    ) -> HistoryCalorieTrendDayBreakdown {
        HistoryCalorieTrendDayBreakdown(
            isLogged: isLogged,
            calorieDifference: calorieDifference,
            dailyCalorieTarget: dailyCalorieTarget,
            mealCalories: mealCalories,
            foods: foods
        )
    }

    private func makeWeek(
        weekStartText: String = "3 Feb",
        loggedDays: Int = 4,
        totalDays: Int = 7,
        onTrackDays: Int = 2,
        swings: [HistoryCalorieTrendWeekBreakdown.DaySwing] = [],
        foods: [HistoryFoodSummary] = []
    ) -> HistoryCalorieTrendWeekBreakdown {
        HistoryCalorieTrendWeekBreakdown(
            weekStartText: weekStartText,
            loggedDays: loggedDays,
            totalDays: totalDays,
            onTrackDays: onTrackDays,
            loggedDaySwings: swings,
            foods: foods
        )
    }

    private func makeFoods(count: Int) -> [HistoryFoodSummary] {
        (0 ..< count).map { index in
            HistoryFoodSummary(
                id: "food-\(index)",
                name: "Food \(index)",
                entryCount: 1,
                portionGrams: 100,
                calories: Double(500 - index)
            )
        }
    }
}
