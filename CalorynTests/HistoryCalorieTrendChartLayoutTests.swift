import CoreGraphics
import Foundation
import Testing
@testable import Caloryn

/// The positional axis every History bar chart plots against, and the two
/// surfaces the calorie-trend chart is drawn on. Nothing here needs a store,
/// a clock or a rendered chart.
@Suite("History chart axis and calorie trend layout")
struct HistoryCalorieTrendChartLayoutTests {

    // MARK: - Axis: domain

    @Test("given no slots, when scaling the axis, then a unit domain keeps the chart drawable")
    func emptyAxisFallsBackToAUnitDomain() {
        #expect(HistoryChartIndexAxis(slotCount: 0).domain == 0 ... 1)
    }

    @Test("given a negative slot count, when building the axis, then it clamps to empty")
    func negativeSlotCountClampsToEmpty() {
        let axis = HistoryChartIndexAxis(slotCount: -4)

        #expect(axis.slotCount == 0)
        #expect(axis.indices.isEmpty)
        #expect(axis.domain == 0 ... 1)
    }

    @Test("given a single slot, when scaling the axis, then it is padded on both sides")
    func singleSlotIsPaddedOnBothSides() {
        #expect(HistoryChartIndexAxis(slotCount: 1).domain == -0.5 ... 0.5)
    }

    @Test("given seven slots, when scaling the axis, then the first and last bars are not clipped")
    func domainPadsHalfASlotAtEachEnd() {
        let axis = HistoryChartIndexAxis(slotCount: 7)

        #expect(axis.domain == -0.5 ... 6.5)
        #expect(axis.indices == [0, 1, 2, 3, 4, 5, 6])
    }

    // MARK: - Axis: which slot was touched

    @Test(
        "given a chart-space x value, when resolving a slot, then it rounds to the nearest bar",
        arguments: [
            (-0.4, 0),
            (0.0, 0),
            (0.49, 0),
            (0.5, 1),
            (2.51, 3),
            (6.4, 6)
        ]
    )
    func slotRoundsToTheNearestBar(value: Double, expected: Int) {
        #expect(HistoryChartIndexAxis(slotCount: 7).slot(for: value) == expected)
    }

    @Test(
        "given an x value past either end, when resolving a slot, then nothing is selected",
        arguments: [-0.6, -12, 6.5, 900]
    )
    func slotOutsideTheSeriesSelectsNothing(value: Double) {
        #expect(HistoryChartIndexAxis(slotCount: 7).slot(for: value) == nil)
    }

    @Test("given a non-finite x value, when resolving a slot, then nothing is selected")
    func nonFiniteValueSelectsNothing() {
        let axis = HistoryChartIndexAxis(slotCount: 7)

        #expect(axis.slot(for: .nan) == nil)
        #expect(axis.slot(for: .infinity) == nil)
        #expect(axis.slot(for: -.infinity) == nil)
    }

    @Test("given an empty series, when resolving a slot, then nothing is selected")
    func emptySeriesSelectsNothing() {
        #expect(HistoryChartIndexAxis(slotCount: 0).slot(for: 0) == nil)
    }

    // MARK: - Axis: hit targets

    @Test("given a wide plot, when sizing tap targets, then each bar gets an equal share")
    func hitTargetsSplitThePlotEvenly() {
        let axis = HistoryChartIndexAxis(slotCount: 7)

        #expect(axis.hitTargetWidth(plotWidth: 350) == 50)
    }

    @Test("given many bars in a narrow plot, when sizing tap targets, then they stop shrinking at the floor")
    func hitTargetsNeverFallBelowTheFloor() {
        let axis = HistoryChartIndexAxis(slotCount: 30)

        #expect(axis.hitTargetWidth(plotWidth: 300) == HistoryChartIndexAxis.minimumHitTargetWidth)
    }

    @Test("given no bars, when sizing tap targets, then the width is finite rather than a division by zero")
    func hitTargetWidthWithNoBarsIsFinite() {
        let width = HistoryChartIndexAxis(slotCount: 0).hitTargetWidth(plotWidth: 300)

        #expect(width == 300)
    }

    // MARK: - Axis: taps outside the plot

    @Test("given a touch inside the plot, when locating it, then the offset is relative to the plot's leading edge")
    func touchInsideThePlotIsMadeRelative() {
        let axis = HistoryChartIndexAxis(slotCount: 7)
        let plot = CGRect(x: 40, y: 10, width: 300, height: 200)

        #expect(axis.plotLocalX(for: CGPoint(x: 140, y: 100), in: plot) == 100)
    }

