import Foundation
import Testing
@testable import Caloryn

@MainActor
@Suite("History trend calendar coverage")
struct HistoryTrendCalendarCoverageTests {
    @Test("given a week across the spring change, when projecting the trend, then axis initials and spoken dates follow the injected calendar")
    func dailyPointLabelsFollowTheCalendar() {
        let projection = HistoryCalorieTrendProjection(range: .week, summary: springWeek().current, today: Self.date(2026, 3, 10))

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
        #expect(sunday.status == .over)
        #expect(sunday.accessibilityValue == "2600 calories, Over")
        #expect(monday.value == 1_950)
        #expect(monday.status == .onTrack)
        #expect(projection.points[0].accessibilityValue == "No calories logged")
        #expect(projection.points.filter(\.isLogged).count == 3)
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
        #expect(dstWeek.status == .over)
        #expect(dstWeek.accessibilityValue == "2400 average calories per logged day, Over")
    }

    @Test("given a week in Auckland across its autumn change, when labelling daily points, then initials and spoken dates name Auckland's days")
    func dailyLabelsUseTheInjectedCalendarRatherThanTheHost() {
        let projection = HistoryCalorieTrendProjection(range: .week, summary: aucklandAutumnWeek().current, today: Self.aucklandDate(2026, 4, 7))

        #expect(projection.points.map(\.xAxisLabel) == ["W", "T", "F", "S", "S", "M", "T"])
        #expect(projection.points.map(\.accessibilityLabel) == [
            "Wed, 1 Apr", "Thu, 2 Apr", "Fri, 3 Apr", "Sat, 4 Apr", "Sun, 5 Apr", "Mon, 6 Apr", "Tue, 7 Apr"
        ])
        #expect(projection.points[4].id == "day-2026-04-04T11:00:00Z")
        #expect(projection.points[5].id == "day-2026-04-05T12:00:00Z")
        #expect(projection.points[4].value == 2_600)
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
        #expect(overWeek.status == .over)
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
