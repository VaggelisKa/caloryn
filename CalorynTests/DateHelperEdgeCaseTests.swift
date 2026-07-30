import Testing
import Foundation
@testable import Caloryn

/// Edge-case coverage for `Caloryn/Extensions/Date+Helpers.swift`.
///
/// `FormattingAndDateHelperTests.swift` already covers the basic
/// `datesInRange`/`startOfWeek` happy path. This file focuses on DST
/// transitions, month/year boundaries, leap days, and near-midnight times.
///
/// All dates are constructed explicitly via `makeTestDate` (defined in
/// `TestFactories.swift`) using `Calendar.current`/its time zone -- never
/// `Date.now` -- so results are deterministic and reproducible.
///
/// The ambient (no-argument) spellings are what this file exercises.
/// `DateHelperCalendarInjectionTests.swift` covers the same rules under an
/// injected calendar -- foreign time zones, week starts and non-Gregorian
/// calendars -- including `isToday` and `isAtFutureLogLimit`, which are only
/// pinnable once the calendar and "now" are supplied rather than read.
struct DateHelperEdgeCaseTests {

    // MARK: - startOfDay

    @Test(
        "startOfDay collapses any time of day to local midnight",
        arguments: [0, 6, 12, 18, 23]
    )
    func startOfDayCollapsesToMidnightRegardlessOfHour(hour: Int) {
        let date = makeTestDate(year: 2026, month: 6, day: 15, hour: hour, minute: hour == 23 ? 59 : 0)
        let expectedMidnight = makeTestDate(year: 2026, month: 6, day: 15, hour: 0, minute: 0).startOfDay
        #expect(date.startOfDay == expectedMidnight)
    }

    @Test("startOfDay on a leap day (Feb 29) stays on the leap day")
    func startOfDayOnLeapDayStaysOnLeapDay() {
        let date = makeTestDate(year: 2024, month: 2, day: 29, hour: 23, minute: 59)
        let midnight = makeTestDate(year: 2024, month: 2, day: 29, hour: 0, minute: 0)
        #expect(date.startOfDay == midnight.startOfDay)
    }

    // MARK: - tomorrow / yesterday across month, year, and leap boundaries

    @Test("tomorrow crosses a month boundary correctly")
    func tomorrowCrossesMonthBoundary() {
        let jan31 = makeTestDate(year: 2026, month: 1, day: 31)
        let feb1 = makeTestDate(year: 2026, month: 2, day: 1)
        #expect(jan31.tomorrow.startOfDay == feb1.startOfDay)
    }

    @Test("yesterday crosses a month boundary correctly")
    func yesterdayCrossesMonthBoundary() {
        let mar1 = makeTestDate(year: 2026, month: 3, day: 1)
        let feb28 = makeTestDate(year: 2026, month: 2, day: 28)
        #expect(mar1.yesterday.startOfDay == feb28.startOfDay)
    }

    @Test("tomorrow crosses a year boundary correctly")
    func tomorrowCrossesYearBoundary() {
        let dec31 = makeTestDate(year: 2025, month: 12, day: 31)
        let jan1 = makeTestDate(year: 2026, month: 1, day: 1)
        #expect(dec31.tomorrow.startOfDay == jan1.startOfDay)
    }

    @Test("yesterday crosses a year boundary correctly")
    func yesterdayCrossesYearBoundary() {
        let jan1 = makeTestDate(year: 2026, month: 1, day: 1)
        let dec31 = makeTestDate(year: 2025, month: 12, day: 31)
        #expect(jan1.yesterday.startOfDay == dec31.startOfDay)
    }

    @Test("tomorrow from Feb 28 lands on Feb 29 in a leap year")
    func tomorrowFromFeb28LandsOnLeapDayInLeapYear() {
        let feb28 = makeTestDate(year: 2024, month: 2, day: 28)
        let feb29 = makeTestDate(year: 2024, month: 2, day: 29)
        #expect(feb28.tomorrow.startOfDay == feb29.startOfDay)
    }

