import Foundation

struct PlannedReminder: Hashable {
    let identifier: String
    let fireDateComponents: DateComponents
    let title: String
    let body: String
}

enum DailyReminderPlanner {
    static let identifierPrefix = "daily-reminder"
    static let minimumRemainingKcal = 100
    static let defaultReminderMinutes = 21 * 60
    static let planHorizonDays = 7

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
