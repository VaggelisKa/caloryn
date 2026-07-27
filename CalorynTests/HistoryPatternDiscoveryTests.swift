import Foundation
import Testing
@testable import Caloryn

/// Characterization tests for Pattern Discovery: the Calorie Trend, Weekly
/// Consistency, and Macro Patterns projections History builds on top of a
/// period summary. Every date is fixed and explicit so day, week, and
/// on-track-band boundaries are asserted rather than inferred.
@MainActor
@Suite("History Pattern Discovery")
struct HistoryPatternDiscoveryTests {

    // MARK: - Calorie Trend: shape of the projected points

    @Test("given a range with no days, when projecting the calorie trend, then there is no logged data and no drill-down")
    func emptyRangeHasNoPoints() {
        let projection = HistoryCalorieTrendProjection(
            range: .week,
            summary: makeSummary(dates: [])
        )

        #expect(projection.points.isEmpty)
        #expect(projection.loggedPointCount == 0)
        #expect(projection.hasLoggedData == false)
        #expect(projection.canDrillDown == false)
        #expect(projection.totalDayCount == 0)
        #expect(projection.loggedDayCount == 0)
        #expect(projection.biggestInconsistencyText == nil)
    }

    @Test(
        "given a daily range, when projecting the calorie trend, then one point is projected per calendar day",
        arguments: [
            (HistoryRange.week, 7),
            (HistoryRange.twoWeeks, 14),
            (HistoryRange.month, 30)
        ]
    )
    func dailyRangesProjectOnePointPerDay(range: HistoryRange, expectedPoints: Int) {
        let analytics = HistoryAnalytics(
            entries: [],
            profile: nil,
            range: range,
            endDate: janDate(30)
        )

        let projection = HistoryPatternDiscovery(analytics: analytics).calorieTrend

        #expect(projection.points.count == expectedPoints)
        #expect(projection.totalDayCount == expectedPoints)
        #expect(projection.points.allSatisfy { $0.isLogged == false })
    }

    @Test("given the 90-day range, when projecting the calorie trend, then points are calendar weeks rather than days")
    func quarterRangeProjectsWeeklyPoints() {
        let analytics = HistoryAnalytics(
            entries: [],
            profile: nil,
            range: .quarter,
            endDate: janDate(30)
        )

        let projection = HistoryPatternDiscovery(analytics: analytics).calorieTrend

        #expect(projection.totalDayCount == 90)
        // 90 days ending Fri 30 Jan 2026 spans 14 Monday-anchored calendar weeks.
        #expect(projection.points.count == 14)
        #expect(projection.points.first?.xAxisLabel == "W1")
        #expect(projection.points.last?.xAxisLabel == "W14")
    }

    @Test("given a 90-day range with two logged weeks, when projecting the calorie trend, then each week point carries its average per logged day")
    func quarterWeekPointsReportAveragePerLoggedDay() throws {
        let dates = days(fromJanuary: 5, count: 14)
        let entries = [
            makeCalorieEntry(date: janDate(5), calories: 2_000),
            makeCalorieEntry(date: janDate(6), calories: 2_400),
            makeCalorieEntry(date: janDate(12), calories: 2_600)
        ]

        let projection = HistoryCalorieTrendProjection(
            range: .quarter,
            summary: makeSummary(dates: dates, entries: entries)
        )

        #expect(projection.points.count == 2)

        let firstWeek = try #require(projection.points.first)
        #expect(firstWeek.isLogged)
        #expect(abs(firstWeek.value - 2_200) < 0.001)
        #expect(firstWeek.targetDelta == 200)
        #expect(firstWeek.status == .over)
        #expect(firstWeek.xAxisLabel == "W1")
        #expect(firstWeek.accessibilityLabel == "W1, week of \(janDate(5).startOfWeek.dayMonthFormatted)")
        #expect(firstWeek.accessibilityValue == "2200 average calories per logged day, Over")

        let secondWeek = try #require(projection.points.last)
        #expect(abs(secondWeek.value - 2_600) < 0.001)
        #expect(secondWeek.xAxisLabel == "W2")
    }

    @Test("given a 90-day range week with nothing logged, when projecting the calorie trend, then the week point reads as not logged")
    func quarterWeekPointWithoutLoggedDaysReadsAsNotLogged() throws {
        let dates = days(fromJanuary: 5, count: 14)
        let entries = [makeCalorieEntry(date: janDate(5), calories: 2_000)]

        let projection = HistoryCalorieTrendProjection(
            range: .quarter,
            summary: makeSummary(dates: dates, entries: entries)
        )

        let emptyWeek = try #require(projection.points.last)
        #expect(emptyWeek.isLogged == false)
        #expect(abs(emptyWeek.value) < 0.001)
        #expect(emptyWeek.status == .notLogged)
        #expect(emptyWeek.accessibilityValue == "No calories logged")
    }

