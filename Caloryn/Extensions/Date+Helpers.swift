import Foundation

/// Day/week derivation and the short date formats used across the app.
///
/// Every rule here is defined against an **injected** `Calendar`. The calendar
/// carries the whole formatting context — its `timeZone` decides which calendar
/// day an instant falls on, and its `locale` decides how `EEE`/`MMM` render —
/// so one parameter is enough to pin behaviour under a foreign time zone, a
/// foreign week-start convention or a non-Gregorian calendar.
///
/// The no-argument properties are the ambient (`Calendar.current`) spellings and
/// exist only so call sites need not change. They delegate; there is exactly one
/// derivation of each rule.
extension Date {
    var startOfDay: Date {
        startOfDay(in: .current)
    }

    func startOfDay(in calendar: Calendar) -> Date {
        calendar.startOfDay(for: self)
    }

    var yesterday: Date {
        yesterday(in: .current)
    }

    func yesterday(in calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: -1, to: self) ?? self
    }

    var tomorrow: Date {
        tomorrow(in: .current)
    }

    func tomorrow(in calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: 1, to: self) ?? self
    }

    var isToday: Bool {
        isToday(in: .current)
    }

    func isToday(in calendar: Calendar) -> Bool {
        calendar.isDateInToday(self)
    }

    /// True when this date is at or beyond the max future log day (7 days from today).
    var isAtFutureLogLimit: Bool {
        isAtFutureLogLimit(from: .now, in: .current)
    }

    func isAtFutureLogLimit(from now: Date, in calendar: Calendar) -> Bool {
        daysFrom(now, in: calendar) >= 7
    }

    var shortFormatted: String {
        shortFormatted(in: .current)
    }

    func shortFormatted(in calendar: Calendar) -> String {
        if isToday(in: calendar) { return "Today" }
        if calendar.isDateInYesterday(self) { return "Yesterday" }
        return formatted(pattern: "EEE, d MMM", in: calendar)
    }

    var dayMonthFormatted: String {
        dayMonthFormatted(in: .current)
    }

    func dayMonthFormatted(in calendar: Calendar) -> String {
        formatted(pattern: "d MMM", in: calendar)
    }

    var shortWeekday: String {
        shortWeekday(in: .current)
    }

    func shortWeekday(in calendar: Calendar) -> String {
        formatted(pattern: "EEE", in: calendar)
    }

    /// Single-letter weekday label ("S M T W T F S"), indexed by the calendar's
    /// own weekday numbering.
    func weekdayInitial(in calendar: Calendar) -> String {
        let weekday = calendar.component(.weekday, from: self)
        return ["S", "M", "T", "W", "T", "F", "S"][max(0, min(weekday - 1, 6))]
    }

    func daysFrom(_ other: Date, in calendar: Calendar = .current) -> Int {
        calendar.dateComponents(
            [.day],
            from: other.startOfDay(in: calendar),
            to: startOfDay(in: calendar)
        ).day ?? 0
    }

    static func datesInRange(from start: Date, days: Int, in calendar: Calendar = .current) -> [Date] {
        (0..<days).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: start.startOfDay(in: calendar))
        }
    }

    var startOfWeek: Date {
        startOfWeek(in: .current)
    }

    /// The Monday of this date's week.
    ///
    /// Deliberately Monday-based regardless of the calendar's `firstWeekday`:
    /// weekly rollups in History are defined as Mon-Sun, not as the user's
    /// locale week. The injected calendar still supplies the time zone and
    /// calendar identity.
    func startOfWeek(in calendar: Calendar) -> Date {
        var cal = calendar
        cal.firstWeekday = 2 // Monday
        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return (cal.date(from: components) ?? self).startOfDay(in: cal)
    }

    static func datesForCurrentWeek(from now: Date = .now, in calendar: Calendar = .current) -> [Date] {
        let monday = now.startOfWeek(in: calendar)
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: monday)
        }
    }

    private func formatted(pattern: String, in calendar: Calendar) -> String {
        let formatter = DateFormatter()
        // Order matters: assigning `locale` resets `calendar` to that locale's
        // calendar, so the calendar has to be set afterwards or a non-Gregorian
        // one is silently discarded.
        formatter.locale = calendar.locale ?? .current
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = pattern
        return formatter.string(from: self)
    }
}
