import Foundation

struct HistoryCalorieTrendCardSummary: Equatable {
    let range: HistoryRange
    let dailyCalorieTarget: Int
    let totalDayCount: Int
    let loggedDayCount: Int
    let onTrackLoggedDayCount: Int
    let hasLoggedData: Bool
    let averageCaloriesPerLoggedDay: Double
    let averageTargetPerLoggedDay: Int
    let totalCalories: Double
    let loggedDayTargetTotal: Int

    init(
        range: HistoryRange,
        dailyCalorieTarget: Int,
        totalDayCount: Int,
        loggedDayCount: Int,
        onTrackLoggedDayCount: Int,
        hasLoggedData: Bool,
        averageCaloriesPerLoggedDay: Double,
        averageTargetPerLoggedDay: Int,
        totalCalories: Double,
        loggedDayTargetTotal: Int
    ) {
        self.range = range
        self.dailyCalorieTarget = dailyCalorieTarget
        self.totalDayCount = totalDayCount
        self.loggedDayCount = loggedDayCount
        self.onTrackLoggedDayCount = onTrackLoggedDayCount
        self.hasLoggedData = hasLoggedData
        self.averageCaloriesPerLoggedDay = averageCaloriesPerLoggedDay
        self.averageTargetPerLoggedDay = averageTargetPerLoggedDay
        self.totalCalories = totalCalories
        self.loggedDayTargetTotal = loggedDayTargetTotal
    }

    var averageValueText: String {
        averageCaloriesPerLoggedDay.rounded().truncatedSafely.formatted()
    }

    var totalValueText: String {
        totalCalories.rounded().truncatedSafely.formatted()
    }

    var onTrackRatioText: String {
        "\(onTrackLoggedDayCount)/\(loggedDayCount)"
    }

    var totalSupportText: String? {
        guard hasLoggedData else { return nil }

        let total = "\(totalValueText) kcal logged"
        let difference = totalCalories.roundedCalories - loggedDayTargetTotal
        if difference > 0 { return "\(total), \(difference.formatted()) over your goals" }
        if difference < 0 { return "\(total), \(abs(difference).formatted()) under your goals" }
        return "\(total), right on your goals"
    }

    var chartAccessibilityLabel: String {
        guard hasLoggedData else {
            return "Calorie trend for \(range.label). 0 of \(totalDayCount) days logged. Target \(dailyCalorieTarget) calories."
        }

        return "Calorie trend for \(range.label). \(loggedDayCount) of \(totalDayCount) days logged. Average \(averageCaloriesPerLoggedDay.rounded().truncatedSafely) calories per logged day. Target \(dailyCalorieTarget) calories."
    }

    static func detailChartAccessibilityLabel(
        range: HistoryRange,
        loggedDayCount: Int,
        totalDayCount: Int
    ) -> String {
        "Detailed calorie trend for \(range.label). \(loggedDayCount) of \(totalDayCount) days logged."
    }
}
