import Foundation

extension HistoryAverages {
    init(summary: HistoryPeriodSummary) {
        self.init(
            days: summary.days.map { day in
                Day(
                    date: day.date,
                    calories: day.calories,
                    target: day.dailyCalorieTarget,
                    isLogged: day.isLogged
                )
            },
            calendar: summary.calendar
        )
    }
}