    @Test("given a day with no entries, when projecting the calorie trend, then the point is an empty position rather than a zero-calorie day")
    func unloggedDayProjectsEmptyPosition() throws {
        let dates = days(fromJanuary: 26, count: 5)
        let entries = [makeCalorieEntry(date: janDate(30), calories: 2_000)]

        let projection = HistoryCalorieTrendProjection(
            range: .week,
            summary: makeSummary(dates: dates, entries: entries)
        )

        let firstPoint = try #require(projection.points.first)
        #expect(firstPoint.isLogged == false)
        #expect(abs(firstPoint.value) < 0.001)
        #expect(firstPoint.status == .notLogged)
        #expect(firstPoint.accessibilityValue == "No calories logged")
        #expect(firstPoint.accessibilityLabel == janDate(26).shortFormatted)
    }

    @Test("given a logged day over target, when projecting the calorie trend, then the point reports the calorie difference and Over status")
    func loggedDayPointReportsTargetDelta() throws {
        let dates = days(fromJanuary: 26, count: 5)
        let entries = [makeCalorieEntry(date: janDate(30), calories: 2_200)]

        let projection = HistoryCalorieTrendProjection(
            range: .week,
            summary: makeSummary(dates: dates, entries: entries)
        )

        let lastPoint = try #require(projection.points.last)
        #expect(lastPoint.isLogged)
        #expect(abs(lastPoint.value - 2_200) < 0.001)
        #expect(lastPoint.targetDelta == 200)
        #expect(lastPoint.status == .over)
        #expect(lastPoint.accessibilityValue == "2200 calories, Over")
    }

    @Test(
        "given a logged day at an on-track band edge, when projecting the calorie trend, then the point status follows the five percent tolerance",
        arguments: [
            (1_899.0, HistoryGoalStatus.under),
            (1_900.0, HistoryGoalStatus.onTrack),
            (2_000.0, HistoryGoalStatus.onTrack),
            (2_100.0, HistoryGoalStatus.onTrack),
            (2_101.0, HistoryGoalStatus.over)
        ]
    )
    func onTrackBandEdgesDecidePointStatus(calories: Double, expected: HistoryGoalStatus) throws {
        let dates = days(fromJanuary: 26, count: 1)
        let entries = [makeCalorieEntry(date: janDate(26), calories: calories)]

        let projection = HistoryCalorieTrendProjection(
            range: .week,
            summary: makeSummary(dates: dates, entries: entries)
        )

        let point = try #require(projection.points.first)
        #expect(point.status == expected)
    }

    @Test(
        "given a daily range, when projecting the calorie trend, then each point is labelled with its weekday initial",
        arguments: [
            (26, "M"),
            (27, "T"),
            (28, "W"),
            (29, "T"),
            (30, "F"),
            (31, "S")
        ]
    )
    func dayPointsUseWeekdayInitials(day: Int, expectedLabel: String) throws {
        let projection = HistoryCalorieTrendProjection(
            range: .week,
            summary: makeSummary(dates: days(fromJanuary: day, count: 1))
        )

        let point = try #require(projection.points.first)
        #expect(point.xAxisLabel == expectedLabel)
    }

    @Test("given a single logged day, when projecting the calorie trend, then there is logged data but no drill-down")
    func singleLoggedDayCannotDrillDown() {
        let dates = days(fromJanuary: 26, count: 7)
        let entries = [makeCalorieEntry(date: janDate(28), calories: 2_000)]

        let projection = HistoryCalorieTrendProjection(
            range: .week,
            summary: makeSummary(dates: dates, entries: entries)
        )

        #expect(projection.loggedPointCount == 1)
        #expect(projection.hasLoggedData)
        #expect(projection.canDrillDown == false)
    }

    @Test("given two logged days, when projecting the calorie trend, then drill-down becomes available")
    func twoLoggedDaysAllowDrillDown() {
        let dates = days(fromJanuary: 26, count: 7)
        let entries = [
            makeCalorieEntry(date: janDate(28), calories: 2_000),
            makeCalorieEntry(date: janDate(29), calories: 2_000)
        ]

        let projection = HistoryCalorieTrendProjection(
            range: .week,
            summary: makeSummary(dates: dates, entries: entries)
        )

        #expect(projection.loggedPointCount == 2)
        #expect(projection.canDrillDown)
    }

    @Test("given a 90-day range with several logged days inside one calendar week, when projecting the calorie trend, then one week is plotted but drill-down stays available")
    func quarterPlotsWeeksButDrillsDownOnLoggedDays() {
        let dates = days(fromJanuary: 5, count: 14)
        let entries = [
            makeCalorieEntry(date: janDate(5), calories: 2_000),
            makeCalorieEntry(date: janDate(6), calories: 2_000),
            makeCalorieEntry(date: janDate(7), calories: 2_000)
        ]

        let projection = HistoryCalorieTrendProjection(
            range: .quarter,
            summary: makeSummary(dates: dates, entries: entries)
        )

        #expect(projection.loggedDayCount == 3)
        #expect(projection.loggedPointCount == 1)
        #expect(projection.canDrillDown)
    }

