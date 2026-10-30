import Foundation
import Testing
@testable import Caloryn

@Suite("History calorie trend card summary")
@MainActor
struct HistoryCalorieTrendCardSummaryTests {
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
                == "Calorie trend for 7 Days. 0 of 7 days logged. Goal \(2_000.formatted()) calories."
        )
    }

    @Test("given logged days, when describing the chart, then the average per logged day is spoken against the goal")
    func aLoggedRangeSpeaksItsAverage() {
        let summary = makeSummary(
            dailyCalorieTarget: 2_000,
            totalDayCount: 7,
            loggedDayCount: 5,
            averageCaloriesPerLoggedDay: 1_899.6
        )

        #expect(
            summary.chartAccessibilityLabel
                == "Calorie trend for 7 Days. 5 of 7 days logged. Average \(1_900.formatted()) calories per logged day. Goal \(2_000.formatted()) calories."
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

    @Test(
        "given a logged total, when supporting the section title, then an unsigned amount and a direction tell its distance from the same days' goals",
        arguments: [
            (15_200.0, 12_000, "\(3_200.formatted()) kcal", " over goal in total"),
            (10_800.0, 12_000, "\(1_200.formatted()) kcal", " under goal in total"),
            (12_000.4, 12_000, "Right on goal", " in total")
        ]
    )
    func theSupportLineTellsTheDistanceFromGoal(total: Double, goals: Int, emphasis: String, remainder: String) {
        let support = makeSummary(totalCalories: total, loggedDayTargetTotal: goals).totalSupport

        #expect(support?.emphasis == emphasis)
        #expect(support?.remainder == remainder)
        #expect(support?.text == emphasis + remainder)
    }

    @Test("given a large logged total, when supporting the section title, then the total itself is not repeated")
    func theSupportLineDropsTheCumulativeTotal() {
        let support = makeSummary(totalCalories: 61_200, loggedDayTargetTotal: 58_000).totalSupport

        #expect(support?.text == "\(3_200.formatted()) kcal over goal in total")
        #expect(support?.text.contains(61_200.formatted()) == false)
    }

    @Test("given nothing logged, when supporting the section title, then there is no line")
    func anEmptyRangeHasNoSupportLine() {
        #expect(makeSummary(loggedDayCount: 0, hasLoggedData: false).totalSupport == nil)
    }

    private func makeSummary(
        range: HistoryRange = .week,
        dailyCalorieTarget: Int = 2_000,
        totalDayCount: Int = 7,
        loggedDayCount: Int = 5,
        hasLoggedData: Bool = true,
        averageCaloriesPerLoggedDay: Double = 2_000,
        totalCalories: Double = 10_000,
        loggedDayTargetTotal: Int = 10_000
    ) -> HistoryCalorieTrendCardSummary {
        HistoryCalorieTrendCardSummary(
            range: range,
            dailyCalorieTarget: dailyCalorieTarget,
            totalDayCount: totalDayCount,
            loggedDayCount: loggedDayCount,
            hasLoggedData: hasLoggedData,
            averageCaloriesPerLoggedDay: averageCaloriesPerLoggedDay,
            totalCalories: totalCalories,
            loggedDayTargetTotal: loggedDayTargetTotal
        )
    }
}
