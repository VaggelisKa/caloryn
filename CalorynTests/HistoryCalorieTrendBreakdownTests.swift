import Foundation
import Testing
@testable import Caloryn

@Suite("History calorie trend breakdown")
struct HistoryCalorieTrendBreakdownTests {
    @Test("given a day with two meals logged, when splitting it, then all four meals still get a row")
    func everyMealGetsARowInCanonicalOrder() {
        let breakdown = makeDay(mealCalories: [.breakfast: 400, .dinner: 700])

        #expect(breakdown.mealRows.map(\.mealType) == [.breakfast, .lunch, .snack, .dinner])
        #expect(breakdown.mealRows.map(\.calories) == [400, 0, 0, 700])
    }

    @Test("given a logged day, when sizing each meal's bar, then it is that meal's share of the day's total")
    func mealBarsAreSharesOfTheDay() {
        let breakdown = makeDay(mealCalories: [.breakfast: 500, .lunch: 500, .dinner: 1_000])

        #expect(breakdown.mealRows.map(\.shareOfDay) == [0.25, 0.25, 0, 0.5])
    }

    @Test("given nothing in any meal, when sizing the bars, then every bar is empty rather than undefined")
    func mealBarsAreEmptyWithoutCalories() {
        #expect(makeDay(mealCalories: [:]).mealRows.map(\.shareOfDay) == [0, 0, 0, 0])
    }

    @Test("given a negative meal total, when sizing the bars, then it neither shrinks the day nor draws backwards")
    func negativeMealCaloriesDrawNothing() {
        let breakdown = makeDay(mealCalories: [.breakfast: -300, .dinner: 600])

        #expect(breakdown.mealRows.map(\.shareOfDay) == [0, 0, 0, 1])
    }

    @Test("given a selected day, when stating its calories against the goal, then both read in whole kcal")
    func theDayGoalLineReadsInKcal() {
        let line = HistoryCalorieTrendGoalLine(calories: 2_000.4, target: 2_000, period: .day)

        #expect(line.valueText == 2_000.formatted())
        #expect(line.goalText == "of \(2_000.formatted()) kcal goal")
    }

    @Test("given a selected week, when stating its calories against the goal, then the average reads per day")
    func theWeekGoalLineReadsPerDay() {
        let line = HistoryCalorieTrendGoalLine(calories: 2_300, target: 2_000, period: .week)

        #expect(line.valueText == 2_300.formatted())
        #expect(line.goalText == "kcal a day of \(2_000.formatted()) goal")
    }

    @Test(
        "given a period exactly on goal, when naming it as furthest from goal, then there is nothing to name",
        arguments: [HistoryCalorieTrendPeriod.day, .week]
    )
    func aPeriodOnGoalIsNeverFurthest(period: HistoryCalorieTrendPeriod) {
        #expect(HistoryCalorieTrendFurthestFromGoal(periodText: "Fri, 23 Oct", calorieDifference: 0, period: period) == nil)
    }

    @Test(
        "given a day or a week off goal, when naming it as furthest from goal, then an unsigned amount, its unit and a direction follow the period",
        arguments: [
            ("Fri, 23 Oct", 800, HistoryCalorieTrendPeriod.day, ", 800 kcal over"),
            ("Fri, 23 Oct", -1_200, .day, ", \(1_200.formatted()) kcal under"),
            ("week of 12 Jan", 500, .week, ", 500 kcal a day over"),
            ("week of 12 Jan", -350, .week, ", 350 kcal a day under")
        ]
    )
    func theFurthestLineReadsAmountUnitAndDirection(
        periodText: String,
        difference: Int,
        period: HistoryCalorieTrendPeriod,
        suffix: String
    ) throws {
        let furthest = try #require(
            HistoryCalorieTrendFurthestFromGoal(periodText: periodText, calorieDifference: difference, period: period)
        )

        #expect(furthest.periodText == periodText)
        #expect(furthest.suffix == suffix)
        #expect(furthest.text == "Furthest from goal: " + periodText + suffix)
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

