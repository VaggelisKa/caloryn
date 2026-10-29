import Foundation
import Testing
@testable import Caloryn

@Suite("History overview summary")
struct HistoryOverviewSummaryTests {
    @Test("given logged days, when stating the average, then it is whole kcal a day on average")
    func theHeadlineIsTheRoundedDailyAverage() {
        let summary = makeSummary(averageCaloriesPerLoggedDay: 1_952.6)

        #expect(summary.hasLoggedDays)
        #expect(summary.averageValueText == 1_953.formatted())
        #expect(summary.averageUnitText == "kcal / day on average")
    }

    @Test("given an average over the goal, when supporting it, then only the overshoot against the goal is stated")
    func overTheGoalStatesTheOvershoot() {
        let summary = makeSummary(
            loggedDayCount: 29,
            totalDayCount: 30,
            averageCaloriesPerLoggedDay: 2_110,
            averageTargetPerLoggedDay: 2_000
        )

        #expect(summary.supportText == "110 over your \(2_000.formatted()) goal")
        #expect(summary.goalGap == .init(emphasis: "110 over", remainder: " your \(2_000.formatted()) goal"))
    }

    @Test("given an average under the goal, when supporting it, then only the gap to the goal is stated")
    func underTheGoalStatesTheGap() {
        let summary = makeSummary(averageCaloriesPerLoggedDay: 1_800, averageTargetPerLoggedDay: 2_000)

        #expect(summary.supportText == "200 under your \(2_000.formatted()) goal")
        #expect(summary.goalGap?.emphasis == "200 under")
    }

    @Test("given an average that rounds to the goal, when supporting it, then it reads as right on it")
    func onTheGoalReadsAsRightOnIt() {
        let summary = makeSummary(averageCaloriesPerLoggedDay: 2_000.4, averageTargetPerLoggedDay: 2_000)

        #expect(summary.supportText == "Right on your \(2_000.formatted()) goal")
        #expect(summary.goalGap?.emphasis == "Right on")
    }

    @Test("given logged days, when stating coverage, then it counts logged days out of the range")
    func coverageCountsLoggedDaysOutOfTheRange() {
        #expect(makeSummary(loggedDayCount: 29, totalDayCount: 30).loggedDaysText == "29 of 30 days logged")
        #expect(makeSummary(loggedDayCount: 1, totalDayCount: 7).loggedDaysText == "1 of 7 days logged")
        #expect(makeSummary(loggedDayCount: 1, totalDayCount: 1).loggedDaysText == "1 of 1 day logged")
    }

    @Test("given nothing logged, when heading the page, then it says so instead of a zero average or a coverage count")
    func anEmptyRangeHasNoAverage() {
        let summary = makeSummary(loggedDayCount: 0, totalDayCount: 30, averageCaloriesPerLoggedDay: 0)

        #expect(summary.hasLoggedDays == false)
        #expect(summary.emptyHeadlineText == "Nothing logged")
        #expect(summary.goalGap == nil)
        #expect(summary.loggedDaysText == nil)
        #expect(summary.supportText == "No days logged in the last 30 days.")
        #expect(summary.accessibilityLabel == "Nothing logged. No days logged in the last 30 days.")
    }