    @Test("given a projected chart index, when looking up a point, then the index is rounded to the nearest position")
    func pointLookupRoundsIndex() {
        let dates = days(fromJanuary: 26, count: 3)
        let projection = HistoryCalorieTrendProjection(
            range: .week,
            summary: makeSummary(dates: dates)
        )

        #expect(projection.point(for: 0)?.xAxisLabel == "M")
        #expect(projection.point(for: 0.4)?.xAxisLabel == "M")
        #expect(projection.point(for: 0.5)?.xAxisLabel == "T")
        #expect(projection.point(for: 1.6)?.xAxisLabel == "W")
        #expect(projection.point(for: -0.4)?.xAxisLabel == "M")
        #expect(projection.point(for: -1) == nil)
        #expect(projection.point(for: 3) == nil)
    }

    // MARK: - Calorie Trend: axis and totals

    @Test("given logged days above target, when projecting the calorie trend, then the y-axis upper bound clears the largest value")
    func yAxisUpperBoundClearsLargestValue() {
        let dates = days(fromJanuary: 26, count: 3)
        let entries = [
            makeCalorieEntry(date: janDate(26), calories: 2_500),
            makeCalorieEntry(date: janDate(27), calories: 1_500)
        ]

        let projection = HistoryCalorieTrendProjection(
            range: .week,
            summary: makeSummary(dates: dates, entries: entries)
        )

        #expect(abs(projection.yAxisUpperBound - 2_500 * 1.15) < 0.001)
    }

    @Test("given no logged days, when projecting the calorie trend, then the y-axis upper bound falls back to the calorie target")
    func yAxisUpperBoundFallsBackToTarget() {
        let projection = HistoryCalorieTrendProjection(
            range: .week,
            summary: makeSummary(dates: days(fromJanuary: 26, count: 3))
        )

        #expect(abs(projection.yAxisUpperBound - 2_000 * 1.15) < 0.001)
    }

    @Test("given logged and unlogged days, when projecting the calorie trend, then totals count only logged days")
    func totalsCountOnlyLoggedDays() {
        let dates = days(fromJanuary: 26, count: 7)
        let entries = [
            makeCalorieEntry(date: janDate(26), calories: 2_000),
            makeCalorieEntry(date: janDate(27), calories: 2_400)
        ]

        let projection = HistoryCalorieTrendProjection(
            range: .week,
            summary: makeSummary(dates: dates, entries: entries)
        )

        #expect(abs(projection.totalCalories - 4_400) < 0.001)
        #expect(projection.loggedDayTargetTotal == 4_000)
        #expect(projection.totalTargetDelta == 400)
        #expect(projection.totalDifferenceText == "+400 over target")
        #expect(projection.totalTargetDeltaText == "400 kcal over target total")
        #expect(projection.averageDifferenceText == "+200 over target")
    }

    @Test("given logged days that land exactly on their targets, when projecting the calorie trend, then the totals read as on target")
    func totalsOnTargetReadAsOnTarget() {
        let dates = days(fromJanuary: 26, count: 3)
        let entries = [
            makeCalorieEntry(date: janDate(26), calories: 2_000),
            makeCalorieEntry(date: janDate(27), calories: 2_000)
        ]

        let projection = HistoryCalorieTrendProjection(
            range: .week,
            summary: makeSummary(dates: dates, entries: entries)
        )

        #expect(projection.totalTargetDelta == 0)
        #expect(projection.totalTargetDeltaText == "On target total")
        #expect(projection.totalDifferenceText == "On target")
        #expect(projection.averageDifferenceText == "On target")
    }

    @Test("given no logged days, when describing calorie differences, then both difference texts say there are no logged days")
    func differenceTextsReportNoLoggedDays() {
        let projection = HistoryCalorieTrendProjection(
            range: .week,
            summary: makeSummary(dates: days(fromJanuary: 26, count: 7))
        )

        #expect(projection.averageDifferenceText == "No logged days")
        #expect(projection.totalDifferenceText == "No logged days")
    }

    @Test(
        "given a target difference, when describing it for a chart selection, then the wording follows the sign",
        arguments: [
            (0, "On target"),
            (250, "250 kcal over target"),
            (-250, "250 kcal under target")
        ]
    )
    func targetDeltaTextFollowsSign(difference: Int, expected: String) {
        let projection = HistoryCalorieTrendProjection(
            range: .week,
            summary: makeSummary(dates: days(fromJanuary: 26, count: 1))
        )

        #expect(projection.targetDeltaText(difference, unit: "kcal") == expected)
    }

    @Test(
        "given a calorie difference, when describing it as a period difference, then over, under, and on target are distinguished",
        arguments: [
            (300, "+300 over target"),
            (-300, "300 under target"),
            (0, "On target")
        ]
    )
    func differenceTextDistinguishesDirection(difference: Int, expected: String) {
        #expect(HistoryCalorieTrendProjection.differenceText(difference) == expected)
    }

    @Test(
        "given a difference with a unit, when describing it as a delta, then the unit and direction are included",
        arguments: [
            (600, "600 kcal over"),
            (-600, "600 kcal under"),
            (0, "On target")
        ]
    )
    func deltaTextIncludesUnitAndDirection(difference: Int, expected: String) {
        #expect(HistoryCalorieTrendProjection.deltaText(difference, unit: "kcal") == expected)
    }

