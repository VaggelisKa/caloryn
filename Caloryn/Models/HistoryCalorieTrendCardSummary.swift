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

    var onTrackRatioText: String {
        "\(onTrackLoggedDayCount)/\(loggedDayCount)"
    }

    struct TotalSupport: Equatable {
        let emphasis: String
        let remainder: String

        var text: String { emphasis + remainder }
    }

    var totalSupport: TotalSupport? {
        guard hasLoggedData else { return nil }

        let difference = totalCalories.roundedCalories - loggedDayTargetTotal
        let amount = "\(difference.magnitude.formatted()) kcal"
        if difference > 0 { return TotalSupport(emphasis: "+\(amount)", remainder: " over goal in total") }
        if difference < 0 { return TotalSupport(emphasis: amount, remainder: " under goal in total") }
        return TotalSupport(emphasis: "Right on goal", remainder: " in total")
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
