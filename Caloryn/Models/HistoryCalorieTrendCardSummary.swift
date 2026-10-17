import Foundation

/// The numbers around the calorie-trend chart: the section's support line, the drill-down's
/// range-summary figures and the spoken description of the chart.
///
/// Takes the period facts the wording depends on rather than the projection, so
/// the empty-range wording is reachable without building a summary. The chart itself is
/// elsewhere. Differences from the goal are told in words, never by a tint.
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

    // MARK: - Figures

    var averageValueText: String {
        averageCaloriesPerLoggedDay.rounded().truncatedSafely.formatted()
    }

    var totalValueText: String {
        totalCalories.rounded().truncatedSafely.formatted()
    }

    var onTrackRatioText: String {
        "\(onTrackLoggedDayCount)/\(loggedDayCount)"
    }

    /// The line under the trend section's title: the range's logged total against the sum
    /// of the same days' own goals — "12,800 kcal logged, 800 over your goals". The daily
    /// average already leads the page, so the section carries the total instead. `nil` with
    /// nothing logged, when there is no total to state.
    var totalSupportText: String? {
        guard hasLoggedData else { return nil }

        let total = "\(totalValueText) kcal logged"
        let difference = totalCalories.roundedCalories - loggedDayTargetTotal
        if difference > 0 { return "\(total), \(difference.formatted()) over your goals" }
        if difference < 0 { return "\(total), \(abs(difference).formatted()) under your goals" }
        return "\(total), right on your goals"
    }

    // MARK: - Spoken descriptions

    /// The card's chart is one accessibility element; without it VoiceOver
    /// reads a wall of unlabelled bars.
    var chartAccessibilityLabel: String {
        guard hasLoggedData else {
            return "Calorie trend for \(range.label). 0 of \(totalDayCount) days logged. Target \(dailyCalorieTarget) calories."
        }

        return "Calorie trend for \(range.label). \(loggedDayCount) of \(totalDayCount) days logged. Average \(averageCaloriesPerLoggedDay.rounded().truncatedSafely) calories per logged day. Target \(dailyCalorieTarget) calories."
    }

    /// The drill-down's chart phrases the same sentence more briefly — the
    /// numbers are already on screen above it. It lives beside the card's so
    /// the two cannot drift apart unnoticed.
    static func detailChartAccessibilityLabel(
        range: HistoryRange,
        loggedDayCount: Int,
        totalDayCount: Int
    ) -> String {
        "Detailed calorie trend for \(range.label). \(loggedDayCount) of \(totalDayCount) days logged."
    }
}
