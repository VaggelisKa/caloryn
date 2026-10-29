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

    @Test("given a single day in one status, when breaking logged days down, then that status fills the whole bar")
    func aSingleStatusFillsTheBar() {
        let breakdown = makeSummary(loggedDayCount: 1, onTrackDayCount: 0, overDayCount: 0, underDayCount: 1).loggedDays

        #expect(breakdown.accessibilityLabel == "Logged days: 0 on track, 0 over, 1 under")
        #expect(breakdown.barSegments.map(\.status) == [.under])
        #expect(breakdown.barSegments.map { breakdown.share(of: $0) } == [1])
    }

    @Test("given no days in any status, when drawing the bar, then it is an empty track rather than dividing by zero")
    func noLoggedDaysLeaveAnEmptyTrack() {
        let breakdown = makeSummary(loggedDayCount: 0, onTrackDayCount: 0, overDayCount: 0, underDayCount: 0).loggedDays

        #expect(breakdown.accessibilityLabel == "Logged days: 0 on track, 0 over, 0 under")
        #expect(breakdown.barSegments.isEmpty)
        #expect(breakdown.columns.allSatisfy { breakdown.share(of: $0) == 0 })
    }

    @Test("given a negative count, when breaking logged days down, then it counts as none")
    func aNegativeCountIsNone() {
        let breakdown = makeSummary(onTrackDayCount: 3, overDayCount: -2, underDayCount: 0).loggedDays

        #expect(breakdown.columns.map(\.count) == [3, 0, 0])
        #expect(breakdown.barSegments.map { breakdown.share(of: $0) } == [1])
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
        #expect(summary.supportText == "\(supportPrefix) \(2_000.formatted()) goal")
    }

    @Test("given a gap of a thousand or more, when supporting the average, then the gap is grouped like the goal")
    func largeGapsAreGrouped() {
        let summary = makeSummary(averageCaloriesPerLoggedDay: 3_250, averageTargetPerLoggedDay: 2_000)

        #expect(summary.supportText == "\(1_250.formatted()) over your \(2_000.formatted()) goal")
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
