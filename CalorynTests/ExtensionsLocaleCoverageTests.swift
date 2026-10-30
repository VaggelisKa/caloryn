import Foundation
import Testing
@testable import Caloryn

@MainActor
@Suite("Day title locale and zone")
struct DayTitleLocaleTests {
    private static func calendar(_ locale: String, zone: String = "UTC") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: locale)
        calendar.timeZone = TimeZone(identifier: zone)!
        return calendar
    }

    private static let noonUTC = Date(timeIntervalSince1970: 1_792_238_400)

    @Test(
        "The weekday and month are named in the calendar's locale, day before month",
        arguments: [
            ("en_GB", "Saturday 17 October"),
            ("en_US", "Saturday 17 October"),
            ("de_DE", "Samstag 17 Oktober"),
            ("da_DK", "lørdag 17 oktober"),
        ]
    )
    func titleFollowsLocale(locale: String, expected: String) {
        #expect(DayTitle.text(for: Self.noonUTC, in: Self.calendar(locale)) == expected)
    }

    @Test("The calendar's time zone decides which day an instant falls on")
    func titleFollowsZone() {
        let lateSaturdayUTC = Self.noonUTC.addingTimeInterval(11.5 * 3_600)

        #expect(DayTitle.text(for: lateSaturdayUTC, in: Self.calendar("en_GB", zone: "Pacific/Auckland")) == "Sunday 18 October")
        #expect(DayTitle.text(for: lateSaturdayUTC, in: Self.calendar("en_GB", zone: "America/Los_Angeles")) == "Saturday 17 October")
    }

    @Test("A Buddhist calendar still prints weekday, day and month, which carry no year")
    func nonGregorianCalendar() {
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.locale = Locale(identifier: "en_GB")
        buddhist.timeZone = TimeZone(identifier: "UTC")!
        #expect(DayTitle.text(for: Self.noonUTC, in: buddhist) == "Saturday 17 October")
    }

    @Test("Relative day is judged in the calendar's zone, not by 24 hours")
    func accessibilityRelativeDayInZone() {
        let auckland = Self.calendar("en_GB", zone: "Pacific/Auckland")
        let now = Self.noonUTC.addingTimeInterval(-30 * 60)
        let saturdayNight = now.addingTimeInterval(-90 * 60)
        let sundayLate = now.addingTimeInterval(23 * 3_600)
        let mondayEarly = now.addingTimeInterval(24 * 3_600)

        #expect(DayTitle.accessibilityLabel(for: saturdayNight, now: now, in: auckland) == "Yesterday, Saturday 17 October")
        #expect(DayTitle.accessibilityLabel(for: sundayLate, now: now, in: auckland) == "Today, Sunday 18 October")
        #expect(DayTitle.accessibilityLabel(for: mondayEarly, now: now, in: auckland) == "Tomorrow, Monday 19 October")
    }

    @Test("Two days out has no relative prefix, in either direction")
    func noPrefixBeyondOneDay() {
        let calendar = Self.calendar("en_GB")
        let now = Self.noonUTC
        #expect(DayTitle.accessibilityLabel(for: now.addingTimeInterval(2 * 86_400), now: now, in: calendar) == "Monday 19 October")
        #expect(DayTitle.accessibilityLabel(for: now.addingTimeInterval(-2 * 86_400), now: now, in: calendar) == "Thursday 15 October")
    }
}

@Suite("Ambient future log limit")
@MainActor
struct AmbientFutureLogLimitTests {
    @Test("Today and three days out are inside the limit", arguments: [0, 3])
    func insideTheLimit(days: Int) {
        let date = Calendar.current.date(byAdding: .day, value: days, to: Date())!
        #expect(date.isAtFutureLogLimit == false)
    }

    @Test("Eight and thirty days out are at or past the limit", arguments: [8, 30])
    func pastTheLimit(days: Int) {
        let date = Calendar.current.date(byAdding: .day, value: days, to: Date())!
        #expect(date.isAtFutureLogLimit)
    }

    @Test("A past day is never at the future limit")
    func pastDay() {
        let date = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        #expect(date.isAtFutureLogLimit == false)
    }
}