        #expect(titles == ["Breakfast", "Lunch", "Snacks", "Dinner"])
    }

    @Test("given a day over goal, when titling the food list, then it reads as an explanation")
    func overTargetTheFoodsExplainTheOverage() {
        #expect(makeDay(calorieDifference: 320).foodSectionTitle == "Top contributors")
    }

    @Test(
        "given a day at or under goal, when titling the food list, then it is just a list",
        arguments: [0, -1, -450]
    )
    func atOrUnderTargetTheFoodsAreJustAList(difference: Int) {
        #expect(makeDay(calorieDifference: difference).foodSectionTitle == "Foods logged")
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

    @Test("given a day with nothing logged, when describing it, then the day's own goal is named")
    func anUnloggedDayNamesItsOwnGoal() {
        let breakdown = makeDay(isLogged: false, dailyCalorieTarget: 2_000)

        #expect(breakdown.isLogged == false)
        #expect(breakdown.unloggedText == "No food logged. Goal was \(2_000.formatted()) kcal.")
    }

    @Test("given a week with nothing logged, when describing it, then it says so rather than showing zeroes")
    func anEmptyWeekSaysSo() {
        let breakdown = makeWeek(loggedDays: 0, totalDays: 7, swings: [])

        #expect(breakdown.hasLoggedDays == false)
        #expect(breakdown.emptyText == "No food logged in this week.")
        #expect(breakdown.furthestFromGoal == nil)
    }

    @Test("given a week, when heading it, then it is named by its first day")
    func aWeekIsNamedByItsFirstDay() {
        #expect(makeWeek(weekStartText: "3 Feb").headerText == "Week of 3 Feb")
    }

    @Test("given a week's counts, when showing them, then on-track is out of logged days and coverage out of all days")
    func theWeeksTwoRatiosCountDifferentDenominators() {
        let breakdown = makeWeek(loggedDays: 5, totalDays: 7, onTrackDays: 3)

        #expect(breakdown.stats == [
            .init(value: "3 of 5", label: "logged days on track"),
            .init(value: "5 of 7", label: "days logged")
        ])
        #expect(breakdown.stats.map(\.spokenLabel) == ["3 of 5 logged days on track", "5 of 7 days logged"])
    }

    @Test("given logged days, when naming the day furthest from goal, then distance from goal wins regardless of direction")
    func theFurthestDayIgnoresDirection() {
        let breakdown = makeWeek(swings: [
            .init(dateText: "Mon, 3 Feb", calorieDifference: 300),
            .init(dateText: "Tue, 4 Feb", calorieDifference: -900),
            .init(dateText: "Wed, 5 Feb", calorieDifference: 120)
        ])

        #expect(breakdown.furthestSwing?.dateText == "Tue, 4 Feb")
        #expect(breakdown.furthestFromGoal?.text == "Furthest from goal: Tue, 4 Feb, 900 kcal under")
    }

    @Test("given two equally distant days, when naming the furthest, then the earlier day wins")
    func anExactTieNamesTheEarlierDay() {
        let breakdown = makeWeek(swings: [
            .init(dateText: "Mon, 3 Feb", calorieDifference: 400),
            .init(dateText: "Tue, 4 Feb", calorieDifference: -400)
        ])

        #expect(breakdown.furthestSwing?.dateText == "Mon, 3 Feb")
    }

    @Test("given every day exactly on goal, when naming the furthest from goal, then the line is hidden")
    func aWeekWhereEveryDayHitTargetHidesTheLine() {
        let breakdown = makeWeek(swings: [.init(dateText: "Mon, 3 Feb", calorieDifference: 0)])

        #expect(breakdown.furthestFromGoal == nil)
    }

    @Test("given a week's foods, when listing them, then the same three-row limit applies")
    func theWeeksFoodListUsesTheSameLimit() {
        let breakdown = makeWeek(foods: makeFoods(count: 5))

        #expect(breakdown.visibleFoods.count == HistoryCalorieTrendDayBreakdown.visibleFoodLimit)
        #expect(breakdown.showsFoodSection)
    }

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
