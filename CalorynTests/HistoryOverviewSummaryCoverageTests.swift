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
        "given a change of exactly half a gram, when comparing, then it rounds away from zero to a whole gram",
        arguments: [
            (0.5, "1 g more than last week"),
            (-0.5, "1 g less than last week"),
            (0.49, nil)
        ] as [(Double, String?)]
    )
    func halfGramChangesRoundAwayFromZero(change: Double, expected: String?) {
        let row = makeMacroRow(hitDays: 2, loggedDays: 4, averageGramsChange: change)

        #expect(row.changeText == expected)
    }

    private func makeSummary(
        loggedDayCount: Int = 6,
        totalDayCount: Int = 7,
        averageCaloriesPerLoggedDay: Double = 2_000,
        averageTargetPerLoggedDay: Int = 2_000
    ) -> HistoryOverviewSummary {
        HistoryOverviewSummary(
            loggedDayCount: loggedDayCount,
            totalDayCount: totalDayCount,
            averageCaloriesPerLoggedDay: averageCaloriesPerLoggedDay,
            averageTargetPerLoggedDay: averageTargetPerLoggedDay
        )
    }

    private func makeMacroRow(hitDays: Int, loggedDays: Int, averageGramsChange: Double?) -> HistoryMacroRowSummary {
        HistoryMacroRowSummary(
            id: "protein",
            name: "Protein",
            goalKind: .minimum,
            averageGrams: 80,
            goalGrams: 150,
            hitDays: hitDays,
            loggedDays: loggedDays,
            range: .week,
            averageGramsChange: averageGramsChange
        )
    }
}
