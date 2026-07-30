import Foundation

/// The headline numbers above the calorie-trend chart, and how they are toned.
///
/// Takes the period facts the wording depends on rather than the projection, so
/// the empty-range wording and the tone bands are reachable without building a
/// summary. The chart itself is elsewhere: this is only the two stat columns,
/// the range-summary counts and the spoken description of the chart.
struct HistoryCalorieTrendCardSummary: Equatable {
    /// How a difference-from-target line reads. The view maps these to a tint;
    /// no colour is decided here.
    enum DifferenceTone: Equatable {
        /// Nothing to compare against — no logged days, or no target.
        case neutral
        case status(HistoryGoalStatus)
    }

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

    // MARK: - Stat columns

    /// The stat columns are hidden entirely when nothing is logged, rather than
    /// shown as zeroes the reader would have to discount.
    var showsStatColumns: Bool { hasLoggedData }

    var averageValueText: String {
        averageCaloriesPerLoggedDay.rounded().truncatedSafely.formatted()
    }

    var totalValueText: String {
        totalCalories.rounded().truncatedSafely.formatted()
    }

    var onTrackRatioText: String {
        "\(onTrackLoggedDayCount)/\(loggedDayCount)"
    }

    var averageDifferenceTone: DifferenceTone {
        tone(
            value: averageCaloriesPerLoggedDay,
            target: averageTargetPerLoggedDay
        )
    }

    var totalDifferenceTone: DifferenceTone {
        tone(
            value: totalCalories,
            target: loggedDayTargetTotal
        )
    }

    /// Bands the *displayed* number, not the raw double: a value that rounds
    /// onto the target reads as on target rather than a hair over it.
    private func tone(value: Double, target: Int) -> DifferenceTone {
        guard hasLoggedData, target > 0 else { return .neutral }

        return .status(
            HistoryGoalStatus.calorieStatus(
                calories: Double(value.rounded().truncatedSafely),
                loggedCount: 1,
                targetCalories: target
            )
        )
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
