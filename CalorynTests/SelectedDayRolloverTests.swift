import XCTest
@testable import Caloryn

final class SelectedDayRolloverTests: XCTestCase {

    func testSelectionIsUntouchedWhenTheCalendarHasNotRolledOver() {
        let today = makeTestDate(year: 2026, month: 3, day: 9)

        let result = SelectedDayRollover.selectedDay(
            selected: today,
            lastKnownToday: today,
            now: makeTestDate(year: 2026, month: 3, day: 9, hour: 23, minute: 59)
        )

        XCTAssertEqual(result, today)
    }

    func testSittingOnTheCurrentDayFollowsTheNewDay() {
        let yesterday = makeTestDate(year: 2026, month: 3, day: 9)
        let now = makeTestDate(year: 2026, month: 3, day: 10, hour: 0, minute: 30)

        let result = SelectedDayRollover.selectedDay(
            selected: yesterday,
            lastKnownToday: yesterday,
            now: now
        )

        XCTAssertEqual(result, Calendar.current.startOfDay(for: now))
    }

    func testDeliberatelyBrowsingAnOlderDayIsLeftAlone() {
        let browsing = makeTestDate(year: 2026, month: 3, day: 4)
        let now = makeTestDate(year: 2026, month: 3, day: 10, hour: 0, minute: 30)

        let result = SelectedDayRollover.selectedDay(
            selected: browsing,
            lastKnownToday: makeTestDate(year: 2026, month: 3, day: 9),
            now: now
        )

        XCTAssertEqual(result, browsing, "A date the user chose must not move under them")
    }

    func testAFutureDayIsLeftAlone() {
        let future = makeTestDate(year: 2026, month: 3, day: 12)
        let now = makeTestDate(year: 2026, month: 3, day: 10, hour: 0, minute: 30)

        let result = SelectedDayRollover.selectedDay(
            selected: future,
            lastKnownToday: makeTestDate(year: 2026, month: 3, day: 9),
            now: now
        )

        XCTAssertEqual(result, future)
    }

    func testRolloverAcrossSeveralDaysStillLandsOnToday() {
        let staleToday = makeTestDate(year: 2026, month: 3, day: 9)
        let now = makeTestDate(year: 2026, month: 3, day: 13, hour: 9)

        let result = SelectedDayRollover.selectedDay(
            selected: staleToday,
            lastKnownToday: staleToday,
            now: now
        )

        XCTAssertEqual(result, Calendar.current.startOfDay(for: now))
    }
}