    @Test("tomorrow from Feb 28 skips straight to Mar 1 in a non-leap year")
    func tomorrowFromFeb28SkipsToMarchInNonLeapYear() {
        let feb28 = makeTestDate(year: 2026, month: 2, day: 28)
        let mar1 = makeTestDate(year: 2026, month: 3, day: 1)
        #expect(feb28.tomorrow.startOfDay == mar1.startOfDay)
    }

    @Test("tomorrow preserves the same local hour across a DST spring-forward transition")
    func tomorrowPreservesLocalHourAcrossSpringForward() {
        // EU spring-forward 2026 is the last Sunday of March (Mar 29).
        let beforeTransition = makeTestDate(year: 2026, month: 3, day: 28, hour: 12)
        let next = beforeTransition.tomorrow
        #expect(Calendar.current.component(.day, from: next) == 29)
        #expect(Calendar.current.component(.hour, from: next) == 12)
    }

    @Test("tomorrow preserves the same local hour across a DST fall-back transition")
    func tomorrowPreservesLocalHourAcrossFallBack() {
        // EU fall-back 2026 is the last Sunday of October (Oct 25).
        let beforeTransition = makeTestDate(year: 2026, month: 10, day: 25, hour: 12)
        let next = beforeTransition.tomorrow
        #expect(Calendar.current.component(.day, from: next) == 26)
        #expect(Calendar.current.component(.hour, from: next) == 12)
    }

    // MARK: - daysFrom

    @Test("daysFrom counts exactly one calendar day across a DST spring-forward transition, despite the 23-hour wall-clock gap")
    func daysFromCountsOneDayAcrossSpringForward() {
        let before = makeTestDate(year: 2026, month: 3, day: 29, hour: 12)
        let after = makeTestDate(year: 2026, month: 3, day: 28, hour: 12)
        #expect(before.daysFrom(after) == 1)
        #expect(after.daysFrom(before) == -1)
    }

    @Test("daysFrom counts exactly one calendar day across a DST fall-back transition, despite the 25-hour wall-clock gap")
    func daysFromCountsOneDayAcrossFallBack() {
        let before = makeTestDate(year: 2026, month: 10, day: 26, hour: 12)
        let after = makeTestDate(year: 2026, month: 10, day: 25, hour: 12)
        #expect(before.daysFrom(after) == 1)
        #expect(after.daysFrom(before) == -1)
    }

    @Test("daysFrom counts 2 days across the Feb 29 leap day, but only 1 across the equivalent non-leap-year span")
    func daysFromAccountsForLeapDay() {
        let leapYearAfter = makeTestDate(year: 2024, month: 3, day: 1)
        let leapYearBefore = makeTestDate(year: 2024, month: 2, day: 28)
        #expect(leapYearAfter.daysFrom(leapYearBefore) == 2)

        let nonLeapYearAfter = makeTestDate(year: 2026, month: 3, day: 1)
        let nonLeapYearBefore = makeTestDate(year: 2026, month: 2, day: 28)
        #expect(nonLeapYearAfter.daysFrom(nonLeapYearBefore) == 1)
    }

    @Test("daysFrom is antisymmetric: a.daysFrom(b) == -(b.daysFrom(a))")
    func daysFromIsAntisymmetric() {
        let a = makeTestDate(year: 2026, month: 7, day: 25)
        let b = makeTestDate(year: 2025, month: 12, day: 1)
        #expect(a.daysFrom(b) == -(b.daysFrom(a)))
    }

    @Test("daysFrom is zero for two times on the same calendar day")
    func daysFromIsZeroWithinSameCalendarDay() {
        let morning = makeTestDate(year: 2026, month: 7, day: 25, hour: 0, minute: 1)
        let night = makeTestDate(year: 2026, month: 7, day: 25, hour: 23, minute: 59)
        #expect(morning.daysFrom(night) == 0)
        #expect(night.daysFrom(morning) == 0)
    }

    // MARK: - datesInRange

    @Test("datesInRange with days: 0 returns an empty array")
    func datesInRangeWithZeroDaysReturnsEmptyArray() {
        let start = makeTestDate(year: 2026, month: 1, day: 10)
        #expect(Date.datesInRange(from: start, days: 0) == [])
    }

