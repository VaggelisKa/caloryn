import Foundation
import Testing
@testable import Caloryn

@MainActor
@Suite("History averages")
struct HistoryAveragesTests {
    @Test("given only seven days, when averaging by week, then there is nothing beyond the headline average to show")
    func aSingleWeekIsNotShown() {
        let averages = makeTestHistoryAverages(dayCount: 7)

        #expect(averages.isEmpty)
        #expect(averages.groupings.isEmpty)
    }

    @Test("given fourteen logged days, when averaging by week, then the newest block is the last seven days and the older one is named by its dates")
    func twoWeeksAreTwoBlocks() {
        let averages = makeTestHistoryAverages(dayCount: 14) { offset in offset < 7 ? 1_800 : 2_200 }

        let periods = averages.series(for: .week).periods

        #expect(averages.groupings == [.week])
        #expect(periods.map(\.title) == ["Last 7 days", "26 Oct – 1 Nov"])
        #expect(periods.map(\.roundedAverage) == [2_200, 1_800])
    }

    @Test("given thirty days, when averaging by week, then four full weeks lead and the two oldest days form a short block that says so")
    func thirtyDaysEndInAShortBlock() {
        let periods = makeTestHistoryAverages(dayCount: 30).series(for: .week).periods

        #expect(periods.count == 5)
        #expect(periods.first?.title == "Last 7 days")
        #expect(periods.last?.title == "10 – 11 Oct (2 days)")
    }

    @Test("given thirty days, when choosing groupings, then monthly is not offered because it would be one block")
    func thirtyDaysOfferOnlyWeekly() {
        let averages = makeTestHistoryAverages(dayCount: 30)

        #expect(averages.groupings == [.week])
        #expect(averages.resolved(.month) == .week)
        #expect(averages.series(for: .month) == averages.series(for: .week))
    }

    @Test("given ninety days logged throughout, when choosing groupings, then monthly is three thirty-day blocks")
    func ninetyDaysOfferMonthly() {
        let averages = makeTestHistoryAverages(dayCount: 90)

        let months = averages.series(for: .month).periods

        #expect(averages.groupings == [.week, .month])
        #expect(averages.resolved(.month) == .month)
        #expect(months.map(\.title) == ["Last 30 days", "10 Sep – 9 Oct", "11 Aug – 9 Sep"])
        #expect(averages.series(for: .week).periods.count == 13)
    }

    @Test("given weeks with nothing logged, when listing averages, then those weeks are left out")
    func emptyBlocksAreHidden() {
        let averages = makeTestHistoryAverages(dayCount: 30) { offset in offset >= 16 ? 2_000 : nil }

        let titles = averages.series(for: .week).periods.map(\.title)

        #expect(titles == ["Last 7 days", "26 Oct – 1 Nov"])
    }

    @Test("given only one block with anything logged, when listing averages, then the section has nothing to add")
    func aSingleLoggedBlockIsNotShown() {
        let averages = makeTestHistoryAverages(dayCount: 30) { offset in offset >= 25 ? 2_000 : nil }

        #expect(averages.isEmpty)
    }

    @Test("given a week with some days unlogged, when averaging it, then only logged days count")
    func unloggedDaysDoNotDilute() {
        let averages = makeTestHistoryAverages(dayCount: 14) { offset in
            switch offset {
            case 7, 8: 1_500
            case 9...13: nil
            default: 2_000
            }
        }

        let newest = averages.series(for: .week).periods[0]

        #expect(newest.loggedDayCount == 2)
        #expect(newest.roundedAverage == 1_500)
    }

    @Test(
        "given an average against its goal, when captioning it, then it states the gap to the rounded calorie",
        arguments: [
            (1_499.6, "500 under goal"),
            (2_000.4, "Right on goal"),
            (2_349.5, "350 over goal")
        ] as [(Double, String)]
    )
    func theGapIsStatedAgainstTheGoal(calories: Double, expected: String) {
        let period = makeTestHistoryAverages(dayCount: 14) { _ in calories }.series(for: .week).periods[0]

        #expect(period.gapText == expected)
    }

    @Test("given a large gap, when captioning it, then the number is grouped")
    func largeGapsAreGrouped() {
        let period = makeTestHistoryAverages(dayCount: 14) { _ in 700 }.series(for: .week).periods[0]

        #expect(period.gapText == "\(1_300.formatted()) under goal")
        #expect(period.valueText == "700")
    }