    @Test("given a touch outside the plot, when locating it, then it is discarded rather than clamped")
    func touchOutsideThePlotIsDiscarded() {
        let axis = HistoryChartIndexAxis(slotCount: 7)
        let plot = CGRect(x: 40, y: 10, width: 300, height: 200)

        #expect(axis.plotLocalX(for: CGPoint(x: 10, y: 100), in: plot) == nil)
        #expect(axis.plotLocalX(for: CGPoint(x: 140, y: 900), in: plot) == nil)
    }

    // MARK: - Bar and chart sizing

    @Test(
        "given a range and a surface, when sizing bars, then only the 7-day range gets wide ones",
        arguments: [
            (HistoryRange.week, HistoryCalorieTrendChartLayout.Surface.card, CGFloat(10)),
            (.twoWeeks, .card, 6),
            (.month, .card, 6),
            (.quarter, .card, 6),
            (.week, .detail, 14),
            (.twoWeeks, .detail, 10),
            (.month, .detail, 10),
            (.quarter, .detail, 10)
        ]
    )
    func barWidthFollowsRangeAndSurface(
        range: HistoryRange,
        surface: HistoryCalorieTrendChartLayout.Surface,
        expected: CGFloat
    ) {
        let layout = HistoryCalorieTrendChartLayout(range: range, surface: surface, pointCount: 7)

        #expect(layout.barWidth == expected)
    }

    @Test("given the drill-down, when sizing the chart, then it is taller than the card's")
    func theDrillDownChartIsTallerThanTheCards() {
        let card = HistoryCalorieTrendChartLayout(range: .week, surface: .card, pointCount: 7)
        let detail = HistoryCalorieTrendChartLayout(range: .week, surface: .detail, pointCount: 7)

        #expect(card.chartHeight == 160)
        #expect(detail.chartHeight == 220)
    }

    @Test("given a longer range, when sizing the chart, then it grows to fit the extra bars")
    func longerRangesGetATallerChart() {
        let week = HistoryCalorieTrendChartLayout(range: .week, surface: .detail, pointCount: 7)
        let quarter = HistoryCalorieTrendChartLayout(range: .quarter, surface: .detail, pointCount: 13)

        #expect(week.chartHeight == 220)
        #expect(quarter.chartHeight == 240)
    }

    @Test("given a point count, when scaling the x axis, then it matches the shared axis")
    func layoutDelegatesTheDomainToTheSharedAxis() {
        let layout = HistoryCalorieTrendChartLayout(range: .month, surface: .detail, pointCount: 30)

        #expect(layout.xAxisDomain == -0.5 ... 29.5)
        #expect(layout.hitTargetWidth(plotWidth: 300) == HistoryChartIndexAxis.minimumHitTargetWidth)
    }

    // MARK: - Selection

    @Test("given a tap that resolved to no chart value, when selecting, then nothing is selected")
    func aTapWithNoChartValueSelectsNothing() {
        let layout = HistoryCalorieTrendChartLayout(range: .week, surface: .detail, pointCount: 7)

        #expect(layout.selectedSlot(chartValue: nil) == nil)
    }

    @Test("given a tap between two bars, when selecting, then the nearer bar wins")
    func aTapBetweenBarsPicksTheNearerOne() {
        let layout = HistoryCalorieTrendChartLayout(range: .week, surface: .detail, pointCount: 7)

        #expect(layout.selectedSlot(chartValue: 3.4) == 3)
        #expect(layout.selectedSlot(chartValue: 3.6) == 4)
    }

    // MARK: - Emphasis

    @Test("given no selection, when drawing a bar, then every bar reads at full strength")
    func noSelectionLeavesEveryBarNormal() {
        #expect(
            HistoryCalorieTrendChartLayout.barEmphasis(pointID: "day-1", selectedPointID: nil) == .normal
        )
    }

    @Test("given a selection, when drawing the selected bar, then it is emphasised")
    func theSelectedBarIsEmphasised() {
        #expect(
            HistoryCalorieTrendChartLayout.barEmphasis(pointID: "day-1", selectedPointID: "day-1") == .selected
        )
    }

    @Test("given a selection, when drawing every other bar, then they recede")
    func unselectedBarsRecede() {
        #expect(
            HistoryCalorieTrendChartLayout.barEmphasis(pointID: "day-2", selectedPointID: "day-1") == .muted
        )
    }
}