    @Test("datesInRange with days: 1 returns exactly the start date's start-of-day")
    func datesInRangeWithOneDayReturnsJustStart() {
        let start = makeTestDate(year: 2026, month: 1, day: 10, hour: 18)
        #expect(Date.datesInRange(from: start, days: 1) == [start.startOfDay])
    }

    @Test("datesInRange descends across a year boundary in the correct order")
    func datesInRangeDescendsAcrossYearBoundary() {
        let start = makeTestDate(year: 2026, month: 1, day: 2)
        let dates = Date.datesInRange(from: start, days: 5)

        let expected = [
            makeTestDate(year: 2026, month: 1, day: 2),
            makeTestDate(year: 2026, month: 1, day: 1),
            makeTestDate(year: 2025, month: 12, day: 31),
            makeTestDate(year: 2025, month: 12, day: 30),
            makeTestDate(year: 2025, month: 12, day: 29),
        ].map(\.startOfDay)

        #expect(dates == expected)
    }

    @Test("datesInRange spanning a leap day includes Feb 29")
    func datesInRangeSpanningLeapDayIncludesFeb29() {
        let start = makeTestDate(year: 2024, month: 3, day: 2)
        let dates = Date.datesInRange(from: start, days: 4)

        let expected = [
            makeTestDate(year: 2024, month: 3, day: 2),
            makeTestDate(year: 2024, month: 3, day: 1),
            makeTestDate(year: 2024, month: 2, day: 29),
            makeTestDate(year: 2024, month: 2, day: 28),
        ].map(\.startOfDay)

        #expect(dates == expected)
    }

    // MARK: - startOfWeek (Monday-based)

    @Test(
        "startOfWeek maps every day of a Mon-Sun week back to that week's Monday",
        arguments: [1, 2, 3, 4, 5, 6, 7]
    )
    func startOfWeekMapsEveryWeekdayToMonday(dayOffset: Int) {
        // 2026-01-05 is a Monday.
        let monday = makeTestDate(year: 2026, month: 1, day: 5)
        let dayInWeek = Calendar.current.date(byAdding: .day, value: dayOffset - 1, to: monday)!
        #expect(dayInWeek.startOfWeek == monday.startOfDay)
    }

    @Test("startOfWeek for a date early in January resolves to the prior calendar year's last Monday")
    func startOfWeekAtYearBoundaryResolvesToPriorYear() {
        // 2026-01-01 is a Thursday; the Monday of its week is 2025-12-29.
        let jan1 = makeTestDate(year: 2026, month: 1, day: 1)
        let dec29 = makeTestDate(year: 2025, month: 12, day: 29)
        #expect(jan1.startOfWeek == dec29.startOfDay)
    }

    @Test("startOfWeek for the last day of December resolves within the same week logic as early January")
    func startOfWeekForDec31ResolvesToMondayOfThatWeek() {
        // 2025-12-31 is a Wednesday; the Monday of its week is 2025-12-29.
        let dec31 = makeTestDate(year: 2025, month: 12, day: 31)
        let dec29 = makeTestDate(year: 2025, month: 12, day: 29)
        #expect(dec31.startOfWeek == dec29.startOfDay)
    }

    @Test("startOfWeek is idempotent: applying it to its own result returns the same date")
    func startOfWeekIsIdempotent() {
        let wednesday = makeTestDate(year: 2026, month: 1, day: 7)
        let monday = wednesday.startOfWeek
        #expect(monday.startOfWeek == monday)
    }

    // MARK: - shortWeekday / shortFormatted / dayMonthFormatted
    //
    // These formatters use locale-sensitive tokens ("EEE", "MMM"), so exact
    // expected strings are computed with an equivalent locale-aware
    // DateFormatter oracle rather than hardcoded English text. This keeps
    // the tests correct regardless of which locale the test host/simulator
    // is configured with.

