import XCTest
@testable import Caloryn

final class FormattingAndDateHelperTests: XCTestCase {
    func testCalorieAndMacroFormattingUsesCompactUserFacingUnits() {
        XCTAssertEqual(123.9.kcalFormatted, "123 kcal")
        XCTAssertEqual(123.kcalFormatted, "123 kcal")
        XCTAssertEqual(12.0.macroFormatted, "12g")
        XCTAssertEqual(12.25.macroFormatted, "12.2g")
        XCTAssertEqual(12.0.spacedMacroFormatted(locale: Locale(identifier: "en_US")), "12 g")
        XCTAssertEqual(3.6.spacedMacroFormatted(locale: Locale(identifier: "en_US")), "3.6 g")
        XCTAssertEqual(98.7.wholeFormatted, "98")
    }

    func testSpacedGramsAreGroupedAndPointedForTheLocale() {
        let us = Locale(identifier: "en_US")
        let danish = Locale(identifier: "da_DK")

        XCTAssertEqual(1_450.0.spacedMacroFormatted(locale: us), "1,450 g")
        XCTAssertEqual(1_450.0.spacedMacroFormatted(locale: danish), "1.450 g")
        XCTAssertEqual(66.66.spacedMacroFormatted(locale: us), "66.7 g")
        XCTAssertEqual(66.66.spacedMacroFormatted(locale: danish), "66,7 g")
        XCTAssertEqual(99.6.spacedMacroFormatted(locale: us), "99.6 g", "A portion keeps its tenth rather than truncating")
        XCTAssertEqual((-0.01).spacedMacroFormatted(locale: us), "0 g")
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
