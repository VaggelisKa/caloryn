import XCTest
@testable import Caloryn

final class DayFoodLogSelectionTests: XCTestCase {
    private struct Entry: Equatable {
        let name: String
        let date: Date
        let mealType: MealType
        let createdAt: Date
    }

    func testOnlyTheSelectedDaysEntriesAreSelected() {
        let day = makeDate(year: 2026, month: 3, day: 14)
        let entries = [
            makeEntry("today-morning", date: day.addingTimeInterval(8 * 3_600)),
            makeEntry("today-evening", date: day.addingTimeInterval(22 * 3_600)),
            makeEntry("yesterday", date: day.addingTimeInterval(-2 * 3_600)),
            makeEntry("tomorrow", date: day.addingTimeInterval(26 * 3_600))
        ]

        let selected = DayFoodLogSelection.entries(entries, on: day, date: \.date)

        XCTAssertEqual(selected.map(\.name), ["today-morning", "today-evening"])
    }

    func testADayKeepsItsOwnEntriesAcrossADaylightSavingChange() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Copenhagen") ?? .gmt

        let springForward = makeDate(year: 2026, month: 3, day: 29, calendar: calendar)
        let entries = [
            makeEntry("before", date: springForward.addingTimeInterval(1 * 3_600)),
            makeEntry("after", date: springForward.addingTimeInterval(20 * 3_600)),
            makeEntry("next-day", date: springForward.addingTimeInterval(23 * 3_600))
        ]

        let selected = DayFoodLogSelection.entries(
            entries,
            on: springForward,
            calendar: calendar,
            date: \.date
        )

