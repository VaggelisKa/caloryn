import Foundation

enum DayTitle {
    static func text(for date: Date, in calendar: Calendar = .current) -> String {
        date.formatted(pattern: "EEEE d MMMM", in: calendar)
    }

    static func accessibilityLabel(
        for date: Date,
        now: Date = .now,
        in calendar: Calendar = .current
    ) -> String {
        let title = text(for: date, in: calendar)
        if calendar.isDate(date, inSameDayAs: now) {
            return "Today, \(title)"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "Yesterday, \(title)"
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           calendar.isDate(date, inSameDayAs: tomorrow) {
            return "Tomorrow, \(title)"
        }
        return title
    }
}
