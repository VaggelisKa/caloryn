import Foundation
import Testing
@testable import Caloryn

/// The headline numbers above the calorie-trend chart: what the two stat
/// columns say, how they are toned, and how the chart describes itself when
/// there is nothing to describe.
@Suite("History calorie trend card summary")
struct HistoryCalorieTrendCardSummaryTests {

    // MARK: - Empty range

    @Test("given nothing logged, when laying out the card, then the stat columns are hidden rather than zeroed")
    func anEmptyRangeHidesTheStatColumns() {
        let summary = makeSummary(loggedDayCount: 0, hasLoggedData: false)

        #expect(summary.showsStatColumns == false)
        #expect(summary.averageDifferenceTone == .neutral)
        #expect(summary.totalDifferenceTone == .neutral)
    }

    @Test("given nothing logged, when describing the chart, then it says zero days rather than an average")
    func anEmptyRangeIsSpokenWithoutAnAverage() {
        let summary = makeSummary(
            dailyCalorieTarget: 2_000,
            totalDayCount: 7,
            loggedDayCount: 0,
            hasLoggedData: false
        )

        #expect(
            summary.chartAccessibilityLabel
                == "Calorie trend for 7 Days. 0 of 7 days logged. Target 2000 calories."
        )
    }

    @Test("given logged days, when describing the chart, then the average per logged day is spoken")
    func aLoggedRangeSpeaksItsAverage() {
        let summary = makeSummary(
            dailyCalorieTarget: 2_000,
            totalDayCount: 7,
            loggedDayCount: 5,
            averageCaloriesPerLoggedDay: 1_899.6
        )

        #expect(
            summary.chartAccessibilityLabel
                == "Calorie trend for 7 Days. 5 of 7 days logged. Average 1900 calories per logged day. Target 2000 calories."
        )
    }

    @Test("given the drill-down, when describing its chart, then only the coverage is spoken")
    func theDrillDownChartSpeaksOnlyItsCoverage() {
        #expect(
            HistoryCalorieTrendCardSummary.detailChartAccessibilityLabel(
                range: .quarter,
                loggedDayCount: 40,
                totalDayCount: 90
            ) == "Detailed calorie trend for 90 Days. 40 of 90 days logged."
        )
    }

    // MARK: - Stat values

    @Test("given fractional totals, when showing them, then they are rounded to whole calories")
    func statValuesAreRoundedForDisplay() {
        let summary = makeSummary(
            averageCaloriesPerLoggedDay: 949.6,
            totalCalories: 950.4
        )

        #expect(summary.averageValueText == "950")
        #expect(summary.totalValueText == "950")
    }

    @Test("given the on-track count, when showing it, then it is out of logged days, not calendar days")
    func theOnTrackRatioCountsLoggedDays() {
        let summary = makeSummary(
            totalDayCount: 30,
            loggedDayCount: 5,
            onTrackLoggedDayCount: 3
        )

        #expect(summary.onTrackRatioText == "3/5")
    }

    // MARK: - Tone

    @Test("given no target at all, when toning a difference, then there is nothing to compare against")
    func noTargetIsNeutral() {
        let summary = makeSummary(
            averageCaloriesPerLoggedDay: 1_800,
            averageTargetPerLoggedDay: 0,
            totalCalories: 9_000,
            loggedDayTargetTotal: 0
        )

        #expect(summary.averageDifferenceTone == .neutral)
        #expect(summary.totalDifferenceTone == .neutral)
    }

    @Test("given an average inside the tolerance band, when toning it, then it reads as on track")
    func anAverageInsideTheBandIsOnTrack() {
        let summary = makeSummary(
            averageCaloriesPerLoggedDay: 2_050,
            averageTargetPerLoggedDay: 2_000
        )

        #expect(summary.averageDifferenceTone == .status(.onTrack))
    }

    @Test("given an average well past the band, when toning it, then it reads as over")
    func anAverageWellPastTheBandIsOver() {
        let summary = makeSummary(
            averageCaloriesPerLoggedDay: 2_400,
            averageTargetPerLoggedDay: 2_000
        )

        #expect(summary.averageDifferenceTone == .status(.over))
    }

    @Test("given a total well short of the band, when toning it, then it reads as under")
    func aTotalWellShortOfTheBandIsUnder() {
        let summary = makeSummary(
            totalCalories: 8_000,
            loggedDayTargetTotal: 10_000
        )

        #expect(summary.totalDifferenceTone == .status(.under))
    }

    @Test("given a value that rounds onto the band edge, when toning it, then the displayed number decides")
    func theDisplayedNumberDecidesTheBand() {
        let onEdge = makeSummary(
            averageCaloriesPerLoggedDay: 2_100.4,
            averageTargetPerLoggedDay: 2_000
        )
        let pastEdge = makeSummary(
            averageCaloriesPerLoggedDay: 2_100.6,
            averageTargetPerLoggedDay: 2_000
        )

        #expect(onEdge.averageDifferenceTone == .status(.onTrack))
        #expect(pastEdge.averageDifferenceTone == .status(.over))
    }

    // MARK: - Helpers

    private func makeSummary(
        range: HistoryRange = .week,
        dailyCalorieTarget: Int = 2_000,
        totalDayCount: Int = 7,
        loggedDayCount: Int = 5,
        onTrackLoggedDayCount: Int = 3,
        hasLoggedData: Bool = true,
        averageCaloriesPerLoggedDay: Double = 2_000,
        averageTargetPerLoggedDay: Int = 2_000,
        totalCalories: Double = 10_000,
        loggedDayTargetTotal: Int = 10_000
    ) -> HistoryCalorieTrendCardSummary {
        HistoryCalorieTrendCardSummary(
            range: range,
            dailyCalorieTarget: dailyCalorieTarget,
            totalDayCount: totalDayCount,
            loggedDayCount: loggedDayCount,
            onTrackLoggedDayCount: onTrackLoggedDayCount,
            hasLoggedData: hasLoggedData,
            averageCaloriesPerLoggedDay: averageCaloriesPerLoggedDay,
            averageTargetPerLoggedDay: averageTargetPerLoggedDay,
            totalCalories: totalCalories,
            loggedDayTargetTotal: loggedDayTargetTotal
        )
    }
}
