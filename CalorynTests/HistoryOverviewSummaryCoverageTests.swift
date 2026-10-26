import Foundation
import Testing
@testable import Caloryn

@MainActor
@Suite("History overview summary coverage")
struct HistoryOverviewSummaryCoverageTests {
    @Test("given logged days, when speaking the headline alone, then it is the rounded average a day")
    func theHeadlineIsSpokenAsAnAverage() {
        let summary = makeSummary(averageCaloriesPerLoggedDay: 1_952.6)

        #expect(summary.averageAccessibilityLabel == "\(1_953.formatted()) kcal a day on average")
    }

    @Test("given nothing logged, when speaking the headline alone, then it says nothing was logged rather than a zero average")
    func anEmptyHeadlineIsSpokenAsNothingLogged() {
        let summary = makeSummary(loggedDayCount: 0, averageCaloriesPerLoggedDay: 0)

        #expect(summary.averageAccessibilityLabel == "Nothing logged")
    }

    @Test("given the on-track count, when spoken, then the count, its support and the comparison form one sentence")
    func theOnTrackCountIsSpoken() {
        let summary = makeSummary(loggedDayCount: 6, onTrackLoggedDayCount: 4, onTrackDayDelta: 2)

        #expect(summary.onTrackAccessibilityLabel == "On track: 4 of 6 logged days, two more than last week.")
    }

    @Test("given nothing logged, when the on-track count is spoken, then it is zero of zero days and the same as before")
    func anEmptyOnTrackCountIsSpoken() {
        let summary = makeSummary(
            range: .month,
            loggedDayCount: 0,
            averageCaloriesPerLoggedDay: 0,
            onTrackLoggedDayCount: 0,
            onTrackDayDelta: 0
        )

        #expect(summary.onTrackValueText == "0")
        #expect(summary.onTrackAccessibilityLabel == "On track: 0 of 0 logged days, the same as the 30 days before.")
    }

    @Test(
        "given an average with a half calorie, when stating it, then the headline and the difference round the same way",
        arguments: [
            (1_952.5, 1_953, "47 under your"),
            (1_999.5, 2_000, "Right on your"),
            (2_000.49, 2_000, "Right on your"),
            (2_047.5, 2_048, "48 over your")
        ] as [(Double, Int, String)]
    )
    func halfCaloriesRoundConsistently(average: Double, headline: Int, supportPrefix: String) {
        let summary = makeSummary(averageCaloriesPerLoggedDay: average, averageTargetPerLoggedDay: 2_000)

        #expect(summary.averageValueText == headline.formatted())
        #expect(summary.supportText.hasPrefix(supportPrefix))
    }

    @Test(
        "given a count, when wording it, then zero to nine are words and ten upwards are figures",
        arguments: [
            (0, "zero"),
            (1, "one"),
            (2, "two"),
            (3, "three"),
            (4, "four"),
            (5, "five"),
            (6, "six"),
            (7, "seven"),
            (8, "eight"),
            (9, "nine"),
            (10, "10"),
            (90, "90")
        ] as [(Int, String)]
    )
    func smallCountsAreWords(count: Int, expected: String) {
        #expect(HistoryOverviewSummary.countWord(count) == expected)
    }

    @Test("given a negative count, when wording it, then it is a figure rather than an out-of-range word")
    func aNegativeCountIsAFigure() {
        #expect(HistoryOverviewSummary.countWord(-3) == (-3).formatted())
    }

    @Test(
        "given the change in on-track days, when comparing with the two weeks before, then the boundary between words and figures holds",
        arguments: [
            (9, "nine more than the two weeks before"),
            (10, "10 more than the two weeks before"),
            (-9, "nine fewer than the two weeks before"),
            (-10, "10 fewer than the two weeks before")
        ] as [(Int, String)]
    )
    func theComparisonSwitchesToFiguresAtTen(delta: Int, expected: String) {
        let summary = makeSummary(range: .twoWeeks, loggedDayCount: 12, onTrackDayDelta: delta)

        #expect(summary.onTrackSupportText == "of 12 logged days, \(expected)")
    }

    @Test(
        "given each status, when badging it, then it reads in sentence case",
        arguments: [
            (HistoryGoalStatus.under, "Under"),
            (.onTrack, "On track"),
            (.over, "Over"),
            (.notLogged, "Not logged")
        ]
    )
    func statusSentenceLabels(status: HistoryGoalStatus, expected: String) {
        #expect(status.sentenceLabel == expected)
    }

    @Test(
        "given hit and logged counts out of step, when filling the bar, then the share stays between empty and full",
        arguments: [
            (5, 4, 1.0),
            (-1, 4, 0.0),
            (1, 4, 0.25)
        ] as [(Int, Int, Double)]
    )
    func theHitShareIsClamped(hitDays: Int, loggedDays: Int, expected: Double) {
        let row = makeMacroRow(hitDays: hitDays, loggedDays: loggedDays, averageGramsChange: nil)

        #expect(row.hitRatio == expected)
    }

    @Test(
        "given a change of exactly half a gram, when comparing, then it rounds away from zero to a whole gram",
        arguments: [
            (0.5, "1 g more than last week"),
            (-0.5, "1 g less than last week"),
            (0.49, "Same as last week")
        ] as [(Double, String)]
    )
    func halfGramChangesRoundAwayFromZero(change: Double, expected: String) {
        let row = makeMacroRow(hitDays: 2, loggedDays: 4, averageGramsChange: change)

        #expect(row.changeText == expected)
    }

    @Test(
        "given each meal, when building its breakdown row, then the row is keyed by the meal and carries its icon",
        arguments: [
            (MealType.breakfast, "breakfast", "sunrise.fill"),
            (.lunch, "lunch", "sun.max.fill"),
            (.dinner, "dinner", "moon.fill"),
            (.snack, "snack", "leaf.fill")
        ]
    )
    func mealRowIdentity(mealType: MealType, id: String, iconName: String) {
        let breakdown = HistoryCalorieTrendDayBreakdown(
            isLogged: true,
            calorieDifference: 0,
            dailyCalorieTarget: 2_000,
            mealCalories: [mealType: 420],
            foods: []
        )

        let row = breakdown.mealRows.first { $0.mealType == mealType }
        #expect(row?.id == id)
        #expect(row?.iconName == iconName)
        #expect(row?.caloriesText == "420 kcal")
        #expect(breakdown.mealRows.map(\.id) == ["breakfast", "lunch", "snack", "dinner"])
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

    private func makeMacroRow(hitDays: Int, loggedDays: Int, averageGramsChange: Double?) -> HistoryMacroRowSummary {
        HistoryMacroRowSummary(
            id: "protein",
            name: "Protein",
            goalKind: .minimum,
            averageGrams: 80,
            hitDays: hitDays,
            loggedDays: loggedDays,
            range: .week,
            averageGramsChange: averageGramsChange
        )
    }
}
