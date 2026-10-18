import Foundation
import Testing
@testable import Caloryn

@Suite("History overview summary")
struct HistoryOverviewSummaryTests {
    @Test("given logged days, when stating the average, then it is whole kcal a day")
    func theHeadlineIsTheRoundedDailyAverage() {
        let summary = makeSummary(averageCaloriesPerLoggedDay: 1_952.6)

        #expect(summary.hasLoggedDays)
        #expect(summary.averageValueText == 1_953.formatted())
        #expect(summary.averageUnitText == "kcal a day")
    }

    @Test("given an average under the goal, when supporting it, then the gap and the coverage are stated")
    func underTheGoalStatesTheGapAndCoverage() {
        let summary = makeSummary(
            loggedDayCount: 6,
            totalDayCount: 7,
            averageCaloriesPerLoggedDay: 1_953,
            averageTargetPerLoggedDay: 2_000
        )

        #expect(summary.supportText == "47 under your \(2_000.formatted()) goal, 6 of 7 days logged")
    }

    @Test("given an average over the goal, when supporting it, then the overshoot is stated")
    func overTheGoalStatesTheOvershoot() {
        let summary = makeSummary(averageCaloriesPerLoggedDay: 2_133, averageTargetPerLoggedDay: 2_000)

        #expect(summary.supportText.hasPrefix("133 over your \(2_000.formatted()) goal"))
    }

    @Test("given an average that rounds to the goal, when supporting it, then it reads as right on it")
    func onTheGoalReadsAsRightOnIt() {
        let summary = makeSummary(averageCaloriesPerLoggedDay: 2_000.4, averageTargetPerLoggedDay: 2_000)

        #expect(summary.supportText.hasPrefix("Right on your \(2_000.formatted()) goal"))
    }

    @Test("given nothing logged, when heading the page, then it says so instead of a zero average")
    func anEmptyRangeHasNoAverage() {
        let summary = makeSummary(loggedDayCount: 0, totalDayCount: 30, averageCaloriesPerLoggedDay: 0)

        #expect(summary.hasLoggedDays == false)
        #expect(summary.emptyHeadlineText == "Nothing logged")
        #expect(summary.supportText == "No days logged in the last 30 days.")
        #expect(summary.accessibilityLabel == "Nothing logged. No days logged in the last 30 days.")
    }

    @Test("given logged days, when spoken, then the headline and its support are one sentence")
    func theHeadlineIsSpokenWithItsSupport() {
        let summary = makeSummary(
            loggedDayCount: 6,
            totalDayCount: 7,
            averageCaloriesPerLoggedDay: 1_953,
            averageTargetPerLoggedDay: 2_000
        )

        #expect(summary.accessibilityLabel.hasPrefix("\(1_953.formatted()) kcal a day on average. 47 under"))
    }

    @Test(
        "given the change from the period before, when comparing, then small counts read as words",
        arguments: [
            (1, "one more than last week"),
            (-1, "one fewer than last week"),
            (0, "the same as last week"),
            (-12, "12 fewer than last week")
        ]
    )
    func theComparisonReadsAsWords(delta: Int, expected: String) {
        let summary = makeSummary(loggedDayCount: 6, onTrackDayDelta: delta)

        #expect(summary.onTrackSupportText == "of 6 logged days, \(expected)")
    }

    @Test(
        "given each range, when naming the period before, then it matches the range's length",
        arguments: [
            (HistoryRange.week, "last week"),
            (.twoWeeks, "the two weeks before"),
            (.month, "the 30 days before"),
            (.quarter, "the 90 days before")
        ]
    )
    func thePreviousPeriodMatchesTheRange(range: HistoryRange, expected: String) {
        let summary = makeSummary(range: range, onTrackDayDelta: 0)

        #expect(summary.onTrackSupportText.hasSuffix(expected))
    }

    @Test("given a single logged day, when counting, then the day is singular")
    func aSingleLoggedDayIsSingular() {
        let summary = makeSummary(loggedDayCount: 1, onTrackLoggedDayCount: 1, onTrackDayDelta: 1)

        #expect(summary.onTrackValueText == "1")
        #expect(summary.onTrackSupportText == "of 1 logged day, one more than last week")
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
        range: HistoryRange = .week,
        loggedDayCount: Int = 6,
        totalDayCount: Int = 7,
        averageCaloriesPerLoggedDay: Double = 2_000,
        averageTargetPerLoggedDay: Int = 2_000,
        onTrackLoggedDayCount: Int = 4,
        onTrackDayDelta: Int = 0
    ) -> HistoryOverviewSummary {
        HistoryOverviewSummary(
            range: range,
            loggedDayCount: loggedDayCount,
            totalDayCount: totalDayCount,
            averageCaloriesPerLoggedDay: averageCaloriesPerLoggedDay,
            averageTargetPerLoggedDay: averageTargetPerLoggedDay,
            onTrackLoggedDayCount: onTrackLoggedDayCount,
            onTrackDayDelta: onTrackDayDelta
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
