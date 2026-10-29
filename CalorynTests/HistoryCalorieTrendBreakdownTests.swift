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
        #expect(line.goalText == "kcal / day of \(2_000.formatted()) goal")
    }

    @Test(
        "given a calorie difference, when signing it, then over is plus, under is a true minus and zero is bare",
        arguments: [(800, "+800"), (-400, "\u{2212}400"), (0, "0")]
    )
    func differencesAreSigned(difference: Int, expected: String) {
        #expect(HistoryCalorieDelta.signedText(difference) == expected)
    }

    @Test("given a period exactly on goal, when naming it as furthest from goal, then there is nothing to name")
    func aPeriodOnGoalIsNeverFurthest() {
        #expect(HistoryCalorieTrendFurthestFromGoal(periodText: "Fri 23 Oct", calorieDifference: 0, unit: nil) == nil)
    }

    @Test("given a day and a week, when naming them as furthest from goal, then only the week carries a per-day unit")
    func theFurthestLineCarriesItsUnit() throws {
        let day = try #require(HistoryCalorieTrendFurthestFromGoal(periodText: "Fri 23 Oct", calorieDifference: 800, unit: nil))
        let week = try #require(HistoryCalorieTrendFurthestFromGoal(periodText: "week of 12 Jan", calorieDifference: 500, unit: "kcal/day"))

        #expect(day.text == "Furthest from goal: Fri 23 Oct, +800")
        #expect(day.periodText == "Fri 23 Oct")
        #expect(week.text == "Furthest from goal: week of 12 Jan, +500 kcal/day")
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

    @Test("given a day over target, when titling the food list, then it reads as an explanation")
    func overTargetTheFoodsExplainTheOverage() {
        #expect(makeDay(calorieDifference: 320).foodSectionTitle == "Top contributors")
    }

    @Test(
        "given a day at or under target, when titling the food list, then it is just a list",
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

    @Test("given a day with nothing logged, when describing it, then the day's own target is named")
    func anUnloggedDayNamesItsOwnTarget() {
        let breakdown = makeDay(isLogged: false, dailyCalorieTarget: 950)

        #expect(breakdown.isLogged == false)
        #expect(breakdown.unloggedText == "No food logged. Target was 950 kcal.")
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

        #expect(breakdown.onTrackRatioText == "3 of 5")
        #expect(breakdown.coverageRatioText == "5 of 7")
    }

    @Test("given logged days, when naming the day furthest from goal, then distance from target wins regardless of direction")
    func theFurthestDayIgnoresDirection() {
        let breakdown = makeWeek(swings: [
            .init(dateText: "Mon 3 Feb", calorieDifference: 300),
            .init(dateText: "Tue 4 Feb", calorieDifference: -900),
            .init(dateText: "Wed 5 Feb", calorieDifference: 120)
        ])

        #expect(breakdown.furthestSwing?.dateText == "Tue 4 Feb")
        #expect(breakdown.furthestFromGoal?.text == "Furthest from goal: Tue 4 Feb, \u{2212}900")
    }

    @Test("given two equally distant days, when naming the furthest, then the earlier day wins")
    func anExactTieNamesTheEarlierDay() {
        let breakdown = makeWeek(swings: [
            .init(dateText: "Mon 3 Feb", calorieDifference: 400),
            .init(dateText: "Tue 4 Feb", calorieDifference: -400)
        ])

        #expect(breakdown.furthestSwing?.dateText == "Mon 3 Feb")
    }

    @Test("given every day exactly on target, when naming the furthest from goal, then the line is hidden")
    func aWeekWhereEveryDayHitTargetHidesTheLine() {
        let breakdown = makeWeek(swings: [.init(dateText: "Mon 3 Feb", calorieDifference: 0)])

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
