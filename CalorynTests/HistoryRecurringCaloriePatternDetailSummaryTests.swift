import Foundation
import Testing
@testable import Caloryn

/// The evidence wording on the recurring-calorie pattern drill-down. The two
/// pattern kinds count different things, and every label on the card turns on
/// that distinction.
@Suite("History recurring pattern detail summary")
struct HistoryRecurringCaloriePatternDetailSummaryTests {

    // MARK: - Weekday patterns

    @Test("given a weekday pattern, when titling the supporting group, then it names the weekday")
    func aWeekdayPatternNamesItsWeekday() {
        let summary = makeSummary(kind: .weekdayMeal, weekdayName: "Friday")

        #expect(summary.supportingTitle == "Logged Fridays")
    }

    @Test("given a weekday pattern, when counting the supporting group, then it is a share of that weekday's cohort")
    func aWeekdayPatternsSupportIsAShareOfItsCohort() {
        let summary = makeSummary(
            kind: .weekdayMeal,
            supportingDayCount: 4,
            cohortDayCount: 5
        )

        #expect(summary.supportingValue == "4 of 5")
        #expect(summary.supportingDetail == "above target")
    }

    @Test("given a weekday pattern, when counting the comparison group, then it is a share of every other logged day")
    func aWeekdayPatternsComparisonIsAShareOfTheRest() {
        let summary = makeSummary(
            kind: .weekdayMeal,
            outcomeComparisonCount: 3,
            outcomeComparisonDayCount: 20
        )

        #expect(summary.comparisonTitle == "Other logged days")
        #expect(summary.comparisonValue == "3 of 20")
        #expect(summary.comparisonDetail == "above target")
    }

    // MARK: - Meal-only patterns

    @Test("given a meal-only pattern, when titling the supporting group, then it names the outcome")
    func aMealOnlyPatternNamesItsOutcome() {
        let summary = makeSummary(kind: .mealOnly, outcomeTargetText: "below target")

        #expect(summary.supportingTitle == "Below Target days")
    }

    @Test("given a meal-only pattern, when counting either group, then it is a bare count with nothing to divide by")
    func aMealOnlyPatternCountsWithoutADenominator() {
        let summary = makeSummary(
            kind: .mealOnly,
            supportingDayCount: 6,
            cohortDayCount: 6,
            mealComparisonDayCount: 11
        )

        #expect(summary.supportingValue == "6")
        #expect(summary.supportingDetail == "supporting logged days")
        #expect(summary.comparisonValue == "11")
        #expect(summary.comparisonDetail == "comparison logged days")
    }

    // MARK: - Meal comparison

    @Test(
        "given a meal, when titling the comparison, then the heading names it in the singular",
        arguments: [
            (MealType.breakfast, "Breakfast Comparison"),
            (.lunch, "Lunch Comparison"),
            (.dinner, "Dinner Comparison"),
            (.snack, "Snack Comparison")
        ]
    )
    func theMealComparisonHeadingIsSingular(mealType: MealType, expected: String) {
        #expect(makeSummary(mealType: mealType).mealComparisonTitle == expected)
    }

    @Test("given a meal eaten more on the pattern's days, when showing the difference, then it is signed positive")
    func amoreCalorificMealReadsPositive() {
        #expect(makeSummary(mealDifferenceCalories: 218.4).mealDifferenceText == "+218 kcal")
    }

    @Test("given a meal eaten less on the pattern's days, when showing the difference, then it uses a true minus sign")
    func aLighterMealUsesATrueMinusSign() {
        let summary = makeSummary(mealDifferenceCalories: -218.6)

        #expect(summary.mealDifferenceText == "\(HistoryRecurringCaloriePatternDetailSummary.minusSign)219 kcal")
        #expect(summary.mealDifferenceText.contains("-") == false)
    }

    @Test("given no difference at all, when showing it, then zero reads as positive rather than negative zero")
    func zeroReadsAsPositive() {
        #expect(makeSummary(mealDifferenceCalories: 0).mealDifferenceText == "+0 kcal")
    }

    // MARK: - Supporting day rows

    @Test("given a supporting day, when summarising it, then the logged total and the day's own target are both named")
    func aSupportingDayNamesBothNumbers() {
        let row = makeRow(totalCalories: 2_400.4, dailyCalorieTarget: 2_000)

        #expect(row.totalsText.contains("kcal logged"))
        #expect(row.totalsText.contains("kcal target"))
        #expect(row.accessibilityLabel.hasPrefix("Mon, 3 Feb, "))
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

    // MARK: - Helpers

    private func makeSummary(
        kind: HistoryRecurringCaloriePatternKind = .weekdayMeal,
        outcomeTargetText: String = "above target",
        weekdayName: String = "Monday",
        mealType: MealType = .dinner,
        supportingDayCount: Int = 4,
        cohortDayCount: Int = 5,
        outcomeComparisonCount: Int = 3,
        outcomeComparisonDayCount: Int = 20,
        mealComparisonDayCount: Int = 21,
        mealDifferenceCalories: Double = 200
    ) -> HistoryRecurringCaloriePatternDetailSummary {
        HistoryRecurringCaloriePatternDetailSummary(
            kind: kind,
            outcomeTargetText: outcomeTargetText,
            weekdayName: weekdayName,
            mealType: mealType,
            supportingDayCount: supportingDayCount,
            cohortDayCount: cohortDayCount,
            outcomeComparisonCount: outcomeComparisonCount,
            outcomeComparisonDayCount: outcomeComparisonDayCount,
            mealComparisonDayCount: mealComparisonDayCount,
            mealDifferenceCalories: mealDifferenceCalories
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
