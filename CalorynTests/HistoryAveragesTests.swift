import Foundation
import Testing
@testable import Caloryn

@MainActor
@Suite("History averages")
struct HistoryAveragesTests {
    @Test("given only seven days, when averaging by week, then there is nothing beyond the headline average to show")
    func aSingleWeekIsNotShown() {
        let averages = makeAverages(dayCount: 7)

        #expect(averages.isEmpty)
        #expect(averages.groupings.isEmpty)
    }

    @Test("given fourteen logged days, when averaging by week, then the newest block is the last seven days and the older one is named by its dates")
    func twoWeeksAreTwoBlocks() {
        let averages = makeAverages(dayCount: 14) { offset in offset < 7 ? 1_800 : 2_200 }

        let periods = averages.series(for: .week).periods

        #expect(averages.groupings == [.week])
        #expect(periods.map(\.title) == ["Last 7 days", "26 Oct – 1 Nov"])
        #expect(periods.map(\.roundedAverage) == [2_200, 1_800])
    }

    @Test("given thirty days, when averaging by week, then four full weeks lead and the two oldest days form a short block that says so")
    func thirtyDaysEndInAShortBlock() {
        let periods = makeAverages(dayCount: 30).series(for: .week).periods

        #expect(periods.count == 5)
        #expect(periods.first?.title == "Last 7 days")
        #expect(periods.last?.title == "10 – 11 Oct (2 days)")
    }

    @Test("given thirty days, when choosing groupings, then monthly is not offered because it would be one block")
    func thirtyDaysOfferOnlyWeekly() {
        let averages = makeAverages(dayCount: 30)

        #expect(averages.groupings == [.week])
        #expect(averages.resolved(.month) == .week)
        #expect(averages.series(for: .month) == averages.series(for: .week))
    }

    @Test("given ninety days logged throughout, when choosing groupings, then monthly is three thirty-day blocks")
    func ninetyDaysOfferMonthly() {
        let averages = makeAverages(dayCount: 90)

        let months = averages.series(for: .month).periods

        #expect(averages.groupings == [.week, .month])
        #expect(averages.resolved(.month) == .month)
        #expect(months.map(\.title) == ["Last 30 days", "10 Sep – 9 Oct", "11 Aug – 9 Sep"])
        #expect(averages.series(for: .week).periods.count == 13)
    }

    @Test("given weeks with nothing logged, when listing averages, then those weeks are left out")
    func emptyBlocksAreHidden() {
        let averages = makeAverages(dayCount: 30) { offset in offset >= 16 ? 2_000 : nil }

        let titles = averages.series(for: .week).periods.map(\.title)

        #expect(titles == ["Last 7 days", "26 Oct – 1 Nov"])
    }

    @Test("given only one block with anything logged, when listing averages, then the section has nothing to add")
    func aSingleLoggedBlockIsNotShown() {
        let averages = makeAverages(dayCount: 30) { offset in offset >= 25 ? 2_000 : nil }

        #expect(averages.isEmpty)
    }

    @Test("given a week with some days unlogged, when averaging it, then only logged days count")
    func unloggedDaysDoNotDilute() {
        let averages = makeAverages(dayCount: 14) { offset in
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
        let period = makeAverages(dayCount: 14) { _ in calories }.series(for: .week).periods[0]

        #expect(period.gapText == expected)
    }

    @Test("given a large gap, when captioning it, then the number is grouped")
    func largeGapsAreGrouped() {
        let period = makeAverages(dayCount: 14) { _ in 700 }.series(for: .week).periods[0]

        #expect(period.gapText == "\(1_300.formatted()) under goal")
        #expect(period.valueText == "700")
    }

    @Test("given goals that change within a block, when averaging it, then the goal is the mean of its logged days' goals")
    func theGoalFollowsTheLoggedDays() {
        let averages = makeAverages(
            dayCount: 14,
            calories: { offset in offset == 13 ? nil : 2_000 },
            target: { offset in offset < 10 ? 2_000 : 2_300 }
        )

        let newest = averages.series(for: .week).periods[0]

        #expect(newest.target == 2_150)
    }

    @Test("given a block over goal and one under, when drawing bars, then both share one scale and the goal sits where it belongs")
    func barsShareOneScale() {
        let series = makeAverages(dayCount: 14) { offset in offset < 7 ? 1_000 : 2_500 }.series(for: .week)
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
        let averages = makeAverages(dayCount: 14, endingOn: (2027, 1, 10))

        #expect(averages.series(for: .week).periods.map(\.title) == ["Last 7 days", "28 Dec 2026 – 3 Jan 2027"])
    }

    @Test("given a logged block, when spoken, then it reads the title, the average and the gap to the goal")
    func aBlockIsSpokenInFull() {
        let period = makeAverages(dayCount: 14) { _ in 1_800 }.series(for: .week).periods[0]

        #expect(
            period.accessibilityLabel
                == "Last 7 days, \(1_800.formatted()) kcal a day on average, 200 under goal of \(2_000.formatted())"
        )
    }

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        calendar.locale = Locale(identifier: "en_GB")
        return calendar
    }()

    private func makeAverages(
        dayCount: Int,
        endingOn end: (Int, Int, Int) = (2026, 11, 8),
        calories: (Int) -> Double? = { _ in 2_000 },
        target: (Int) -> Int = { _ in 2_000 }
    ) -> HistoryAverages {
        let calendar = Self.calendar
        let lastDay = calendar.date(from: DateComponents(year: end.0, month: end.1, day: end.2)) ?? .now
        let days = (0..<dayCount).map { offset in
            let date = calendar.date(byAdding: .day, value: offset - (dayCount - 1), to: lastDay) ?? lastDay
            let value = calories(offset)
            return HistoryAverages.Day(
                date: date,
                calories: value ?? 0,
                target: target(offset),
                isLogged: value != nil
            )
        }
        return HistoryAverages(days: days, calendar: calendar)
    }
}
