import Foundation

/// One scheduled daily-reminder notification: a stable per-day identifier,
/// local wall-clock fire components, and the finished message. The remaining
/// count lives in the title because iOS renders titles bold and bodies plain.
struct PlannedReminder: Hashable {
    let identifier: String
    let fireDateComponents: DateComponents
    let title: String
    let body: String
}

/// Pure planning logic for the daily remaining-calories reminder (issue #60).
/// Local notification content is baked in at scheduling time, so the caller
/// re-plans whenever the log or the reminder settings change.
enum DailyReminderPlanner {
    /// All daily-reminder identifiers share this prefix so the scheduler can
    /// clear stale requests without touching unrelated notifications.
    static let identifierPrefix = "daily-reminder"
    /// Below this the reminder is noise, not help (issue #60 discussion).
    static let minimumRemainingKcal = 100
    static let defaultReminderMinutes = 21 * 60
    /// Today plus six future days keeps reminders flowing when the app
    /// isn't opened every day.
    static let planHorizonDays = 7

    /// Today's remaining calories, as the reminder title states them. Lives
    /// here rather than in `DailyReminderBridge` so the arithmetic can be
    /// driven with a number no view would ever be asked to render.
    static func remainingToday(target: Int, consumed: Double) -> Int {
        max(0, CalorieDomain.clamped(target) - consumed.roundedCalories)
    }

    static func makePlan(
        isEnabled: Bool,
        remainingToday: Int?,
        fullDayTarget: Int?,
        reminderMinutesFromMidnight: Int = defaultReminderMinutes,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [PlannedReminder] {
        guard isEnabled, let fullDayTarget, fullDayTarget > 0 else { return [] }

        let hour = reminderMinutesFromMidnight / 60
        let minute = reminderMinutesFromMidnight % 60
        let todayStart = calendar.startOfDay(for: now)

        return (0..<planHorizonDays).compactMap { dayOffset in
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: todayStart),
                  let fireDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                  fireDate > now else {
                return nil
            }

            // Future days have no logged meals yet, so if the app never opens
            // again the full target is the correct remaining amount.
            let remaining = dayOffset == 0 ? (remainingToday ?? fullDayTarget) : fullDayTarget
            guard remaining >= minimumRemainingKcal else { return nil }

            return PlannedReminder(
                identifier: identifier(for: day, calendar: calendar),
                fireDateComponents: calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: fireDate
                ),
                title: "🔥 \(remaining) calories to go",
                body: "There's still time to log a meal and reach today's goal."
            )
        }
    }

    static func identifier(for day: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: day)
        return String(
            format: "%@-%04d-%02d-%02d",
            identifierPrefix,
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}
