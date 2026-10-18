import Foundation

enum SelectedDayRollover {
    static func selectedDay(
        selected: Date,
        lastKnownToday: Date,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Date {
        let today = calendar.startOfDay(for: now)
        guard !calendar.isDate(lastKnownToday, inSameDayAs: today) else { return selected }
        guard calendar.isDate(selected, inSameDayAs: lastKnownToday) else { return selected }
        return today
    }
}