    @Test("given logged days, when spoken, then the headline and its support are one sentence")
    func theHeadlineIsSpokenWithItsSupport() {
        let summary = makeSummary(averageCaloriesPerLoggedDay: 2_110, averageTargetPerLoggedDay: 2_000)

        #expect(
            summary.accessibilityLabel
                == "\(2_110.formatted()) kcal a day on average. 110 over your \(2_000.formatted()) goal."
        )
    }

    @Test("given logged days by status, when breaking them down, then on track, over and under are counted in that order")
    func loggedDaysAreBrokenDownByStatus() {
        let breakdown = makeSummary(onTrackDayCount: 25, overDayCount: 4, underDayCount: 0).loggedDays

        #expect(breakdown.title == "Logged days")
        #expect(breakdown.columns.map(\.valueText) == ["25", "4", "0"])
        #expect(breakdown.columns.map(\.label) == ["on track", "over", "under"])
        #expect(breakdown.accessibilityLabel == "Logged days: 25 on track, 4 over, 0 under")
    }

    @Test("given logged days by status, when drawing the bar, then each status with days takes its share")
    func theBarSplitsByShare() {
        let breakdown = makeSummary(onTrackDayCount: 25, overDayCount: 4, underDayCount: 0).loggedDays

        #expect(breakdown.barSegments.map(\.status) == [.onTrack, .over])
        #expect(breakdown.barSegments.map { breakdown.share(of: $0) } == [25.0 / 29.0, 4.0 / 29.0])
    }

    @Test("given the range chips, when titling them, then only the first carries the unit")
    func onlyTheFirstChipCarriesTheUnit() {
        #expect(HistoryRange.allCases.map(\.chipTitle) == ["7 days", "14", "30", "90"])
    }

    @Test("given a macro, when describing its row, then the average and the hit count are stated")
    func aMacroRowStatesAverageAndHits() {
        let row = makeMacroRow(goalKind: .minimum, averageGrams: 123.6, hitDays: 3, loggedDays: 6)

        #expect(row.detailText == "124 g a day, hit 3 of 6")
        #expect(row.hitRatio == 0.5)
    }

    @Test(
        "given each goal kind, when naming a met day, then the word matches the goal",
        arguments: [
            (NutrientGoalKind.minimum, "hit"),
            (.target, "on target"),
            (.maximum, "under max")
        ]
    )
    func theHitWordMatchesTheGoalKind(goalKind: NutrientGoalKind, expected: String) {
        let row = makeMacroRow(goalKind: goalKind, hitDays: 2, loggedDays: 4)

        #expect(row.detailText.hasSuffix("\(expected) 2 of 4"))
    }

    @Test("given nothing logged, when filling the bar, then it stays empty rather than dividing by zero")
    func anEmptyMacroRowHasAnEmptyBar() {
        #expect(makeMacroRow(hitDays: 0, loggedDays: 0).hitRatio == 0)
    }

    @Test(
        "given the period before, when comparing the average, then the change is in whole grams against that period",
        arguments: [
            (HistoryRange.week, 12.4, "12 g more than last week"),
            (.twoWeeks, -8.6, "9 g less than the two weeks before"),
            (.month, 0.4, "Same as the 30 days before"),
            (.quarter, -0.4, "Same as the 90 days before")
        ]
    )
    func theMacroChangeIsAgainstThePeriodBefore(range: HistoryRange, change: Double, expected: String) {
        let row = makeMacroRow(hitDays: 3, loggedDays: 6, range: range, averageGramsChange: change)

        #expect(row.changeText == expected)
    }

    @Test("given nothing logged in the period before, when comparing the average, then no change is shown")
    func noPreviousPeriodMeansNoChange() {
        let row = makeMacroRow(hitDays: 3, loggedDays: 6, averageGramsChange: nil)

        #expect(row.changeText == nil)
        #expect(row.accessibilityLabel == "Protein, 80 grams a day, hit on 3 of 6 logged days")
    }

    @Test("given a change, when spoken, then it follows the row in grams")
    func theMacroChangeIsSpoken() {
        let row = makeMacroRow(hitDays: 3, loggedDays: 6, averageGramsChange: 0)

        #expect(row.accessibilityLabel == "Protein, 80 grams a day, hit on 3 of 6 logged days, same as last week")
        #expect(
            makeMacroRow(hitDays: 3, loggedDays: 6, averageGramsChange: -5).accessibilityLabel
                == "Protein, 80 grams a day, hit on 3 of 6 logged days, 5 grams less than last week"
        )
    }

    private func makeSummary(
        loggedDayCount: Int = 6,
        totalDayCount: Int = 7,
        averageCaloriesPerLoggedDay: Double = 2_000,
        averageTargetPerLoggedDay: Int = 2_000,
        onTrackDayCount: Int = 4,
        overDayCount: Int = 1,
        underDayCount: Int = 1
    ) -> HistoryOverviewSummary {
        HistoryOverviewSummary(
            loggedDayCount: loggedDayCount,
            totalDayCount: totalDayCount,
            averageCaloriesPerLoggedDay: averageCaloriesPerLoggedDay,
            averageTargetPerLoggedDay: averageTargetPerLoggedDay,
            onTrackDayCount: onTrackDayCount,
            overDayCount: overDayCount,
            underDayCount: underDayCount
        )
    }

    private func makeMacroRow(
        goalKind: NutrientGoalKind = .minimum,
        averageGrams: Double = 80,
        hitDays: Int,
        loggedDays: Int,
        range: HistoryRange = .week,
        averageGramsChange: Double? = nil
    ) -> HistoryMacroRowSummary {
        HistoryMacroRowSummary(
            id: "protein",
            name: "Protein",
            goalKind: goalKind,
            averageGrams: averageGrams,
            hitDays: hitDays,
            loggedDays: loggedDays,
            range: range,
            averageGramsChange: averageGramsChange
        )
    }
}
