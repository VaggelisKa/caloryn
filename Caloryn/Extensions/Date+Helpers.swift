import Foundation

extension Date {
    nonisolated var startOfDay: Date {
        startOfDay(in: .current)
    }

    nonisolated func startOfDay(in calendar: Calendar) -> Date {
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

    func startOfWeek(in calendar: Calendar) -> Date {
        var cal = calendar
        cal.firstWeekday = 2
        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return (cal.date(from: components) ?? self).startOfDay(in: cal)
    }

    static func datesForCurrentWeek(from now: Date = .now, in calendar: Calendar = .current) -> [Date] {
        let monday = now.startOfWeek(in: calendar)
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: monday)
        }
    }

    func formatted(pattern: String, in calendar: Calendar) -> String {
        let locale = calendar.locale ?? .current
        let key = FormatterKey(pattern: pattern, calendar: calendar, locale: locale)
        if let formatter = Self.formatterCache[key] {
            return formatter.string(from: self)
        }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = pattern
        Self.formatterCache[key] = formatter
        return formatter.string(from: self)
    }

    private struct FormatterKey: Hashable {
        let pattern: String
        let calendar: Calendar
        let locale: Locale
    }

    private static var formatterCache: [FormatterKey: DateFormatter] = [:]
}