        XCTAssertEqual(selected.map(\.name), ["before", "after"])
    }

    func testADayWithNothingLoggedSelectsNothing() {
        let day = makeDate(year: 2026, month: 3, day: 14)

        XCTAssertTrue(DayFoodLogSelection.entries([Entry](), on: day, date: \.date).isEmpty)
    }

    func testSelectedDayKeepsYesterdaySeparateAndOrdersEachMealOldestFirst() {
        let day = makeDate(year: 2026, month: 3, day: 14)
        let entries = [
            makeEntry("tomorrow", date: day.addingTimeInterval(26 * 3_600)),
            makeEntry("late-lunch", date: day, mealType: .lunch, createdAt: day.addingTimeInterval(60)),
            makeEntry("yesterday", date: day.addingTimeInterval(-2 * 3_600)),
            makeEntry("early-lunch", date: day, mealType: .lunch, createdAt: day)
        ]

        let projection = DayFoodLogProjection(
            entries,
            on: day,
            date: \.date,
            mealType: \.mealType,
            createdAt: \.createdAt
        )

        XCTAssertEqual(projection.today.map(\.name), ["late-lunch", "early-lunch"])
        XCTAssertEqual(projection.yesterday.map(\.name), ["yesterday"])
        XCTAssertEqual(projection.entries(for: .lunch).map(\.name), ["early-lunch", "late-lunch"])
        XCTAssertTrue(projection.entries(for: .dinner).isEmpty)
    }

    func testProjectionKeepsBothDaysCorrectAcrossSpringDaylightSavingChange() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Copenhagen") ?? .gmt
        let springForward = makeDate(year: 2026, month: 3, day: 29, calendar: calendar)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: springForward)!
        let entries = [
            makeEntry("yesterday-last-hour", date: yesterday.addingTimeInterval(23 * 3_600)),
            makeEntry("today-last-hour", date: springForward.addingTimeInterval(22 * 3_600)),
            makeEntry("tomorrow", date: springForward.addingTimeInterval(23 * 3_600))
        ]

        let projection = DayFoodLogProjection(
            entries,
            on: springForward,
            calendar: calendar,
            date: \.date,
            mealType: \.mealType,
            createdAt: \.createdAt
        )

        XCTAssertEqual(projection.yesterday.map(\.name), ["yesterday-last-hour"])
        XCTAssertEqual(projection.today.map(\.name), ["today-last-hour"])
    }

    func testProjectionUsesCalendarDaysForANonMidnightSelectionAcrossFallDaylightSavingChange() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Copenhagen") ?? .gmt
        let fallBack = makeDate(year: 2026, month: 10, day: 25, calendar: calendar)
        let selectedAfternoon = fallBack.addingTimeInterval(15 * 3_600)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: fallBack)!
        let entries = [
            makeEntry("yesterday", date: yesterday.addingTimeInterval(23 * 3_600)),
            makeEntry("today-after-fallback", date: fallBack.addingTimeInterval(24 * 3_600)),
            makeEntry("tomorrow", date: fallBack.addingTimeInterval(25 * 3_600))
        ]

        let projection = DayFoodLogProjection(
            entries,
            on: selectedAfternoon,
            calendar: calendar,
            date: \.date,
            mealType: \.mealType,
            createdAt: \.createdAt
        )

        XCTAssertEqual(projection.yesterday.map(\.name), ["yesterday"])
        XCTAssertEqual(projection.today.map(\.name), ["today-after-fallback"])
    }

    func testAnEntryLoggedForTomorrowIsNotPartOfTheSelectedDay() {
        let calendar = makeCalendar("UTC")
        let day = startOfDay(year: 2026, month: 3, day: 14, calendar: calendar)
        let entries = [
            makeEntry("yesterday", date: startOfDay(year: 2026, month: 3, day: 13, calendar: calendar)),
            makeEntry("today", date: day),
            makeEntry("tomorrow", date: startOfDay(year: 2026, month: 3, day: 15, calendar: calendar))
        ]

        let selected = DayFoodLogSelection.entries(entries, on: day, calendar: calendar, date: \.date)
        let projection = makeProjection(entries, on: day, calendar: calendar)

        XCTAssertEqual(selected.map(\.name), ["today"])
        XCTAssertEqual(projection.today.map(\.name), ["today"])
        XCTAssertEqual(projection.yesterday.map(\.name), ["yesterday"])
    }

    func testADayThatStartsLateForDaylightSavingLeavesTheNextMidnightToTheNextDay() {
        let calendar = makeCalendar("America/Havana")
        let shortDay = startOfDay(year: 2026, month: 3, day: 8, calendar: calendar)
        let nextDay = startOfDay(year: 2026, month: 3, day: 9, calendar: calendar)
        let entries = [
            makeEntry("day-before", date: startOfDay(year: 2026, month: 3, day: 7, calendar: calendar)),
            makeEntry("short-day", date: shortDay),
            makeEntry("next-day", date: nextDay)
        ]

        let selected = DayFoodLogSelection.entries(entries, on: shortDay, calendar: calendar, date: \.date)
        let onShortDay = makeProjection(entries, on: shortDay, calendar: calendar)
        let onNextDay = makeProjection(entries, on: nextDay, calendar: calendar)

        XCTAssertEqual(selected.map(\.name), ["short-day"])
        XCTAssertEqual(onShortDay.today.map(\.name), ["short-day"])
        XCTAssertEqual(onShortDay.yesterday.map(\.name), ["day-before"])
        XCTAssertEqual(onNextDay.today.map(\.name), ["next-day"])
        XCTAssertEqual(onNextDay.yesterday.map(\.name), ["short-day"])
    }

    func testEntriesAreFiledByTheClockOfTheCalendarTheyAreReadInAfterATimeZoneChange() {
        let copenhagen = makeCalendar("Europe/Copenhagen")
        let newYork = makeCalendar("America/New_York")
        let entries = [
            makeEntry("logged-24th", date: startOfDay(year: 2026, month: 7, day: 24, calendar: copenhagen)),
            makeEntry("logged-25th", date: startOfDay(year: 2026, month: 7, day: 25, calendar: copenhagen)),
            makeEntry("logged-26th", date: startOfDay(year: 2026, month: 7, day: 26, calendar: copenhagen))
        ]
        let day = startOfDay(year: 2026, month: 7, day: 25, calendar: newYork)

        let selected = DayFoodLogSelection.entries(entries, on: day, calendar: newYork, date: \.date)
        let projection = makeProjection(entries, on: day, calendar: newYork)

        XCTAssertEqual(selected.map(\.name), ["logged-26th"])
        XCTAssertEqual(projection.today.map(\.name), ["logged-26th"])
        XCTAssertEqual(projection.yesterday.map(\.name), ["logged-25th"])
    }

    func testTheSelectedDayIsTheCalendarsDayAroundEveryDaylightSavingChange() throws {
        let zones = [
            "Europe/Copenhagen",
            "America/Havana",
            "America/Santiago",
            "Africa/Cairo",
            "Asia/Beirut",
            "Australia/Lord_Howe"
        ]
        var checkedTransitions = 0

        for zone in zones {
            let calendar = makeCalendar(zone)
            for transition in daylightSavingTransitions(in: 2026, calendar: calendar) {
                checkedTransitions += 1
                let days = try (-2...2).map { offset in
                    calendar.startOfDay(for: try XCTUnwrap(calendar.date(byAdding: .day, value: offset, to: transition)))
                }
                let probes = [transition.addingTimeInterval(-1), transition, transition.addingTimeInterval(1)]
                    + days.flatMap { start in
                        [start.addingTimeInterval(-1), start, start.addingTimeInterval(1), start.addingTimeInterval(12 * 3_600)]
                    }
                let references = [transition] + days.dropFirst().dropLast().flatMap { start in
                    [start, start.addingTimeInterval(1), start.addingTimeInterval(12 * 3_600)]
                }

                for reference in references {
                    let previousDay = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: reference))
                    let expectedToday = probes.filter { calendar.isDate($0, inSameDayAs: reference) }
                    let expectedYesterday = probes.filter {
                        !calendar.isDate($0, inSameDayAs: reference) && calendar.isDate($0, inSameDayAs: previousDay)
                    }

                    let selected = DayFoodLogSelection.entries(probes, on: reference, calendar: calendar, date: { $0 })
                    let projection = DayFoodLogProjection(
                        probes,
                        on: reference,
                        calendar: calendar,
                        date: { $0 },
                        mealType: { _ in .breakfast },
                        createdAt: { $0 }
                    )

                    XCTAssertEqual(selected, expectedToday, "\(zone) on \(reference)")
                    XCTAssertEqual(projection.today, expectedToday, "\(zone) on \(reference)")
                    XCTAssertEqual(projection.yesterday, expectedYesterday, "\(zone) on \(reference)")
                }
            }
        }

        XCTAssertGreaterThan(checkedTransitions, 0)
    }

    func testAMealTakesOnlyItsOwnEntries() {
        let entries = [
            makeEntry("oats", mealType: .breakfast),
            makeEntry("soup", mealType: .lunch),
            makeEntry("apple", mealType: .snack)
        ]

        let lunch = DayFoodLogSelection.entries(
            entries,
            inMeal: .lunch,
            mealType: \.mealType,
            createdAt: \.createdAt
        )

        XCTAssertEqual(lunch.map(\.name), ["soup"])
    }

    func testAMealsEntriesStayInTheOrderTheyWereAdded() {
        let base = makeDate(year: 2026, month: 3, day: 14)
        let entries = [
            makeEntry("third", mealType: .dinner, createdAt: base.addingTimeInterval(300)),
            makeEntry("first", mealType: .dinner, createdAt: base),
            makeEntry("second", mealType: .dinner, createdAt: base.addingTimeInterval(60))
        ]

        let dinner = DayFoodLogSelection.entries(
            entries,
            inMeal: .dinner,
            mealType: \.mealType,
            createdAt: \.createdAt
        )

        XCTAssertEqual(dinner.map(\.name), ["first", "second", "third"])
    }

    func testCopyingRunsDownTheDayMealByMealAndOldestFirst() {
        let base = makeDate(year: 2026, month: 3, day: 14)
        let entries = [
            makeEntry("late-snack", mealType: .snack, createdAt: base.addingTimeInterval(600)),
            makeEntry("dinner", mealType: .dinner, createdAt: base),
            makeEntry("second-breakfast", mealType: .breakfast, createdAt: base.addingTimeInterval(120)),
            makeEntry("first-breakfast", mealType: .breakfast, createdAt: base),
            makeEntry("lunch", mealType: .lunch, createdAt: base)
        ]

        let ordered = DayFoodLogSelection.copyOrdered(
            entries,
            mealType: \.mealType,
            createdAt: \.createdAt
        )

        XCTAssertEqual(
            ordered.map(\.name),
            ["first-breakfast", "second-breakfast", "lunch", "dinner", "late-snack"]
        )
    }

    func testCopyingIsOfferedIntoAnEmptyDayThatHasSomethingToCopy() {
        XCTAssertTrue(
            DayFoodLogSelection.canCopyYesterday(loggedTodayCount: 0, loggedYesterdayCount: 3)
        )
    }

    func testCopyingIsNotOfferedOnceTheDayHasAnythingInIt() {
        XCTAssertFalse(
            DayFoodLogSelection.canCopyYesterday(loggedTodayCount: 1, loggedYesterdayCount: 3)
        )
    }

    func testCopyingIsNotOfferedWhenThereIsNothingToCopy() {
        XCTAssertFalse(
            DayFoodLogSelection.canCopyYesterday(loggedTodayCount: 0, loggedYesterdayCount: 0)
        )
    }

    func testTheThreeCoreMealsAlwaysHaveASectionInDayOrder() {
        XCTAssertEqual(DayFoodLogSelection.coreMeals, [.breakfast, .lunch, .dinner])
    }

    private func makeEntry(
        _ name: String,
        date: Date = Date(timeIntervalSinceReferenceDate: 0),
        mealType: MealType = .breakfast,
        createdAt: Date = Date(timeIntervalSinceReferenceDate: 0)
    ) -> Entry {
        Entry(name: name, date: date, mealType: mealType, createdAt: createdAt)
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        calendar: Calendar = .current
    ) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .now
    }

    private func makeCalendar(_ zone: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone) ?? .gmt
        return calendar
    }

    private func startOfDay(year: Int, month: Int, day: Int, calendar: Calendar) -> Date {
        let noon = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? .now
        return calendar.startOfDay(for: noon)
    }

    private func makeProjection(
        _ entries: [Entry],
        on day: Date,
        calendar: Calendar
    ) -> DayFoodLogProjection<Entry> {
        DayFoodLogProjection(
            entries,
            on: day,
            calendar: calendar,
            date: \.date,
            mealType: \.mealType,
            createdAt: \.createdAt
        )
    }

    private func daylightSavingTransitions(in year: Int, calendar: Calendar) -> [Date] {
        guard let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let end = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) else {
            return []
        }
        return Array(
            sequence(first: start) { calendar.timeZone.nextDaylightSavingTimeTransition(after: $0) }
                .dropFirst()
                .prefix { $0 < end }
        )
    }
}