@Suite("Decimal input and number formatting edges")
@MainActor
struct DecimalInputLocaleEdgeTests {
    @Test(
        "Keypad shapes with a leading or trailing separator, or a sign, still parse",
        arguments: [
            (".5", 0.5), (",5", 0.5), ("5.", 5.0), ("5,", 5.0), ("+3", 3.0), ("-0,25", -0.25),
            ("\t42\t", 42.0), ("007", 7.0),
        ]
    )
    func keypadShapesParse(text: String, expected: Double) {
        #expect(text.decimalInputValue == expected)
    }

    @Test("A comma is read as the decimal point, so 1,000 is one")
    func commaIsNeverGrouping() {
        #expect("1,000".decimalInputValue == 1.0)
        #expect("1.000".decimalInputValue == 1.0)
    }

    @Test(
        "Text a keypad cannot produce is rejected",
        arguments: [
            ".", ",", "+", "-", "+-1", "1.000,5", "1,000.5", "\u{2212}5", "１２", "5\n", "\n5", "5 g",
        ]
    )
    func nonKeypadTextIsRejected(text: String) {
        #expect(text.decimalInputValue == nil)
    }

    @Test(
        "Body weight is pointed for the locale and always shows its tenth",
        arguments: [
            ("en_US", 72.5, "72.5 kg"),
            ("da_DK", 72.5, "72,5 kg"),
            ("de_DE", 80.0, "80,0 kg"),
            ("en_GB", 66.66, "66.7 kg"),
            ("en_US", 1_234.5, "1,234.5 kg"),
        ]
    )
    func kilograms(locale: String, value: Double, expected: String) {
        #expect(value.kilogramsFormatted(locale: Locale(identifier: locale)) == expected)
    }

    @Test(
        "Grams take the locale's separators and drop a zero tenth",
        arguments: [
            ("de_DE", 12.25, "12,3 g"),
            ("de_DE", 2_000.0, "2.000 g"),
            ("fr_FR", 0.04, "0 g"),
            ("en_US", 0.05, "0.1 g"),
        ]
    )
    func spacedGrams(locale: String, value: Double, expected: String) {
        let formatted = value.spacedMacroFormatted(locale: Locale(identifier: locale))
        #expect(formatted.replacingOccurrences(of: "\u{202F}", with: " ") == expected)
    }

    @Test(
        "Sentence case keeps the first letter's case rule and lowers the rest",
        arguments: [
            ("ÉCLAIR AU CHOCOLAT", "Éclair au chocolat"),
            ("alcohol", "Alcohol"),
            ("Moderately Active", "Moderately active"),
            ("x", "X"),
        ]
    )
    func sentenceCase(text: String, expected: String) {
        #expect(text.sentenceCased == expected)
    }

    @Test("Sentence case does not keep acronyms, as its documentation warns")
    func sentenceCaseFlattensAcronyms() {
        #expect("BMR Target".sentenceCased == "Bmr target")
    }
}

@Suite("Selected day rollover in an injected zone")
@MainActor
struct SelectedDayRolloverZoneTests {
    private static let auckland: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Pacific/Auckland")!
        return calendar
    }()

    private static func aucklandDate(_ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        auckland.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    @Test("Midnight in the injected zone rolls a selection that was on the old day")
    func rollsAtTheZonesMidnight() {
        let saturday = Self.aucklandDate(17)
        let result = SelectedDayRollover.selectedDay(
            selected: saturday.addingTimeInterval(9 * 3_600),
            lastKnownToday: saturday,
            now: Self.aucklandDate(18, 0, 5),
            calendar: Self.auckland
        )
        #expect(result == Self.aucklandDate(18))
    }

    @Test("Before the zone's midnight nothing rolls, even though UTC is already on another day")
    func doesNotRollBeforeTheZonesMidnight() {
        let saturday = Self.aucklandDate(17)
        let selected = saturday.addingTimeInterval(3_600)
        let result = SelectedDayRollover.selectedDay(
            selected: selected,
            lastKnownToday: saturday,
            now: Self.aucklandDate(17, 23, 55),
            calendar: Self.auckland
        )
        #expect(result == selected)
    }

    @Test("A selection the user moved to another day survives the rollover")
    func navigatedSelectionSurvives() {
        let saturday = Self.aucklandDate(17)
        let earlier = Self.aucklandDate(12)
        let result = SelectedDayRollover.selectedDay(
            selected: earlier,
            lastKnownToday: saturday,
            now: Self.aucklandDate(18, 7),
            calendar: Self.auckland
        )
        #expect(result == earlier)
    }
}
