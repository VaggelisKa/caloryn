import Foundation

enum DayCalorieTarget {
    static func calories(
        for day: Date,
        today: Date,
        currentTarget: Int,
        savedTargets: HistoryDayTargetResolver,
        calendar: Calendar = .current
    ) -> Int {
        guard calendar.startOfDay(for: day) < calendar.startOfDay(for: today) else { return currentTarget }
        return savedTargets.target(for: day, calendar: calendar).calories
    }
}
