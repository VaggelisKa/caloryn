import Foundation
import Testing
@testable import Caloryn

@Suite("History recurring pattern detail summary")
struct HistoryRecurringCaloriePatternDetailSummaryTests {
    @Test("given every logged weekday matched, when leading the detail, then it states the card's meal averages with both numbers emphasised")
    func aWeekdayPatternLeadsWithTheMeal() {
        let summary = makeSummary(
            kind: .weekdayMeal,
            weekdayName: "Friday",
            supportingDayCount: 4,
            cohortDayCount: 4,
            supportingMealAverage: 800.4,
            comparisonMealAverage: 499.6
        )

        #expect(summary.mealLead.plainText == "Dinner averages 800 kcal on Fridays, 500 on other days.")
        #expect(summary.mealLead.runs.filter(\.isEmphasised).map(\.text) == ["800", "500"])
    }

    @Test(
        "given only some logged weekdays matched, when leading the detail, then the matching weekdays are named by their side of goal",
        arguments: [
            (HistoryRecurringCalorieOutcome.above, "Dinner averages 800 kcal on over-goal Fridays, 500 on other days."),
            (.below, "Dinner averages 800 kcal on under-goal Fridays, 500 on other days.")
        ]
    )
    func aPartialWeekdayPatternLeadsWithItsSideOfGoal(outcome: HistoryRecurringCalorieOutcome, expected: String) {
        let summary = makeSummary(kind: .weekdayMeal, outcome: outcome, supportingDayCount: 4, cohortDayCount: 5)

        #expect(summary.mealLead.plainText == expected)
    }

    @Test(
        "given a meal-only pattern, when leading the detail, then the pattern days are named by their side of goal",
        arguments: [
            (HistoryRecurringCalorieOutcome.above, "Dinner averages 800 kcal on over-goal days, 500 on other days."),
            (.below, "Dinner averages 800 kcal on under-goal days, 500 on other days.")
        ]
    )
    func aMealOnlyPatternLeadsWithItsSideOfGoal(outcome: HistoryRecurringCalorieOutcome, expected: String) {
        #expect(makeSummary(kind: .mealOnly, outcome: outcome).mealLead.plainText == expected)
    }

