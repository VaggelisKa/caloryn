import CoreGraphics
import Foundation
import Testing
@testable import Caloryn

@Suite("History weekly consistency chart")
@MainActor
struct HistoryWeeklyConsistencyChartTests {
    @Test("given no weeks, when scaling the chart, then it still has a drawable domain")
    func noWeeksStillScales() {
        let chart = makeChart(weekCount: 0)

        #expect(chart.weekCount == 0)
        #expect(chart.indices.isEmpty)
        #expect(chart.xAxisDomain == 0 ... 1)
    }

    @Test("given a handful of weeks, when scaling the chart, then the first and last bars are not clipped")
    func theDomainPadsBothEnds() {
        #expect(makeChart(weekCount: 5).xAxisDomain == -0.5 ... 4.5)
    }

    @Test(
        "given a week count, when sizing bars, then they shrink only past the dense threshold",
        arguments: [(1, CGFloat(16)), (10, 16), (11, 12), (14, 12)]
    )
    func barsShrinkOnlyOnceCrowded(weekCount: Int, expected: CGFloat) {
        let chart = makeChart(weekCount: weekCount)

        #expect(chart.barWidth == expected)
        #expect(chart.isDense == (weekCount > HistoryWeeklyConsistencyChart.denseWeekThreshold))
    }

    @Test("given the dense threshold exactly, when sizing bars, then the chart is not yet dense")
    func theThresholdItselfIsNotDense() {
        #expect(makeChart(weekCount: 10).isDense == false)
        #expect(makeChart(weekCount: 11).isDense)
    }

    @Test(
        "given a week count, when deciding whether counts fit above the bars, then they show only until the chart is dense",
        arguments: [(5, true), (10, true), (11, false), (14, false)]
    )
    func countsShowOnlyWhileTheyFit(weekCount: Int, expected: Bool) {
        #expect(makeChart(weekCount: weekCount).showsCounts == expected)
    }

    @Test("given a week's position, when numbering it for the day strip, then W1 is the oldest week")
    func weeksAreNumberedFromTheOldest() {
        #expect(HistoryWeeklyConsistencyChart.label(forOffset: 0) == "W1")
        #expect(HistoryWeeklyConsistencyChart.label(forOffset: 12) == "W13")
    }

    @Test("given five weeks ending with today's, when labelling the axis, then each week shows its start date and the last reads This week")
    func axisLabelsAreStartDatesEndingInThisWeek() {
        let chart = makeChart(weekCount: 5)

        #expect(chart.weeks.map(\.axisLabel) == ["28 Sep", "5 Oct", "12 Oct", "19 Oct", "This week"])
    }

    @Test("given a period that ended before this week, when labelling the axis, then no week reads This week")
    func aPastPeriodHasNoCurrentWeek() {
        let chart = makeChart(weekCount: 2, today: date(2026, 11, 20))

        #expect(chart.weeks.map(\.axisLabel) == ["19 Oct", "26 Oct"])
        #expect(chart.weeks.allSatisfy { !$0.isCurrent })
    }

    @Test("given thirteen weeks, when labelling the axis, then every other week is labelled counting back from this week")
    func aDenseAxisLabelsEveryOtherWeek() {
        let chart = makeChart(weekCount: 13)
        let labelled = chart.weeks.filter { $0.axisLabel != nil }.map(\.index)

        #expect(labelled == [0, 2, 4, 6, 8, 10, 12])
        #expect(chart.weeks.last?.axisLabel == "This week")
        #expect(chart.weeks[1].axisLabel == nil)
    }

    @Test("given an even dense week count, when labelling the axis, then this week stays labelled and the oldest is skipped")
    func anEvenDenseAxisStillLabelsThisWeek() {
        let chart = makeChart(weekCount: 12)

        #expect(chart.weeks.first?.axisLabel == nil)
        #expect(chart.weeks.last?.axisLabel == "This week")
    }

    @Test("given a chart-space x value, when labelling it, then it rounds to the nearest week")
    func labelsRoundToTheNearestWeek() {
        let chart = makeChart(weekCount: 5)

        #expect(chart.label(forChartValue: 0) == "28 Sep")
        #expect(chart.label(forChartValue: 1.4) == "5 Oct")
        #expect(chart.label(forChartValue: 1.6) == "12 Oct")
    }

