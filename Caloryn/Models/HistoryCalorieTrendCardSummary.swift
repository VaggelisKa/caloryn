import Foundation

struct HistoryCalorieTrendCardSummary: Equatable {
    let range: HistoryRange
    let dailyCalorieTarget: Int
    let totalDayCount: Int
    let loggedDayCount: Int
    let hasLoggedData: Bool
    let averageCaloriesPerLoggedDay: Double

    init(
        range: HistoryRange,
        dailyCalorieTarget: Int,
        totalDayCount: Int,
        loggedDayCount: Int,
        hasLoggedData: Bool,
        averageCaloriesPerLoggedDay: Double
    ) {
        self.range = range
        self.dailyCalorieTarget = dailyCalorieTarget
        self.totalDayCount = totalDayCount
        self.loggedDayCount = loggedDayCount
        self.hasLoggedData = hasLoggedData
        self.averageCaloriesPerLoggedDay = averageCaloriesPerLoggedDay
    }

    var chartAccessibilityLabel: String {
        let goal = "Goal \(dailyCalorieTarget.formatted()) calories."
        guard hasLoggedData else {
            return "Calorie trend for \(range.label). 0 of \(totalDayCount) days logged. \(goal)"
        }

        let average = averageCaloriesPerLoggedDay.roundedCalories.formatted()
        return "Calorie trend for \(range.label). \(loggedDayCount) of \(totalDayCount) days logged. Average \(average) calories per logged day. \(goal)"
    }
}