    @Test("given goals that change within a block, when averaging it, then the goal is the mean of its logged days' goals")
    func theGoalFollowsTheLoggedDays() {
        let averages = makeTestHistoryAverages(
            dayCount: 14,
            calories: { offset in offset == 13 ? nil : 2_000 },
            target: { offset in offset < 10 ? 2_000 : 2_300 }
        )

        let newest = averages.series(for: .week).periods[0]

        #expect(newest.target == 2_150)
    }

    @Test("given a block over goal and one under, when drawing bars, then both share one scale and the goal sits where it belongs")
    func barsShareOneScale() {
        let series = makeTestHistoryAverages(dayCount: 14) { offset in offset < 7 ? 1_000 : 2_500 }.series(for: .week)
        let over = series.periods[0]
        let under = series.periods[1]

        #expect(series.fillFraction(for: over) == 1)
        #expect(series.goalFraction(for: over) == 0.8)
        #expect(series.fillFraction(for: under) == 0.4)
        #expect(over.status == .over)
        #expect(under.status == .under)
    }

    @Test("given blocks across new year, when naming them, then both ends carry their year")
    func spansAcrossTheYearNameBothYears() {
        let averages = makeTestHistoryAverages(dayCount: 14, endingOn: (2027, 1, 10))

        #expect(averages.series(for: .week).periods.map(\.title) == ["Last 7 days", "28 Dec 2026 – 3 Jan 2027"])
    }

    @Test(
        "given a logged block, when spoken, then it reads the title, the average and its gap to the named goal",
        arguments: [
            (1_800.0, "200 under your"),
            (2_000.0, "Right on your"),
            (2_150.0, "150 over your")
        ] as [(Double, String)]
    )
    func aBlockIsSpokenInFull(calories: Double, gap: String) {
        let period = makeTestHistoryAverages(dayCount: 14) { _ in calories }.series(for: .week).periods[0]

        #expect(
            period.accessibilityLabel
                == "Last 7 days, \(period.valueText) kcal a day on average, \(gap) \(2_000.formatted()) kcal goal"
        )
    }

    @Test(
        "given averages either side of the rounded edge of the on-track band, when tinting them, then the tint follows the number shown",
        arguments: [2_099.6, 2_100.4]
    )
    func theTintFollowsTheRoundedAverage(calories: Double) {
        let period = makeTestHistoryAverages(dayCount: 14) { _ in calories }.series(for: .week).periods[0]

        #expect(period.gapText == "100 over goal")
        #expect(period.status == .onTrack)
    }

    @Test("given fifteen days, when averaging by week, then the oldest single day is its own block named by that day")
    func aSingleDayBlockIsNamedByItsDay() {
        let titles = makeTestHistoryAverages(dayCount: 15).series(for: .week).periods.map(\.title)

        #expect(titles == ["Last 7 days", "26 Oct – 1 Nov", "25 Oct (1 day)"])
    }

    @Test("given seventy-five days, when averaging by month, then the oldest block holds the fifteen days left over")
    func aShortOldestMonthSaysHowManyDays() {
        let titles = makeTestHistoryAverages(dayCount: 75).series(for: .month).periods.map(\.title)

        #expect(titles == ["Last 30 days", "10 Sep – 9 Oct", "26 Aug – 9 Sep (15 days)"])
    }

    @Test("given a period summary, when averaging it, then each day's calories, goal and logged state carry over")
    func aPeriodSummaryCarriesItsDays() {
        let calendar = makeTestHistoryAveragesCalendar()
        let lastDay = calendar.date(from: DateComponents(year: 2026, month: 11, day: 8, hour: 12)) ?? .now
        let dates = (0..<14).map { calendar.date(byAdding: .day, value: $0 - 13, to: lastDay) ?? lastDay }
        let entries = dates.enumerated().compactMap { offset, date -> FoodLogEntry? in
            guard offset != 13 else { return nil }
            let entry = makeTestEntry(
                date: date,
                foodItem: makeTestFoodItem(caloriesPer100g: offset < 7 ? 1_600 : 2_400),
                portionGrams: 100
            )
            entry.date = date
            return entry
        }
        let summary = HistoryPeriodSummary(
            dates: dates.map { calendar.startOfDay(for: $0) },
            entriesByDate: Dictionary(grouping: entries) { calendar.startOfDay(for: $0.date) },
            targetResolver: HistoryDayTargetResolver(fallbackTarget: 2_200),
            calendar: calendar
        )

        let periods = HistoryAverages(summary: summary).series(for: .week).periods

        #expect(periods.map(\.title) == ["Last 7 days", "26 Oct – 1 Nov"])
        #expect(periods.map(\.loggedDayCount) == [6, 7])
        #expect(periods.map(\.roundedAverage) == [2_400, 1_600])
        #expect(periods.map(\.target) == [2_200, 2_200])
    }
}
