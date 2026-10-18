import Foundation

/// The heading for one calendar day: "Friday 17 October" on Today's date row and as the
/// Nutrition Details sheet's title.
///
/// The printed title is the date even when the day is today — the date row says which day,
/// the chevrons beside it move between days — but VoiceOver hears "Today, Friday 17 October",
/// so the relative day the old "Today" heading carried is not lost to anyone listening.
///
/// Every rule takes the calendar it is judged in: its locale names the weekday and month, its
/// time zone decides which day `date` falls on. Day before month, as the app's other date
/// formats are (`Date.shortFormatted`).
enum DayTitle {
    static func text(for date: Date, in calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        // `locale` first: assigning it resets `calendar` to the locale's own.
        formatter.locale = calendar.locale ?? .current
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "EEEE d MMMM"
        return formatter.string(from: date)
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