    private func oracle(format: String, for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: date)
    }

    @Test("shortWeekday matches a locale-aware 'EEE' formatter for a fixed date")
    func shortWeekdayMatchesLocaleAwareFormatter() {
        let date = makeTestDate(year: 2026, month: 1, day: 5) // Monday
        #expect(date.shortWeekday == oracle(format: "EEE", for: date))
    }

    @Test("shortWeekday returns the identical string for two dates exactly 7 days apart")
    func shortWeekdayIsStableAcrossWholeWeeks() {
        let date = makeTestDate(year: 2026, month: 1, day: 5)
        let weekLater = Calendar.current.date(byAdding: .day, value: 7, to: date)!
        #expect(date.shortWeekday == weekLater.shortWeekday)
    }

    @Test("dayMonthFormatted matches a locale-aware 'd MMM' formatter across a month boundary and a leap day")
    func dayMonthFormattedMatchesLocaleAwareFormatter() {
        for date in [
            makeTestDate(year: 2026, month: 1, day: 31),
            makeTestDate(year: 2026, month: 2, day: 1),
            makeTestDate(year: 2024, month: 2, day: 29),
        ] {
            #expect(date.dayMonthFormatted == oracle(format: "d MMM", for: date))
        }
    }

    @Test("shortFormatted falls back to a locale-aware 'EEE, d MMM' formatter for dates that are not today or yesterday")
    func shortFormattedFallsBackToLocaleAwareFormatterForDistantDates() {
        // Fixed historical dates that will never coincide with "today" or
        // "yesterday" relative to any real test run.
        for date in [
            makeTestDate(year: 2020, month: 6, day: 15),
            makeTestDate(year: 2024, month: 2, day: 29),
        ] {
            #expect(date.shortFormatted == oracle(format: "EEE, d MMM", for: date))
        }
    }

    // MARK: - Calendar day-boundary semantics across time zones
    //
    // These characterize the `Calendar.startOfDay(for:)` primitive that
    // `startOfDay`/`daysFrom` are built on, using explicitly-constructed
    // `Calendar` values for a couple of named time zones -- including one
    // with a non-zero, non-hour offset (India Standard Time, UTC+5:30) -- to
    // show how the same absolute instant resolves to different calendar days
    // depending on the zone in effect. The helpers themselves are driven with
    // those zones in `DateHelperCalendarInjectionTests.swift`.

    private func calendar(timeZoneIdentifier: String) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: timeZoneIdentifier)!
        return cal
    }

    @Test("The same absolute instant can fall on different calendar days in UTC vs. a +5:30 (non-hour) offset zone")
    func sameInstantResolvesToDifferentCalendarDaysAcrossNonHourOffsetTimeZone() {
        let utc = calendar(timeZoneIdentifier: "UTC")
        var components = DateComponents()
        components.calendar = utc
        components.timeZone = utc.timeZone
        components.year = 2025
        components.month = 12
        components.day = 31
        components.hour = 23
        components.minute = 45
        let instant = components.date!

        let kolkata = calendar(timeZoneIdentifier: "Asia/Kolkata") // UTC+5:30

        let utcDay = utc.component(.day, from: instant)
        let utcMonth = utc.component(.month, from: instant)
        let kolkataDay = kolkata.component(.day, from: instant)
        let kolkataMonth = kolkata.component(.month, from: instant)

        #expect((utcMonth, utcDay) == (12, 31))
        #expect((kolkataMonth, kolkataDay) == (1, 1))
        #expect(utc.startOfDay(for: instant) != kolkata.startOfDay(for: instant))
    }

    @Test("startOfDay for the same instant differs between two distinct time zones, one with a negative offset")
    func startOfDayDiffersBetweenTimeZonesForSameInstant() {
        let utc = calendar(timeZoneIdentifier: "UTC")
        var components = DateComponents()
        components.calendar = utc
        components.timeZone = utc.timeZone
        components.year = 2026
        components.month = 6
        components.day = 15
        components.hour = 2
        components.minute = 0
        let instant = components.date!

        let losAngeles = calendar(timeZoneIdentifier: "America/Los_Angeles") // UTC-7/-8

        let laDay = losAngeles.component(.day, from: instant)
        let laMonth = losAngeles.component(.month, from: instant)

        // 02:00 UTC on Jun 15 is still Jun 14 evening in Los Angeles (PDT, UTC-7).
        #expect((laMonth, laDay) == (6, 14))
        #expect(utc.startOfDay(for: instant) != losAngeles.startOfDay(for: instant))
    }
}