    @Test("given no logged days, when comparing a value with the period average, then no comparison is offered")
    func averageDeltaTextIsUnavailableWithoutLoggedDays() {
        let projection = HistoryCalorieTrendProjection(
            range: .week,
            summary: makeSummary(dates: days(fromJanuary: 26, count: 7))
        )

        #expect(projection.averageDeltaText(value: 2_000, unit: "kcal") == nil)
    }

    @Test("given logged days, when comparing a value with the period average, then above, below, and matching are distinguished")
    func averageDeltaTextComparesWithPeriodAverage() {
        let dates = days(fromJanuary: 26, count: 3)
        let entries = [makeCalorieEntry(date: janDate(26), calories: 2_000)]

        let projection = HistoryCalorieTrendProjection(
            range: .week,
            summary: makeSummary(dates: dates, entries: entries)
        )

        #expect(projection.averageDeltaText(value: 2_000, unit: "kcal") == "Matches 7-day average")
        #expect(projection.averageDeltaText(value: 2_300, unit: "kcal") == "300 kcal above 7-day average")
        #expect(projection.averageDeltaText(value: 1_700, unit: "kcal") == "300 kcal below 7-day average")
    }

    @Test(
        "given a selected History range, when comparing a value with the period average, then the range is named in the comparison",
        arguments: [
            (HistoryRange.week, "Matches 7-day average"),
            (HistoryRange.twoWeeks, "Matches 14-day average"),
            (HistoryRange.month, "Matches 30-day average"),
            (HistoryRange.quarter, "Matches 90-day average")
        ]
    )
    func averageDeltaTextNamesTheRange(range: HistoryRange, expected: String) {
        let dates = days(fromJanuary: 5, count: 14)
        let entries = [makeCalorieEntry(date: janDate(5), calories: 2_000)]

        let projection = HistoryCalorieTrendProjection(
            range: range,
            summary: makeSummary(dates: dates, entries: entries)
        )

        #expect(projection.averageDeltaText(value: 2_000, unit: "kcal") == expected)
    }

    // MARK: - Calorie Trend: estimated targets

    @Test("given every logged day has a saved daily goal, when projecting the calorie trend, then no estimated-target note is shown")
    func savedDailyGoalsSuppressEstimatedTargetNote() {
        let dates = days(fromJanuary: 26, count: 3)
        let entries = [makeCalorieEntry(date: janDate(26), calories: 2_000)]

        let projection = HistoryCalorieTrendProjection(
            range: .week,
            summary: makeSummary(
                dates: dates,
                entries: entries,
                snapshotTargets: [janDate(26): 2_000]
            )
        )

        #expect(projection.hasEstimatedTargets == false)
        #expect(projection.estimatedTargetNoteText == nil)
    }