    @Test("given snacks, when leading the detail, then they are plural and the verb agrees")
    func snacksLeadInThePlural() {
        #expect(
            makeSummary(mealType: .snack).mealLead.plainText
                == "Snacks average 800 kcal on Fridays, 500 on other days."
        )
        #expect(
            makeSummary(kind: .mealOnly, mealType: .snack).mealLead.plainText
                == "Snacks average 800 kcal on over-goal days, 500 on other days."
        )
    }

    @Test("given the window and the logged days, when stating the basis, then both are counted")
    func theBasisCountsWindowAndLoggedDays() {
        #expect(makeSummary(eligibleDayCount: 30, windowDayCount: 30).basisText == "Last 30 days · 30 logged days")
        #expect(makeSummary(eligibleDayCount: 1, windowDayCount: 30).basisText == "Last 30 days · 1 logged day")
    }

    @Test(
        "given each outcome, when titling the outcome section, then it names the side of goal",
        arguments: [
            (HistoryRecurringCalorieOutcome.above, "Over goal"),
            (.below, "Under goal")
        ]
    )
    func theOutcomeSectionNamesTheSideOfGoal(outcome: HistoryRecurringCalorieOutcome, expected: String) {
        #expect(makeSummary(outcome: outcome).outcomeTitle == expected)
    }

    @Test("given a weekday pattern, when counting the outcome, then that weekday's share sits beside every other day's")
    func aWeekdayPatternComparesTwoShares() {
        let summary = makeSummary(
            kind: .weekdayMeal,
            weekdayName: "Friday",
            supportingDayCount: 4,
            cohortDayCount: 4,
            outcomeComparisonCount: 0,
            outcomeComparisonDayCount: 26
        )

        #expect(summary.outcomeStats == [
            .init(value: "4 of 4", label: "Fridays"),
            .init(value: "0 of 26", label: "other days")
        ])
    }

    @Test("given a meal-only pattern, when counting the outcome, then it is the share of all logged days with nothing to set beside it")
    func aMealOnlyPatternCountsOneShare() {
        let summary = makeSummary(kind: .mealOnly, supportingDayCount: 6, eligibleDayCount: 17)

        #expect(summary.outcomeStats == [.init(value: "6 of 17", label: "logged days")])
    }

    @Test(
        "given a meal, when titling its section, then it is named as a day row names it",
        arguments: [
            (MealType.breakfast, "Breakfast"),
            (.lunch, "Lunch"),
            (.dinner, "Dinner"),
            (.snack, "Snacks")
        ]
    )
    func theMealSectionIsNamedForTheMeal(mealType: MealType, expected: String) {
        #expect(makeSummary(mealType: mealType).mealTitle == expected)
    }

    @Test("given a weekday pattern, when comparing the meal, then the weekday's bar is full and the other days' bar is scaled to it")
    func theLargerAverageFillsItsBar() {
        let bars = makeSummary(supportingMealAverage: 800, comparisonMealAverage: 500).mealBars

        #expect(bars.map(\.label) == ["Fridays", "Other days"])
        #expect(bars.map(\.valueText) == ["800 kcal", "500 kcal"])
        #expect(bars.map(\.ratio) == [1, 0.625])
        #expect(bars.map(\.isPatternDays) == [true, false])
    }

    @Test(
        "given only some logged weekdays matched, when comparing the meal, then the first bar is the matching weekdays and the other bar is every other day",
        arguments: [
            (HistoryRecurringCalorieOutcome.above, "Over-goal Fridays"),
            (.below, "Under-goal Fridays")
        ]
    )
    func aPartialWeekdayBarNamesItsSideOfGoal(outcome: HistoryRecurringCalorieOutcome, expected: String) {
        let bars = makeSummary(outcome: outcome, supportingDayCount: 4, cohortDayCount: 5).mealBars

        #expect(bars.map(\.label) == [expected, "Other days"])
    }

    @Test("given only some logged weekdays matched, when counting the outcome, then the weekday is still set against every other weekday")
    func aPartialWeekdayOutcomeComparesWeekdays() {
        let summary = makeSummary(
            kind: .weekdayMeal,
            weekdayName: "Friday",
            supportingDayCount: 4,
            cohortDayCount: 5,
            outcomeComparisonCount: 2,
            outcomeComparisonDayCount: 25
        )

        #expect(summary.outcomeStats == [
            .init(value: "4 of 5", label: "Fridays"),
            .init(value: "2 of 25", label: "other days")
        ])
    }

    @Test("given a smaller meal on the pattern's days, when comparing the meal, then the other days fill their bar instead")
    func aSmallerMealScalesToTheOtherDays() {
        let bars = makeSummary(
            kind: .mealOnly,
            outcome: .below,
            supportingMealAverage: 150,
            comparisonMealAverage: 600
        ).mealBars

        #expect(bars.map(\.label) == ["Under-goal days", "Other days"])
        #expect(bars.map(\.ratio) == [0.25, 1])
    }

    @Test("given no calories for the meal anywhere, when comparing it, then both bars are empty rather than undefined")
    func noCaloriesLeaveBothBarsEmpty() {
        let bars = makeSummary(supportingMealAverage: 0, comparisonMealAverage: 0).mealBars

        #expect(bars.map(\.ratio) == [0, 0])
        #expect(bars.map(\.valueText) == ["0 kcal", "0 kcal"])
    }

    @Test(
        "given each kind of pattern, when titling the day list, then it names the days it lists",
        arguments: [
            (HistoryRecurringCaloriePatternKind.weekdayMeal, HistoryRecurringCalorieOutcome.above, 4, "Fridays"),
            (.weekdayMeal, .below, 4, "Fridays"),
            (.weekdayMeal, .above, 5, "Over-goal Fridays"),
            (.weekdayMeal, .below, 5, "Under-goal Fridays"),
            (.mealOnly, .above, 4, "Over-goal days"),
            (.mealOnly, .below, 4, "Under-goal days")
        ]
    )
    func theDayListNamesItsDays(
        kind: HistoryRecurringCaloriePatternKind,
        outcome: HistoryRecurringCalorieOutcome,
        cohortDayCount: Int,
        expected: String
    ) {
        let summary = makeSummary(kind: kind, outcome: outcome, supportingDayCount: 4, cohortDayCount: cohortDayCount)

        #expect(summary.daysListTitle == expected)
    }

    @Test("given a supporting day, when summarising it, then the logged total is emphasised against the day's own goal in kcal, as VoiceOver reads it")
    func aSupportingDayEmphasisesItsTotal() {
        let row = makeRow(totalCalories: 2_800.4, dailyCalorieTarget: 2_000)

        #expect(row.totals.plainText == "\(2_800.formatted()) of \(2_000.formatted()) kcal goal")
        #expect(row.totals.runs.filter(\.isEmphasised).map(\.text) == [2_800.formatted()])
        #expect(row.accessibilityLabel.hasPrefix("Mon, 3 Feb, \(2_800.formatted()) of \(2_000.formatted()) kcal goal"))
    }

    @Test("given snacks, when naming the meal on a day row, then it reads plural")
    func theDayRowsSnackNameIsPlural() {
        #expect(makeRow(mealType: .snack).mealName == "Snacks")
        #expect(makeRow(mealType: .lunch).mealName == "Lunch")
    }

    @Test("given a meal's calories, when showing them on a day row, then they are rounded to whole kcal")
    func theDayRowRoundsMealCalories() {
        #expect(makeRow(mealCalories: 612.7).mealCaloriesText == "613 kcal")
    }

    @Test("given a collapsed row, when describing it, then the hint offers to expand")
    func aCollapsedRowOffersToExpand() {
        let row = makeRow(isExpanded: false)

        #expect(row.accessibilityValue == "Collapsed")
        #expect(row.accessibilityHint == "Expands contributing foods")
    }

    @Test("given an expanded row, when describing it, then the hint offers to collapse")
    func anExpandedRowOffersToCollapse() {
        let row = makeRow(isExpanded: true)

        #expect(row.accessibilityValue == "Expanded")
        #expect(row.accessibilityHint == "Collapses contributing foods")
    }

    @Test("given an expanded row, when heading its foods, then the meal is named in lower case mid-sentence")
    func theExpandedHeadingLowercasesTheMeal() {
        let row = makeRow(mealType: .snack)

        #expect(row.expandedSectionTitle == "Foods logged in snacks")
        #expect(row.expandedEmptyText == "No snacks calories were logged.")
    }

    private func makeSummary(
        kind: HistoryRecurringCaloriePatternKind = .weekdayMeal,
        outcome: HistoryRecurringCalorieOutcome = .above,
        weekdayName: String = "Friday",
        mealType: MealType = .dinner,
        supportingDayCount: Int = 4,
        cohortDayCount: Int = 4,
        outcomeComparisonCount: Int = 0,
        outcomeComparisonDayCount: Int = 26,
        eligibleDayCount: Int = 30,
        windowDayCount: Int = 30,
        supportingMealAverage: Double = 800,
        comparisonMealAverage: Double = 500
    ) -> HistoryRecurringCaloriePatternDetailSummary {
        HistoryRecurringCaloriePatternDetailSummary(
            kind: kind,
            outcome: outcome,
            weekdayName: weekdayName,
            mealType: mealType,
            supportingDayCount: supportingDayCount,
            cohortDayCount: cohortDayCount,
            outcomeComparisonCount: outcomeComparisonCount,
            outcomeComparisonDayCount: outcomeComparisonDayCount,
            eligibleDayCount: eligibleDayCount,
            windowDayCount: windowDayCount,
            supportingMealAverageCalories: supportingMealAverage,
            comparisonMealAverageCalories: comparisonMealAverage
        )
    }

    private func makeRow(
        dateText: String = "Mon, 3 Feb",
        totalCalories: Double = 2_200,
        dailyCalorieTarget: Int = 2_000,
        mealCalories: Double = 600,
        mealType: MealType = .dinner,
        isExpanded: Bool = false
    ) -> HistoryRecurringCaloriePatternDayRow {
        HistoryRecurringCaloriePatternDayRow(
            dateText: dateText,
            totalCalories: totalCalories,
            dailyCalorieTarget: dailyCalorieTarget,
            mealCalories: mealCalories,
            mealType: mealType,
            isExpanded: isExpanded
        )
    }
}
