import CoreGraphics
import Foundation
import Testing
@testable import Caloryn

@Suite("History chart axis and calorie trend layout")
@MainActor
struct HistoryCalorieTrendChartLayoutTests {
    @Test("given no slots, when scaling the axis, then a unit domain keeps the chart drawable")
    func emptyAxisFallsBackToAUnitDomain() {
        #expect(HistoryChartIndexAxis(slotCount: 0).domain == 0 ... 1)
    }

    @Test("given a negative slot count, when building the axis, then it clamps to empty")
    func negativeSlotCountClampsToEmpty() {
        let axis = HistoryChartIndexAxis(slotCount: -4)

        #expect(axis.slotCount == 0)
        #expect(axis.domain == 0 ... 1)
    }

    @Test("given a single slot, when scaling the axis, then it is padded on both sides")
    func singleSlotIsPaddedOnBothSides() {
        #expect(HistoryChartIndexAxis(slotCount: 1).domain == -0.5 ... 0.5)
    }

    @Test("given seven slots, when scaling the axis, then the first and last bars are not clipped")
    func domainPadsHalfASlotAtEachEnd() {
        #expect(HistoryChartIndexAxis(slotCount: 7).domain == -0.5 ... 6.5)
    }

    @Test(
        "given a range, when sizing bars, then only the 7-day range gets wide ones",
        arguments: [
            (HistoryRange.week, CGFloat(10)),
            (.twoWeeks, 6),
            (.month, 6),
            (.quarter, 6)
        ]
    )
    func barWidthFollowsTheRange(range: HistoryRange, expected: CGFloat) {
        #expect(HistoryCalorieTrendChartLayout(range: range, pointCount: 7).barWidth == expected)
    }

    @Test("given a longer range, when sizing the chart, then it grows to fit the extra bars")
    func longerRangesGetATallerChart() {
        let week = HistoryCalorieTrendChartLayout(range: .week, pointCount: 7)
        let quarter = HistoryCalorieTrendChartLayout(range: .quarter, pointCount: 13)

        #expect(week.chartHeight == 160)
        #expect(quarter.chartHeight == 180)
    }

    @Test("given a point count, when scaling the x axis, then it matches the shared axis")
    func layoutDelegatesTheDomainToTheSharedAxis() {
        let layout = HistoryCalorieTrendChartLayout(range: .month, pointCount: 30)

        #expect(layout.xAxisDomain == HistoryChartIndexAxis(slotCount: 30).domain)
        #expect(layout.xAxisDomain == -0.5 ... 29.5)
    }

    @Test(
        "given a range, when choosing the axis label size, then only the 14-day and 90-day ranges use the dense size",
        arguments: [
            (HistoryRange.week, false),
            (.twoWeeks, true),
            (.month, false),
            (.quarter, true)
        ]
    )
    func onlyTheTwoWeekAndQuarterRangesUseDenseAxisLabels(range: HistoryRange, isDense: Bool) {
        let layout = HistoryCalorieTrendChartLayout(range: range, pointCount: 30)

        #expect(layout.usesDenseAxisLabels == isDense)
    }
}
