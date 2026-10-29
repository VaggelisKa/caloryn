import Foundation
import Testing
@testable import Caloryn

@MainActor
@Suite("History trend calendar coverage")
struct HistoryTrendCalendarCoverageTests {
    @Test("given a week across the spring change, when projecting the trend, then axis initials and spoken dates follow the injected calendar")
    func dailyPointLabelsFollowTheCalendar() {
        let projection = HistoryCalorieTrendProjection(range: .week, summary: springWeek().current, today: Self.date(2026, 3, 10))

        #expect(projection.calendar == Self.newYork)
        #expect(projection.points.map(\.xAxisLabel) == ["W", "T", "F", "S", "S", "M", "T"])
        #expect(projection.points.map(\.accessibilityLabel) == [
            "Wed, 4 Mar", "Thu, 5 Mar", "Fri, 6 Mar", "Sat, 7 Mar", "Sun, 8 Mar", "Mon, 9 Mar", "Tue, 10 Mar"
        ])
        #expect(projection.points.map(\.index) == [0, 1, 2, 3, 4, 5, 6])
    }

    @Test("given 30 days across the spring change, when labelling the axis, then only Mondays are named, by day and month in the injected calendar")
    func monthAxisLabelsOnlyMondays() {
        let projection = HistoryCalorieTrendProjection(range: .month, summary: springMonth().current, today: Self.date(2026, 3, 20))
        let labelled = projection.points.filter { !$0.xAxisLabel.isEmpty }

        #expect(projection.points.count == 30)
        #expect(labelled.map(\.xAxisLabel) == ["23 Feb", "2 Mar", "9 Mar", "16 Mar"])
        #expect(labelled.map(\.index) == [4, 11, 18, 25])
        #expect(labelled.map(\.accessibilityLabel) == ["Mon, 23 Feb", "Mon, 2 Mar", "Mon, 9 Mar", "Mon, 16 Mar"])
    }

    @Test("given 14 days, when labelling the axis, then every day keeps its weekday initial")
    func twoWeekAxisLabelsEveryDay() {
        let analytics = HistoryAnalytics(
            entries: [],
            profile: nil,
            range: .twoWeeks,
            endDate: Self.date(2026, 3, 10),
            calendar: Self.newYork
        )
        let projection = HistoryCalorieTrendProjection(range: .twoWeeks, summary: analytics.current, today: Self.date(2026, 3, 10))

        #expect(projection.points.map(\.xAxisLabel) == ["W", "T", "F", "S", "S", "M", "T", "W", "T", "F", "S", "S", "M", "T"])
    }

    @Test("given days either side of the spring change, when identifying their points, then each is keyed by its own UTC midnight")
    func dailyPointIdsShiftWithTheOffset() {
        let projection = HistoryCalorieTrendProjection(range: .week, summary: springWeek().current, today: Self.date(2026, 3, 10))

        #expect(projection.points[3].id == "day-2026-03-07T05:00:00Z")
        #expect(projection.points[4].id == "day-2026-03-08T05:00:00Z")
        #expect(projection.points[5].id == "day-2026-03-09T04:00:00Z")
    }

    @Test("given logged days across the spring change, when projecting the trend, then values, deltas and spoken values describe each local day")
    func dailyPointValuesDescribeLocalDays() {
        let projection = HistoryCalorieTrendProjection(range: .week, summary: springWeek().current, today: Self.date(2026, 3, 10))
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

    @Test("given a swing on the short day, when naming the day furthest from goal, then the day is named in the injected calendar")
    func theFurthestDayIsNamedInTheCalendar() {
        let projection = HistoryCalorieTrendProjection(range: .week, summary: springWeek().current, today: Self.date(2026, 3, 10))

        #expect(projection.furthestFromGoal?.periodText == "Sun 8 Mar")
        #expect(projection.furthestFromGoal?.text == "Furthest from goal: Sun 8 Mar, +600")
    }

    @Test("given an instant that is already the next day in UTC, when labelling it for the drill-down, then the injected calendar's day is used")
    func drillDownLabelsUseTheCalendar() {
        let projection = HistoryCalorieTrendProjection(range: .week, summary: springWeek().current, today: Self.date(2026, 3, 10))
        let instant = Date(timeIntervalSince1970: 1_773_021_600)

        #expect(projection.dayText(for: instant) == "Sun 8 Mar")
        #expect(projection.weekStartText(for: instant) == "8 Mar")
    }

    @Test("given a 90-day range across the spring change, when projecting the trend, then every other week counting back from this week is labelled by its Monday")
    func weeklyPointLabelsFollowTheCalendar() throws {
        let projection = HistoryCalorieTrendProjection(range: .quarter, summary: springQuarter().current, today: Self.date(2026, 4, 30))

        #expect(projection.points.count == 14)
        #expect(
            projection.points.map(\.xAxisLabel)
                == ["", "2 Feb", "", "16 Feb", "", "2 Mar", "", "16 Mar", "", "30 Mar", "", "13 Apr", "", "This week"]
        )
        #expect(projection.points.first?.accessibilityLabel == "Week of 26 Jan")
        let dstWeek = try #require(projection.points.first { $0.accessibilityLabel == "Week of 9 Mar" })
        #expect(dstWeek.id == "week-2026-03-09T04:00:00Z")
        #expect(dstWeek.isLogged)
        #expect(dstWeek.value == 2_400)
        #expect(dstWeek.targetDelta == 400)
        #expect(dstWeek.status == .over)
        #expect(dstWeek.accessibilityValue == "2400 average calories per logged day, Over")
    }

    @Test("given a 90-day range with one week far over, when naming the week furthest from goal, then that week is named by its Monday in the calendar")
    func theFurthestWeekIsNamedInTheCalendar() {
        let projection = HistoryCalorieTrendProjection(range: .quarter, summary: springQuarter().current, today: Self.date(2026, 4, 30))

        #expect(projection.furthestFromGoal?.text == "Furthest from goal: week of 9 Mar, +400 kcal/day")
    }

    @Test("given a week in Auckland across its autumn change, when labelling daily points, then initials, spoken dates and the furthest day name Auckland's days")
    func dailyLabelsUseTheInjectedCalendarRatherThanTheHost() {
        let projection = HistoryCalorieTrendProjection(range: .week, summary: aucklandAutumnWeek().current, today: Self.aucklandDate(2026, 4, 7))

        #expect(projection.points.map(\.xAxisLabel) == ["W", "T", "F", "S", "S", "M", "T"])
        #expect(projection.points.map(\.accessibilityLabel) == [
            "Wed, 1 Apr", "Thu, 2 Apr", "Fri, 3 Apr", "Sat, 4 Apr", "Sun, 5 Apr", "Mon, 6 Apr", "Tue, 7 Apr"
        ])
        #expect(projection.points[4].id == "day-2026-04-04T11:00:00Z")
        #expect(projection.points[5].id == "day-2026-04-05T12:00:00Z")
        #expect(projection.points[4].value == 2_600)
        #expect(projection.furthestFromGoal?.text == "Furthest from goal: Sun 5 Apr, +600")
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
        let marchDays: [String] = (22...31).map { String($0) }
        let aprilDays: [String] = (1...20).map { String($0) }
        #expect(month.plates.map(\.label) == marchDays + aprilDays)
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
        let projection = HistoryCalorieTrendProjection(range: .quarter, summary: analytics.current, today: Self.aucklandDate(2026, 4, 30))

        #expect(projection.points.count == 14)
        #expect(projection.points.first?.accessibilityLabel == "Week of 26 Jan")
        let overWeek = try #require(projection.points.first { $0.accessibilityLabel == "Week of 30 Mar" })
        #expect(overWeek.id == "week-2026-03-29T11:00:00Z")
        #expect(overWeek.value == 2_400)
        #expect(projection.furthestFromGoal?.text == "Furthest from goal: week of 30 Mar, +400 kcal/day")
    }

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

        let februaryDays: [String] = (19...28).map { String($0) }
        let marchDays: [String] = (1...20).map { String($0) }
        #expect(strip.plates.map(\.label) == februaryDays + marchDays)
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

    private func springMonth() -> HistoryAnalytics {
        HistoryAnalytics(
            entries: [],
            profile: Self.makeProfile(),
            range: .month,
            endDate: Self.date(2026, 3, 20),
            calendar: Self.newYork
        )
    }

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
