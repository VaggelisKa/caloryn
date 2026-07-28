import CoreGraphics
import Foundation
import Testing
@testable import Caloryn

/// The weekly-consistency chart's layout and labelling. Weeks are numbered by
/// position, so a week with nothing logged still holds its place.
@Suite("History weekly consistency chart")
struct HistoryWeeklyConsistencyChartTests {

    @Test("given no weeks, when scaling the chart, then it still has a drawable domain")
    func noWeeksStillScales() {
        let chart = HistoryWeeklyConsistencyChart(weekCount: 0)

        #expect(chart.weekCount == 0)
        #expect(chart.indices.isEmpty)
        #expect(chart.xAxisDomain == 0 ... 1)
    }

    @Test("given a handful of weeks, when scaling the chart, then the first and last bars are not clipped")
    func theDomainPadsBothEnds() {
        #expect(HistoryWeeklyConsistencyChart(weekCount: 5).xAxisDomain == -0.5 ... 4.5)
    }

    @Test(
        "given a week count, when sizing bars, then they shrink only past the dense threshold",
        arguments: [(1, CGFloat(16)), (10, 16), (11, 12), (14, 12)]
    )
    func barsShrinkOnlyOnceCrowded(weekCount: Int, expected: CGFloat) {
        let chart = HistoryWeeklyConsistencyChart(weekCount: weekCount)

        #expect(chart.barWidth == expected)
        #expect(chart.isDense == (weekCount > HistoryWeeklyConsistencyChart.denseWeekThreshold))
    }

    @Test("given the dense threshold exactly, when sizing bars, then the chart is not yet dense")
    func theThresholdItselfIsNotDense() {
        #expect(HistoryWeeklyConsistencyChart(weekCount: 10).isDense == false)
        #expect(HistoryWeeklyConsistencyChart(weekCount: 11).isDense)
    }

    @Test("given a week's position, when labelling it, then W1 is the oldest week")
    func weeksAreNumberedFromTheOldest() {
        #expect(HistoryWeeklyConsistencyChart.label(forOffset: 0) == "W1")
        #expect(HistoryWeeklyConsistencyChart.label(forOffset: 12) == "W13")
    }

    @Test("given a chart-space x value, when labelling it, then it rounds to the nearest week")
    func labelsRoundToTheNearestWeek() {
        let chart = HistoryWeeklyConsistencyChart(weekCount: 13)

        #expect(chart.label(forChartValue: 0) == "W1")
        #expect(chart.label(forChartValue: 2.4) == "W3")
        #expect(chart.label(forChartValue: 2.6) == "W4")
    }

    @Test("given an x value past the last week, when labelling it, then there is no label")
    func valuesOutsideTheSeriesHaveNoLabel() {
        let chart = HistoryWeeklyConsistencyChart(weekCount: 13)

        #expect(chart.label(forChartValue: 13) == nil)
        #expect(chart.label(forChartValue: -1) == nil)
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
}