    @Test("given a logged day without a saved daily goal, when projecting the calorie trend, then the estimated-target note is shown")
    func missingDailyGoalSurfacesEstimatedTargetNote() {
        let dates = days(fromJanuary: 26, count: 3)
        let entries = [
            makeCalorieEntry(date: janDate(26), calories: 2_000),
            makeCalorieEntry(date: janDate(27), calories: 2_000)
        ]

        let projection = HistoryCalorieTrendProjection(
            range: .week,
            summary: makeSummary(
                dates: dates,
                entries: entries,
                snapshotTargets: [janDate(26): 2_000]
            )
        )

        #expect(projection.hasEstimatedTargets)
        #expect(
            projection.estimatedTargetNoteText
                == "Days without a saved daily goal are compared with your current target."
        )
    }

    @Test("given only unlogged days lack a saved daily goal, when projecting the calorie trend, then no estimated-target note is shown")
    func unloggedDaysDoNotTriggerEstimatedTargetNote() {
        let dates = days(fromJanuary: 26, count: 5)
        let entries = [makeCalorieEntry(date: janDate(26), calories: 2_000)]

        let projection = HistoryCalorieTrendProjection(
            range: .week,
            summary: makeSummary(
                dates: dates,
                entries: entries,
                snapshotTargets: [janDate(26): 2_000]
            )
        )

        #expect(projection.hasEstimatedTargets == false)
        #expect(projection.estimatedTargetNoteText == nil)
    }

    @Test("given days with different saved daily goals, when projecting the calorie trend, then each day is compared with its own target")
    func perDayTargetsDriveDayDeltas() throws {
        let dates = days(fromJanuary: 26, count: 2)
        let entries = [
            makeCalorieEntry(date: janDate(26), calories: 2_000),
            makeCalorieEntry(date: janDate(27), calories: 2_000)
        ]

        let projection = HistoryCalorieTrendProjection(
            range: .week,
            summary: makeSummary(
                dates: dates,
                entries: entries,
                snapshotTargets: [janDate(26): 1_800, janDate(27): 2_000]
            )
        )

        let first = try #require(projection.points.first)
        let second = try #require(projection.points.last)
        #expect(first.targetDelta == 200)
        #expect(first.status == .over)
        #expect(second.targetDelta == 0)
        #expect(second.status == .onTrack)
        #expect(projection.averageTargetPerLoggedDay == 1_900)
        #expect(projection.averageDifferenceText == "+100 over target")
    }

    // MARK: - Calorie Trend: biggest inconsistency

    @Test(
        "given nothing logged in the range, when discovering the biggest swing, then no inconsistency is reported",
        arguments: [HistoryRange.week, .twoWeeks, .month, .quarter]
    )
    func noLoggedDataReportsNoBiggestSwing(range: HistoryRange) {
        let projection = HistoryCalorieTrendProjection(
            range: range,
            summary: makeSummary(dates: days(fromJanuary: 5, count: 14))
        )

        #expect(projection.biggestInconsistencyText == nil)
    }

    @Test("given every logged day is on track, when discovering the biggest swing, then the range is reported as stable")
    func allOnTrackDaysReportStability() {
        let dates = days(fromJanuary: 26, count: 5)
        let entries = [
            makeCalorieEntry(date: janDate(26), calories: 2_000),
            makeCalorieEntry(date: janDate(27), calories: 2_050),
            makeCalorieEntry(date: janDate(28), calories: 1_950)
        ]

        let projection = HistoryCalorieTrendProjection(
            range: .week,
            summary: makeSummary(dates: dates, entries: entries)
        )

        #expect(projection.biggestInconsistencyText == "Most stable: logged days stayed near target")
    }

    @Test("given one logged day far over target, when discovering the biggest swing, then that day is named with its overage")
    func biggestSwingNamesTheDayOverTarget() {
        let dates = days(fromJanuary: 26, count: 5)
        let entries = [
            makeCalorieEntry(date: janDate(26), calories: 2_000),
            makeCalorieEntry(date: janDate(27), calories: 2_100),
            makeCalorieEntry(date: janDate(28), calories: 2_600)
        ]

        let projection = HistoryCalorieTrendProjection(
            range: .week,
            summary: makeSummary(dates: dates, entries: entries)
        )

        #expect(
            projection.biggestInconsistencyText
                == "Biggest swing: \(janDate(28).shortFormatted), 600 kcal over"
        )
    }

    @Test("given one logged day far under target, when discovering the biggest swing, then that day is named with its shortfall")
    func biggestSwingNamesTheDayUnderTarget() {
        let dates = days(fromJanuary: 26, count: 5)
        let entries = [
            makeCalorieEntry(date: janDate(26), calories: 2_000),
            makeCalorieEntry(date: janDate(27), calories: 1_200)
        ]

        let projection = HistoryCalorieTrendProjection(
            range: .week,
            summary: makeSummary(dates: dates, entries: entries)
        )

        #expect(
            projection.biggestInconsistencyText
                == "Biggest swing: \(janDate(27).shortFormatted), 800 kcal under"
        )
    }

    @Test("given two logged days with equally large opposite swings, when discovering the biggest swing, then the earlier day is reported")
    func equalSwingsReportTheEarlierDay() {
        let dates = days(fromJanuary: 26, count: 5)
        let entries = [
            makeCalorieEntry(date: janDate(26), calories: 2_300),
            makeCalorieEntry(date: janDate(27), calories: 1_700)
        ]

        let projection = HistoryCalorieTrendProjection(
            range: .week,
            summary: makeSummary(dates: dates, entries: entries)
        )

        #expect(
            projection.biggestInconsistencyText
                == "Biggest swing: \(janDate(26).shortFormatted), 300 kcal over"
        )
    }

    @Test("given a 90-day range where every logged week stays near target, when discovering the biggest swing, then the weeks are reported as stable")
    func allOnTrackWeeksReportStability() {
        let dates = days(fromJanuary: 5, count: 14)
        let entries = [
            makeCalorieEntry(date: janDate(5), calories: 2_000),
            makeCalorieEntry(date: janDate(12), calories: 2_050)
        ]

        let projection = HistoryCalorieTrendProjection(
            range: .quarter,
            summary: makeSummary(dates: dates, entries: entries)
        )

        #expect(projection.biggestInconsistencyText == "Most stable: logged weeks stayed near target")
    }

    @Test("given a 90-day range with one week far off target, when discovering the biggest swing, then that week is named with its per-day delta")
    func biggestWeeklySwingNamesTheWeek() {
        let dates = days(fromJanuary: 5, count: 14)
        let entries = [
            makeCalorieEntry(date: janDate(5), calories: 2_000),
            makeCalorieEntry(date: janDate(12), calories: 2_500)
        ]

        let projection = HistoryCalorieTrendProjection(
            range: .quarter,
            summary: makeSummary(dates: dates, entries: entries)
        )

        #expect(
            projection.biggestInconsistencyText
                == "Biggest swing: week of \(janDate(12).startOfWeek.dayMonthFormatted), 500 kcal/day over"
        )
    }

    // MARK: - Calorie Trend: top foods behind a selection

    @Test("given a selected logged day, when discovering its food drivers, then foods are merged by name and ranked by calories")
    func dayDrillDownRanksTopFoods() throws {
        let dates = days(fromJanuary: 26, count: 3)
        let entries = [
            makeCalorieEntry(date: janDate(26), name: "Oats", calories: 300),
            makeCalorieEntry(date: janDate(26), name: "Pasta", calories: 700),
            makeCalorieEntry(date: janDate(26), name: "Oats", calories: 150)
        ]

        let projection = HistoryCalorieTrendProjection(
            range: .week,
            summary: makeSummary(dates: dates, entries: entries)
        )

        let selection = try #require(projection.points.first?.selection)
        let foods = projection.topFoods(for: selection)

        #expect(foods.map(\.name) == ["Pasta", "Oats"])
        #expect(foods.first?.entryCount == 1)
        #expect(foods.last?.entryCount == 2)
        #expect(abs((foods.last?.calories ?? 0) - 450) < 0.001)
    }

    @Test("given a selected calendar week, when discovering its food drivers, then foods are aggregated across the week's logged days")
    func weekDrillDownAggregatesFoodsAcrossDays() throws {
        let dates = days(fromJanuary: 5, count: 7)
        let entries = [
            makeCalorieEntry(date: janDate(5), name: "Oats", calories: 300),
            makeCalorieEntry(date: janDate(5), name: "Pasta", calories: 600),
            makeCalorieEntry(date: janDate(6), name: "Pasta", calories: 400)
        ]

        let projection = HistoryCalorieTrendProjection(
            range: .quarter,
            summary: makeSummary(dates: dates, entries: entries)
        )

        let selection = try #require(projection.points.first?.selection)
        let foods = projection.topFoods(for: selection)

        #expect(foods.map(\.name) == ["Pasta", "Oats"])
        #expect(foods.first?.entryCount == 2)
        #expect(abs((foods.first?.calories ?? 0) - 1_000) < 0.001)
        #expect(abs((foods.first?.portionGrams ?? 0) - 200) < 0.001)
    }

    @Test("given two week foods with identical calories, when discovering food drivers, then they are ordered by name")
    func equalCalorieFoodsAreOrderedByName() throws {
        let dates = days(fromJanuary: 5, count: 7)
        let entries = [
            makeCalorieEntry(date: janDate(5), name: "Zucchini", calories: 200),
            makeCalorieEntry(date: janDate(6), name: "Apple", calories: 200)
        ]

        let projection = HistoryCalorieTrendProjection(
            range: .quarter,
            summary: makeSummary(dates: dates, entries: entries)
        )

        let selection = try #require(projection.points.first?.selection)
        #expect(projection.topFoods(for: selection).map(\.name) == ["Apple", "Zucchini"])
    }

    @Test("given a selected week with no logged days, when discovering its food drivers, then no foods are reported")
    func weekWithoutLoggedDaysHasNoFoodDrivers() throws {
        let dates = days(fromJanuary: 5, count: 7)

        let projection = HistoryCalorieTrendProjection(
            range: .quarter,
            summary: makeSummary(dates: dates)
        )

        let selection = try #require(projection.points.first?.selection)
        #expect(projection.topFoods(for: selection).isEmpty)
    }

    // MARK: - Weekly Consistency

    @Test("given a range spanning two calendar weeks, when projecting weekly consistency, then logged and total day counts cover the whole range")
    func weeklyConsistencyCountsLoggedAndTotalDays() {
        let dates = days(fromJanuary: 5, count: 14)
        let entries = [
            makeCalorieEntry(date: janDate(5), calories: 2_000),
            makeCalorieEntry(date: janDate(12), calories: 2_000)
        ]

        let projection = HistoryWeeklyConsistencyProjection(
            summary: makeSummary(dates: dates, entries: entries)
        )

        #expect(projection.weeks.count == 2)
        #expect(projection.loggedDayCount == 2)
        #expect(projection.totalDayCount == 14)
    }

    @Test("given nothing logged in the range, when projecting weekly consistency, then there is no best week and no headline")
    func weeklyConsistencyWithoutLoggedDaysHasNoBestWeek() {
        let projection = HistoryWeeklyConsistencyProjection(
            summary: makeSummary(dates: days(fromJanuary: 5, count: 14))
        )

        #expect(projection.weeks.count == 2)
        #expect(projection.bestWeek == nil)
        #expect(projection.headlineText == nil)
    }

    @Test("given two logged weeks with different on-track ratios, when projecting weekly consistency, then the higher ratio wins")
    func bestWeekIsTheHighestOnTrackRatio() {
        let dates = days(fromJanuary: 5, count: 14)
        let entries = [
            makeCalorieEntry(date: janDate(5), calories: 2_000),
            makeCalorieEntry(date: janDate(6), calories: 2_600),
            makeCalorieEntry(date: janDate(12), calories: 2_000),
            makeCalorieEntry(date: janDate(13), calories: 2_000)
        ]

        let projection = HistoryWeeklyConsistencyProjection(
            summary: makeSummary(dates: dates, entries: entries)
        )

        #expect(projection.bestWeek?.startDate == janDate(12).startOfWeek)
        #expect(projection.headlineText == "Best week had 2 of 2 logged days on track.")
    }

    @Test("given two fully on-track weeks with different logged-day counts, when projecting weekly consistency, then the better covered week wins")
    func bestWeekTieBreaksOnLoggedDays() {
        let dates = days(fromJanuary: 5, count: 14)
        let entries = [
            makeCalorieEntry(date: janDate(5), calories: 2_000),
            makeCalorieEntry(date: janDate(6), calories: 2_000),
            makeCalorieEntry(date: janDate(12), calories: 2_000),
            makeCalorieEntry(date: janDate(13), calories: 2_000),
            makeCalorieEntry(date: janDate(14), calories: 2_000)
        ]

        let projection = HistoryWeeklyConsistencyProjection(
            summary: makeSummary(dates: dates, entries: entries)
        )

        #expect(projection.bestWeek?.startDate == janDate(12).startOfWeek)
        #expect(projection.headlineText == "Best week had 3 of 3 logged days on track.")
    }

    @Test("given the best week has a single logged day, when projecting weekly consistency, then the headline uses the singular day label")
    func singleLoggedDayHeadlineUsesSingularLabel() {
        let dates = days(fromJanuary: 5, count: 7)
        let entries = [makeCalorieEntry(date: janDate(5), calories: 2_000)]

        let projection = HistoryWeeklyConsistencyProjection(
            summary: makeSummary(dates: dates, entries: entries)
        )

        #expect(projection.headlineText == "Best week had 1 of 1 logged day on track.")
    }

    @Test("given the best week has logged days that were not on track, when projecting weekly consistency, then the headline reports the on-track share")
    func headlineReportsOnTrackShareOfLoggedDays() {
        let dates = days(fromJanuary: 5, count: 7)
        let entries = [
            makeCalorieEntry(date: janDate(5), calories: 2_000),
            makeCalorieEntry(date: janDate(6), calories: 2_000),
            makeCalorieEntry(date: janDate(7), calories: 2_600)
        ]

        let projection = HistoryWeeklyConsistencyProjection(
            summary: makeSummary(dates: dates, entries: entries)
        )

        #expect(projection.headlineText == "Best week had 2 of 3 logged days on track.")
    }

    // MARK: - Macro Patterns

    @Test("given no macro patterns, when discovering the least consistent macro, then nothing is reported")
    func noMacroPatternsReportNothing() {
        #expect(HistoryMacroPatternsProjection(patterns: []).summaryText == nil)
    }

    @Test("given macro patterns with no logged days, when discovering the least consistent macro, then nothing is reported")
    func macroPatternsWithoutLoggedDaysReportNothing() {
        let projection = HistoryMacroPatternsProjection(patterns: [
            makeMacroPattern(nutrient: .protein, loggedDays: 0, hitDays: 0),
            makeMacroPattern(nutrient: .carbs, loggedDays: 0, hitDays: 0)
        ])

        #expect(projection.summaryText == nil)
    }

    @Test("given macro patterns with different hit days, when discovering the least consistent macro, then the fewest hit days is reported")
    func leastConsistentMacroIsTheFewestHitDays() {
        let projection = HistoryMacroPatternsProjection(patterns: [
            makeMacroPattern(nutrient: .protein, loggedDays: 5, hitDays: 4),
            makeMacroPattern(nutrient: .carbs, loggedDays: 5, hitDays: 1),
            makeMacroPattern(nutrient: .fat, loggedDays: 5, hitDays: 3)
        ])

        #expect(projection.summaryText == "Carbs was the least consistent macro at 1 of 5 logged days.")
    }

    @Test("given a nutrient with a compact display name, when discovering the least consistent macro, then the compact name is used")
    func leastConsistentMacroUsesCompactNutrientName() {
        let projection = HistoryMacroPatternsProjection(patterns: [
            makeMacroPattern(nutrient: .protein, loggedDays: 3, hitDays: 3),
            makeMacroPattern(nutrient: .saturatedFat, loggedDays: 3, hitDays: 0)
        ])

        #expect(projection.summaryText == "Sat Fat was the least consistent macro at 0 of 3 logged days.")
    }

    @Test("given macro patterns tied on hit days, when discovering the least consistent macro, then the first listed macro is reported")
    func tiedMacroPatternsReportTheFirstListed() {
        let projection = HistoryMacroPatternsProjection(patterns: [
            makeMacroPattern(nutrient: .protein, loggedDays: 4, hitDays: 2),
            makeMacroPattern(nutrient: .carbs, loggedDays: 4, hitDays: 2)
        ])

        #expect(projection.summaryText == "Protein was the least consistent macro at 2 of 4 logged days.")
    }

    @Test("given a macro pattern with no logged days alongside a logged one, when discovering the least consistent macro, then the unlogged macro is ignored")
    func unloggedMacroPatternsAreIgnored() {
        let projection = HistoryMacroPatternsProjection(patterns: [
            makeMacroPattern(nutrient: .carbs, loggedDays: 0, hitDays: 0),
            makeMacroPattern(nutrient: .fat, loggedDays: 2, hitDays: 1)
        ])

        #expect(projection.summaryText == "Fat was the least consistent macro at 1 of 2 logged days.")
    }

    // MARK: - Pattern Discovery as a whole

    @Test("given no profile targets, when discovering patterns, then macro patterns are absent while the calorie trend still projects")
    func missingProfileTargetsLeaveOnlyCalorieAndWeeklyPatterns() {
        let analytics = HistoryAnalytics(
            entries: [],
            profile: nil,
            range: .week,
            endDate: janDate(30)
        )

        let discovery = HistoryPatternDiscovery(analytics: analytics)

        #expect(discovery.macroPatterns.patterns.isEmpty)
        #expect(discovery.macroPatterns.summaryText == nil)
        #expect(discovery.calorieTrend.points.count == 7)
        // No saved profile falls back to the documented 2,000 kcal target.
        #expect(discovery.calorieTrend.dailyCalorieTarget == 2_000)
        #expect(discovery.weeklyConsistency.totalDayCount == 7)
        #expect(discovery.weeklyConsistency.bestWeek == nil)
    }

    @Test("given a logged week, when discovering patterns, then the calorie trend and weekly consistency describe the same logged days")
    func discoveryProjectionsAgreeOnLoggedDays() {
        let profile = makeProfile()
        let entries = [
            makeCalorieEntry(date: janDate(26), calories: 2_000),
            makeCalorieEntry(date: janDate(27), calories: 2_000),
            makeCalorieEntry(date: janDate(28), calories: 2_600)
        ]

        let analytics = HistoryAnalytics(
            entries: entries,
            profile: profile,
            range: .week,
            endDate: janDate(30)
        )

        let discovery = HistoryPatternDiscovery(analytics: analytics)

        #expect(discovery.calorieTrend.loggedDayCount == 3)
        #expect(discovery.weeklyConsistency.loggedDayCount == 3)
        #expect(discovery.calorieTrend.totalDayCount == discovery.weeklyConsistency.totalDayCount)
        #expect(discovery.calorieTrend.onTrackLoggedDayCount == 2)
        #expect(discovery.weeklyConsistency.headlineText == "Best week had 2 of 3 logged days on track.")
    }

    // MARK: - Fixtures

    private func janDate(_ day: Int) -> Date {
        makeTestDate(year: 2026, month: 1, day: day)
    }

    private func days(fromJanuary startDay: Int, count: Int) -> [Date] {
        let start = janDate(startDay)
        return (0..<count).compactMap {
            Calendar.current.date(byAdding: .day, value: $0, to: start)
        }
    }

    private func makeProfile() -> UserProfile {
        UserProfile(
            age: 30,
            sex: .male,
            heightCm: 180,
            weightKg: 80,
            activityLevel: .moderatelyActive,
            dailyCalorieTarget: 2_000
        )
    }

    private func makeCalorieEntry(
        date: Date,
        name: String = "Test Food",
        calories: Double
    ) -> FoodLogEntry {
        makeTestEntry(
            date: date,
            foodItem: makeTestFoodItem(
                name: name,
                caloriesPer100g: calories,
                proteinPer100g: 0,
                carbsPer100g: 0,
                fatPer100g: 0
            ),
            portionGrams: 100
        )
    }

    private func makeSummary(
        dates: [Date],
        entries: [FoodLogEntry] = [],
        fallbackTarget: Int = 2_000,
        snapshotTargets: [Date: Int] = [:]
    ) -> HistoryPeriodSummary {
        let calendar = Calendar.current
        let entriesByDate = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.date)
        }

        var valuesByDayKey: [String: DailyGoalSnapshotValues] = [:]
        for (date, target) in snapshotTargets {
            valuesByDayKey[DailyGoalSnapshot.dayKey(for: date, calendar: calendar)] =
                DailyGoalSnapshotValues(
                    baseCalorieTarget: target,
                    healthAdjustment: 0,
                    effectiveCalorieTarget: target,
                    calculationMode: .lifestyleEstimate,
                    isManualTarget: false
                )
        }

        return HistoryPeriodSummary(
            dates: dates,
            entriesByDate: entriesByDate,
            targetResolver: HistoryDayTargetResolver(
                fallbackTarget: fallbackTarget,
                valuesByDayKey: valuesByDayKey
            ),
            calendar: calendar
        )
    }

    private func makeMacroPattern(
        nutrient: TrackedNutrient,
        loggedDays: Int,
        hitDays: Int,
        averageValue: Double = 0
    ) -> HistoryMacroPattern {
        HistoryMacroPattern(
            nutrient: nutrient,
            goalKind: nutrient.defaultGoalKind,
            current: HistoryNutrientPeriodSummary(
                loggedDays: loggedDays,
                hitDays: hitDays,
                averageValue: averageValue
            ),
            previous: HistoryNutrientPeriodSummary(
                loggedDays: 0,
                hitDays: 0,
                averageValue: 0
            )
        )
    }
}
