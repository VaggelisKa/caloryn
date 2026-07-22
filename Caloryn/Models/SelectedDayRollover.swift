import Foundation

/// Decides which day Today should show after the calendar rolls over while the
/// app stays open.
///
/// Someone sitting on the current day expects to follow the new day; someone who
/// deliberately navigated to another date should stay where they put themselves.
///
/// This matters beyond presentation: `DailyGoalSnapshotStore` only records the
/// current calendar day, so a `selectedDate` left on yesterday means the new day
/// never gets a goal snapshot and History falls back to its estimate.
enum SelectedDayRollover {
    /// The day to select, given the day the app last treated as current.
    static func selectedDay(
        selected: Date,
        lastKnownToday: Date,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Date {
        let today = calendar.startOfDay(for: now)
        // Nothing rolled over.
        guard !calendar.isDate(lastKnownToday, inSameDayAs: today) else { return selected }
        // The user had navigated away, so leave their choice alone.
        guard calendar.isDate(selected, inSameDayAs: lastKnownToday) else { return selected }
        return today
    }
}