    @Test("given an x value past the last week, when labelling it, then there is no label")
    func valuesOutsideTheSeriesHaveNoLabel() {
        let chart = makeChart(weekCount: 13)

        #expect(chart.label(forChartValue: 13) == nil)
        #expect(chart.label(forChartValue: -1) == nil)
    }

    @Test(
        "given a week's tally, when stating it above the bar, then it reads on-track over logged",
        arguments: [(4, 5, "4/5"), (6, 7, "6/7"), (3, 3, "3/3"), (0, 1, "0/1")]
    )
    func theCountReadsOnTrackOverLogged(onTrackDays: Int, loggedDays: Int, expected: String) {
        let week = makeWeek(onTrackDays: onTrackDays, loggedDays: loggedDays)

        #expect(week.countText == expected)
    }

    @Test("given a week with no logged days, when stating it above the bar, then there is no count")
    func aWeekWithoutLoggedDaysHasNoCount() {
        #expect(makeWeek(onTrackDays: 0, loggedDays: 0).countText == nil)
    }

    @Test(
        "given a week's tally, when sizing its bar, then it is the on-track share of logged days",
        arguments: [(4, 5, 80.0), (3, 3, 100.0), (0, 0, 0.0), (9, 3, 100.0)] as [(Int, Int, Double)]
    )
    func theBarIsTheOnTrackShare(onTrackDays: Int, loggedDays: Int, expected: Double) {
        #expect(makeWeek(onTrackDays: onTrackDays, loggedDays: loggedDays).onTrackPercentage == expected)
    }

    @Test(
        "given a week's tally, when spoken, then it names the week by its start date and states the share",
        arguments: [
            (4, 5, "Week of 28 Sep, 4 of 5 logged days on track"),
            (1, 1, "Week of 28 Sep, 1 of 1 logged day on track"),
            (0, 0, "Week of 28 Sep, no days logged")
        ]
    )
    func eachWeekIsSpoken(onTrackDays: Int, loggedDays: Int, expected: String) {
        #expect(makeWeek(onTrackDays: onTrackDays, loggedDays: loggedDays).accessibilityLabel == expected)
    }

    @Test("given this week, when spoken, then it is still named by its start date")
    func thisWeekIsSpokenByDate() {
        let chart = makeChart(weekCount: 1)

        #expect(chart.weeks.first?.axisLabel == "This week")
        #expect(chart.weeks.first?.accessibilityLabel == "Week of 26 Oct, no days logged")
    }

    @Test("given the period's coverage, when describing the chart, then both counts are spoken")
    func theChartIsSpokenWithItsCoverage() {
        #expect(
            HistoryWeeklyConsistencyChart.accessibilityLabel(
                loggedDayCount: 18,
                totalDayCount: 30
            ) == "Weekly consistency of on-track days. 18 of 30 days logged."
        )
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    private func makeChart(weekCount: Int, today: Date? = nil) -> HistoryWeeklyConsistencyChart {
        let lastWeekStart = date(2026, 10, 26)
        let tallies = (0 ..< weekCount).map { offset in
            HistoryWeeklyConsistencyChart.Tally(
                startDate: calendar.date(byAdding: .day, value: -7 * (weekCount - 1 - offset), to: lastWeekStart) ?? lastWeekStart,
                onTrackDays: 0,
                loggedDays: 0
            )
        }
        return HistoryWeeklyConsistencyChart(
            tallies: tallies,
            calendar: calendar,
            today: today ?? date(2026, 10, 29)
        )
    }

    private func makeWeek(onTrackDays: Int, loggedDays: Int) -> HistoryWeeklyConsistencyChart.Week {
        let chart = HistoryWeeklyConsistencyChart(
            tallies: [
                HistoryWeeklyConsistencyChart.Tally(
                    startDate: date(2026, 9, 28),
                    onTrackDays: onTrackDays,
                    loggedDays: loggedDays
                )
            ],
            calendar: calendar,
            today: date(2026, 10, 29)
        )
        return chart.weeks[0]
    }
}
