import XCTest
@testable import Caloryn

final class DayFoodLogSelectionTests: XCTestCase {
    /// A stand-in for a log entry, carrying only the three facts the selection
    /// rules read.
    private struct Entry: Equatable {
        let name: String
        let date: Date
        let mealType: MealType
        let createdAt: Date
    }

    // MARK: - Picking a day

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

    /// A day is matched as a calendar day, so the last hour of it belongs to it
    /// even on a date where the clocks moved.
    func testADayKeepsItsOwnEntriesAcrossADaylightSavingChange() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Copenhagen") ?? .gmt

        // Central European Summer Time begins on 29 March 2026; the day is 23h long.
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

    // MARK: - Picking a meal

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

    /// A meal keeps the order things were added in, so editing a portion cannot
    /// make a row jump up the section.
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

    // MARK: - Copy order

    /// Copying walks the day meal by meal, and each meal oldest first, so the
    /// new day is rebuilt in the order it was originally eaten.
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

    // MARK: - Copy availability

    func testCopyingIsOfferedIntoAnEmptyDayThatHasSomethingToCopy() {
        XCTAssertTrue(
            DayFoodLogSelection.canCopyYesterday(loggedTodayCount: 0, loggedYesterdayCount: 3)
        )
    }

    /// Never offered into a day that already has entries: copying again would
    /// silently double the day up.
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

    // MARK: - Sections

    func testTheThreeCoreMealsAlwaysHaveASectionInDayOrder() {
        XCTAssertEqual(DayFoodLogSelection.coreMeals, [.breakfast, .lunch, .dinner])
    }

    // MARK: - Helpers

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
}
