import Foundation
import Testing
@testable import Caloryn

/// The calorie-trend projection and the consistency plate strip, built from analytics run in
/// an injected calendar whose zone crosses a daylight-saving change. Every label a reader sees
/// (axis initials, spoken dates, the biggest-swing line, week headings, plate labels) has to
/// come from the calendar the days were bucketed in, never from the host's.
@MainActor
@Suite("History trend calendar coverage")
struct HistoryTrendCalendarCoverageTests {

    // MARK: - Daily points

    @Test("given a week across the spring change, when projecting the trend, then axis initials and spoken dates follow the injected calendar")
    func dailyPointLabelsFollowTheCalendar() {
        let projection = HistoryCalorieTrendProjection(range: .week, summary: springWeek().current)

        #expect(projection.calendar == Self.newYork)
        #expect(projection.points.map(\.xAxisLabel) == ["W", "T", "F", "S", "S", "M", "T"])
        #expect(projection.points.map(\.accessibilityLabel) == [
            "Wed, 4 Mar", "Thu, 5 Mar", "Fri, 6 Mar", "Sat, 7 Mar", "Sun, 8 Mar", "Mon, 9 Mar", "Tue, 10 Mar"
        ])
        #expect(projection.points.map(\.index) == [0, 1, 2, 3, 4, 5, 6])
    }

    @Test("given days either side of the spring change, when identifying their points, then each is keyed by its own UTC midnight")
    func dailyPointIdsShiftWithTheOffset() {
        let projection = HistoryCalorieTrendProjection(range: .week, summary: springWeek().current)

        // Local midnight is 05:00 UTC in standard time and 04:00 UTC once the clocks go forward.
        #expect(projection.points[3].id == "day-2026-03-07T05:00:00Z")
        #expect(projection.points[4].id == "day-2026-03-08T05:00:00Z")
        #expect(projection.points[5].id == "day-2026-03-09T04:00:00Z")
    }

    @Test("given logged days across the spring change, when projecting the trend, then values, deltas and spoken values describe each local day")
    func dailyPointValuesDescribeLocalDays() {
        let projection = HistoryCalorieTrendProjection(range: .week, summary: springWeek().current)
        let sunday = projection.points[4]
        let monday = projection.points[5]

        #expect(sunday.isLogged)
        #expect(sunday.value == 2_600)
        #expect(sunday.targetDelta == 600)
        #expect(sunday.status == .over)
        #expect(sunday.accessibilityValue == "2600 calories, Over")
        #expect(monday.value == 1_950)
        #expect(monday.status == .onTrack)
        #expect(projection.points[0].accessibilityValue == "No calories logged")
        #expect(projection.loggedPointCount == 3)
        #expect(projection.totalCalories == 2_600 + 1_950 + 1_500)
    }

    @Test("given a swing on the short day, when naming the biggest swing, then the day is named in the injected calendar")
    func theBiggestSwingIsNamedInTheCalendar() {
        let projection = HistoryCalorieTrendProjection(range: .week, summary: springWeek().current)

        #expect(projection.biggestInconsistencyText == "Biggest swing: Sun, 8 Mar, 600 kcal over")
    }

    @Test("given an instant that is already the next day in UTC, when labelling it for the drill-down, then the injected calendar's day is used")
    func drillDownLabelsUseTheCalendar() {
        let projection = HistoryCalorieTrendProjection(range: .week, summary: springWeek().current)
        // 02:00 UTC on 9 March is still 22:00 on Sunday 8 March in New York.
        let instant = Date(timeIntervalSince1970: 1_773_021_600)

        #expect(projection.dayText(for: instant) == "Sun, 8 Mar")
        #expect(projection.weekStartText(for: instant) == "8 Mar")
    }

    // MARK: - Weekly points

    @Test("given a 90-day range across the spring change, when projecting the trend, then week points are labelled from the oldest and named by their Monday")
    func weeklyPointLabelsFollowTheCalendar() throws {
        let projection = HistoryCalorieTrendProjection(range: .quarter, summary: springQuarter().current)

        #expect(projection.points.count == 14)
        #expect(projection.points.map(\.xAxisLabel) == (1...14).map { "W\($0)" })
        #expect(projection.points.first?.accessibilityLabel == "W1, week of 26 Jan")
        let dstWeek = try #require(projection.points.first { $0.accessibilityLabel == "W7, week of 9 Mar" })
        #expect(dstWeek.id == "week-2026-03-09T04:00:00Z")
        #expect(dstWeek.isLogged)
        #expect(dstWeek.value == 2_400)
        #expect(dstWeek.targetDelta == 400)
        #expect(dstWeek.status == .over)
        #expect(dstWeek.accessibilityValue == "2400 average calories per logged day, Over")
    }

    @Test("given a 90-day range with one week far over, when naming the biggest swing, then that week is named by its Monday in the calendar")
    func theBiggestWeeklySwingIsNamedInTheCalendar() {
        let projection = HistoryCalorieTrendProjection(range: .quarter, summary: springQuarter().current)

        #expect(projection.biggestInconsistencyText == "Biggest swing: week of 9 Mar, 400 kcal/day over")
    }

    @Test("given the 90-day range, when comparing a value with the average, then the label names the 90-day average")
    func theQuarterAverageLabel() {
        let projection = HistoryCalorieTrendProjection(range: .quarter, summary: springQuarter().current)

        // Logged days: 2,400 on 9 and 10 March, 2,000 on 2 February: 2,266.67 on average.
        #expect(projection.averageDeltaText(value: 2_400, unit: "kcal") == "133 kcal above 90-day average")
        #expect(projection.averageDeltaText(value: 2_267, unit: "kcal") == "Matches 90-day average")
        // 266.67 below rounds to 267, where cutting the fraction off would say 266.
        #expect(projection.averageDeltaText(value: 2_000, unit: "kcal") == "267 kcal below 90-day average")
        // 0.83 above rounds to one, where cutting the fraction off would say it matches.
        #expect(projection.averageDeltaText(value: 2_267.5, unit: "kcal") == "1 kcal above 90-day average")
    }

    // MARK: - A zone whose midnight is the day before nearly everywhere

    // New York's midnight is the same calendar day in UTC and in Europe, so the labels above
    // would still read right if they were spelled from the host calendar on those hosts.
    // Auckland's midnight is the previous day from UTC-11 to UTC+11, so here they would not.

    @Test("given a week in Auckland across its autumn change, when labelling daily points, then initials, spoken dates and the biggest swing name Auckland's days")
    func dailyLabelsUseTheInjectedCalendarRatherThanTheHost() {
        let projection = HistoryCalorieTrendProjection(range: .week, summary: aucklandAutumnWeek().current)

        #expect(projection.points.map(\.xAxisLabel) == ["W", "T", "F", "S", "S", "M", "T"])
        #expect(projection.points.map(\.accessibilityLabel) == [
            "Wed, 1 Apr", "Thu, 2 Apr", "Fri, 3 Apr", "Sat, 4 Apr", "Sun, 5 Apr", "Mon, 6 Apr", "Tue, 7 Apr"
        ])
        // Midnight is 11:00 UTC the day before under daylight saving (UTC+13), 12:00 after it (UTC+12).
        #expect(projection.points[4].id == "day-2026-04-04T11:00:00Z")
        #expect(projection.points[5].id == "day-2026-04-05T12:00:00Z")
        #expect(projection.points[4].value == 2_600)
        #expect(projection.biggestInconsistencyText == "Biggest swing: Sun, 5 Apr, 600 kcal over")
    }

    @Test("given 7 and 30 days in Auckland, when laying out plates, then weekday and day-of-month labels are Auckland's")
    func plateLabelsUseTheInjectedCalendarRatherThanTheHost() {
        let week = HistoryDayPlateStrip(
            range: .week,
            summary: aucklandAutumnWeek().current,
            today: Self.aucklandDate(2026, 4, 7, hour: 23)
        )
        let month = HistoryDayPlateStrip(
            range: .month,
            summary: HistoryAnalytics(
                entries: [],
                profile: nil,
                range: .month,
                endDate: Self.aucklandDate(2026, 4, 20),
                calendar: Self.auckland
            ).current,
            today: Self.aucklandDate(2026, 4, 20, hour: 23)
        )

        #expect(week.plates.map(\.label) == ["Wed", "Thu", "Fri", "Sat", "Sun", "Mon", "Tue"])
        #expect(week.plates.map(\.outline) == [.standard, .standard, .standard, .standard, .over, .standard, .current])
        #expect(month.plates.map(\.label) == (22...31).map(String.init) + (1...20).map(String.init))
        #expect(month.plates.last?.outline == .current)
    }

    @Test("given 90 days in Auckland, when labelling week points, then each week is named by Auckland's Monday")
    func weekLabelsUseTheInjectedCalendarRatherThanTheHost() throws {
        let analytics = HistoryAnalytics(
            entries: [
                entry(at: Self.aucklandDate(2026, 2, 2), calories: 2_000),
                entry(at: Self.aucklandDate(2026, 3, 31), calories: 2_400),
                entry(at: Self.aucklandDate(2026, 4, 1), calories: 2_400)
            ],
            profile: Self.makeProfile(),
            range: .quarter,
            endDate: Self.aucklandDate(2026, 4, 30),
            calendar: Self.auckland
        )
        let projection = HistoryCalorieTrendProjection(range: .quarter, summary: analytics.current)

        #expect(projection.points.count == 14)
        #expect(projection.points.first?.accessibilityLabel == "W1, week of 26 Jan")
        let overWeek = try #require(projection.points.first { $0.accessibilityLabel == "W10, week of 30 Mar" })
        #expect(overWeek.id == "week-2026-03-29T11:00:00Z")
        #expect(overWeek.value == 2_400)
        #expect(projection.biggestInconsistencyText == "Biggest swing: week of 30 Mar, 400 kcal/day over")
    }

    // MARK: - Plate strip

    @Test("given a 30-day range across the spring change, when laying out plates, then each is labelled by its local day of the month")
    func monthPlatesAreLabelledByLocalDay() {
        let analytics = HistoryAnalytics(
            entries: [],
            profile: nil,
            range: .month,
            endDate: Self.date(2026, 3, 20),
            calendar: Self.newYork
        )

        let strip = HistoryDayPlateStrip(
            range: .month,
            summary: analytics.current,
            today: Self.date(2026, 3, 20, hour: 23)
        )

        // 19 February to 20 March: the short day (8 March) is still one plate.
        #expect(strip.plates.map(\.label) == (19...28).map(String.init) + (1...20).map(String.init))
        #expect(strip.plates.count == 30)
        #expect(strip.columnCount == 10)
        #expect(strip.plates.last?.outline == .current)
        #expect(strip.plates.dropLast().allSatisfy { $0.outline == .standard })
        #expect(strip.statusCounts == [.notLogged: 30])
    }

    @Test("given a week across the spring change, when laying out plates, then they read as weekdays and only today is current")
    func weekPlatesAreLabelledByWeekday() {
        let strip = HistoryDayPlateStrip(
            range: .week,
            summary: springWeek().current,
            // Late on Tuesday 10 March locally, already Wednesday in UTC.
            today: Self.date(2026, 3, 10, hour: 23)
        )

        #expect(strip.plates.map(\.label) == ["Wed", "Thu", "Fri", "Sat", "Sun", "Mon", "Tue"])
        #expect(strip.plates.map(\.outline) == [.standard, .standard, .standard, .standard, .over, .standard, .current])
        #expect(strip.statusCounts.values.reduce(0, +) == 7)
        #expect(strip.accessibilityLabel == "Goal consistency: 1 under, 1 on track, 1 over, 4 not logged.")
    }

    @Test("given a 90-day range, when laying out week plates, then the week holding today is current and the counts cover every day")
    func quarterPlatesMarkTheCurrentWeek() {
        let summary = springQuarter().current
        let strip = HistoryDayPlateStrip(range: .quarter, summary: summary, today: Self.date(2026, 4, 30, hour: 23))

        #expect(strip.plates.count == 14)
        #expect(strip.plates.last?.outline == .current)
        #expect(strip.plates.dropLast().allSatisfy { $0.outline != .current })
        #expect(strip.plates.first?.consistencyText == "0/2 on track")
        #expect(strip.plates.last?.consistencyText == "0/4 on track")
        #expect(strip.statusCounts.values.reduce(0, +) == 14)
    }

    // MARK: - Fixtures

    private static let newYork: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }()

    private static func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12, minute: Int = 0) -> Date {
        newYork.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private static let auckland: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Pacific/Auckland")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }()

    private static func aucklandDate(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12, minute: Int = 0) -> Date {
        auckland.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    /// 1–7 April 2026 in Auckland, across the end of daylight saving on Sunday 5 April:
    /// Sunday 600 over (logged late in the evening) and Tuesday on track.
    private func aucklandAutumnWeek() -> HistoryAnalytics {
        HistoryAnalytics(
            entries: [
                entry(at: Self.aucklandDate(2026, 4, 5, hour: 23, minute: 30), calories: 2_600),
                entry(at: Self.aucklandDate(2026, 4, 7), calories: 1_950)
            ],
            profile: Self.makeProfile(),
            range: .week,
            endDate: Self.aucklandDate(2026, 4, 7),
            calendar: Self.auckland
        )
    }

    /// 4–10 March 2026, across the change on Sunday 8 March: Sunday over (logged late in the
    /// evening, 600 over), Monday on track and Tuesday 500 under, against a 2,000 kcal goal.
    private func springWeek() -> HistoryAnalytics {
        HistoryAnalytics(
            entries: [
                entry(at: Self.date(2026, 3, 8, hour: 23, minute: 30), calories: 2_600),
                entry(at: Self.date(2026, 3, 9, hour: 0, minute: 30), calories: 1_950),
                entry(at: Self.date(2026, 3, 10), calories: 1_500)
            ],
            profile: Self.makeProfile(),
            range: .week,
            endDate: Self.date(2026, 3, 10),
            calendar: Self.newYork
        )
    }

    /// 31 January to 30 April 2026: one on-track day in February and the week of 9 March
    /// (the first full week after the change) over, at 2,400 a day.
    private func springQuarter() -> HistoryAnalytics {
        HistoryAnalytics(
            entries: [
                entry(at: Self.date(2026, 2, 2), calories: 2_000),
                entry(at: Self.date(2026, 3, 9), calories: 2_400),
                entry(at: Self.date(2026, 3, 10), calories: 2_400)
            ],
            profile: Self.makeProfile(),
            range: .quarter,
            endDate: Self.date(2026, 4, 30),
            calendar: Self.newYork
        )
    }

    private static func makeProfile() -> UserProfile {
        UserProfile(
            age: 30,
            sex: .female,
            heightCm: 168,
            weightKg: 64,
            activityLevel: .lightlyActive,
            dailyCalorieTarget: 2_000
        )
    }

    /// An entry at an exact instant. The factory normalises dates with the host calendar,
    /// so the instant is put back and bucketing is left to the calendar under test.
    private func entry(at date: Date, calories: Double) -> FoodLogEntry {
        let entry = makeTestEntry(
            date: date,
            mealType: .dinner,
            foodItem: makeTestFoodItem(
                name: "Dinner",
                caloriesPer100g: calories,
                proteinPer100g: 0,
                carbsPer100g: 0,
                fatPer100g: 0
            ),
            portionGrams: 100
        )
        entry.date = date
        return entry
    }
}
