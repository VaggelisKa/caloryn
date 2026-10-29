import Foundation

struct HistoryCalorieTrendCardSummary: Equatable {
    let range: HistoryRange
    let dailyCalorieTarget: Int
    let totalDayCount: Int
    let loggedDayCount: Int
    let hasLoggedData: Bool
    let averageCaloriesPerLoggedDay: Double
    let totalCalories: Double
    let loggedDayTargetTotal: Int

    init(
        range: HistoryRange,
        dailyCalorieTarget: Int,
        totalDayCount: Int,
        loggedDayCount: Int,
        hasLoggedData: Bool,
        averageCaloriesPerLoggedDay: Double,
        totalCalories: Double,
        loggedDayTargetTotal: Int
    ) {
        self.range = range
        self.dailyCalorieTarget = dailyCalorieTarget
        self.totalDayCount = totalDayCount
        self.loggedDayCount = loggedDayCount
        self.hasLoggedData = hasLoggedData
        self.averageCaloriesPerLoggedDay = averageCaloriesPerLoggedDay
        self.totalCalories = totalCalories
        self.loggedDayTargetTotal = loggedDayTargetTotal
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
        if difference > 0 { return TotalSupport(emphasis: amount, remainder: " over goal in total") }
        if difference < 0 { return TotalSupport(emphasis: amount, remainder: " under goal in total") }
        return TotalSupport(emphasis: "Right on goal", remainder: " in total")
    }

    var chartAccessibilityLabel: String {
        let goal = "Goal \(dailyCalorieTarget.formatted()) calories."
        guard hasLoggedData else {
            return "Calorie trend for \(range.label). 0 of \(totalDayCount) days logged. \(goal)"
        }

        let average = averageCaloriesPerLoggedDay.roundedCalories.formatted()
        return "Calorie trend for \(range.label). \(loggedDayCount) of \(totalDayCount) days logged. Average \(average) calories per logged day. \(goal)"
    }

    static func detailChartAccessibilityLabel(
        range: HistoryRange,
        loggedDayCount: Int,
        totalDayCount: Int
    ) -> String {
        "Detailed calorie trend for \(range.label). \(loggedDayCount) of \(totalDayCount) days logged."
    }
}

struct HistoryCalorieTrendRangeStats: Equatable {
    let averageCaloriesPerLoggedDay: Double
    let loggedDayCount: Int
    let onTrackLoggedDayCount: Int
    let totalTargetDelta: Int

    var average: HistoryCalorieTrendStat {
        HistoryCalorieTrendStat(
            value: averageCaloriesPerLoggedDay.roundedCalories.formatted(),
            label: "kcal a day on average"
        )
    }

    var onTrack: HistoryCalorieTrendStat {
        HistoryCalorieTrendStat(value: "\(onTrackLoggedDayCount) of \(loggedDayCount)", label: "logged days on track")
    }

    var totalDelta: HistoryCalorieTrendStat {
        let value = totalTargetDelta.magnitude.formatted()
        if totalTargetDelta > 0 {
            return HistoryCalorieTrendStat(value: value, label: "kcal over goal in total")
        }
        if totalTargetDelta < 0 {
            return HistoryCalorieTrendStat(value: value, label: "kcal under goal in total")
        }
        return HistoryCalorieTrendStat(value: value, label: "kcal off goal in total", spokenLabel: "Right on goal in total")
    }

    var stats: [HistoryCalorieTrendStat] {
        [average, onTrack, totalDelta]
    }
}
