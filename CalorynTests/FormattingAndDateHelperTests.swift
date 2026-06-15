import XCTest
@testable import Caloryn

final class FormattingAndDateHelperTests: XCTestCase {
    func testCalorieAndMacroFormattingUsesCompactUserFacingUnits() {
        XCTAssertEqual(123.9.kcalFormatted, "123 kcal")
        XCTAssertEqual(123.kcalFormatted, "123 kcal")
        XCTAssertEqual(12.0.macroFormatted, "12g")
        XCTAssertEqual(12.25.macroFormatted, "12.2g")
        XCTAssertEqual(98.7.wholeFormatted, "98")
    }

    func testDateRangeHelpersReturnStartOfDayDescendingDates() {
        let start = makeTestDate(year: 2026, month: 1, day: 10, hour: 16)

        let dates = Date.datesInRange(from: start, days: 3)

        XCTAssertEqual(dates, [
            makeTestDate(year: 2026, month: 1, day: 10).startOfDay,
            makeTestDate(year: 2026, month: 1, day: 9).startOfDay,
            makeTestDate(year: 2026, month: 1, day: 8).startOfDay
        ])
        XCTAssertEqual(dates[0].daysFrom(dates[2]), 2)
    }

    func testStartOfWeekUsesMonday() {
        let wednesday = makeTestDate(year: 2026, month: 1, day: 7)

        XCTAssertEqual(wednesday.startOfWeek, makeTestDate(year: 2026, month: 1, day: 5).startOfDay)
    }
}
