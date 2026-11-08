import Foundation

struct HistoryPatternDiscovery {
    let calorieTrend: HistoryCalorieTrendProjection
    let macroPatterns: HistoryMacroPatternsProjection

    init(analytics: HistoryAnalytics, today: Date) {
        calorieTrend = HistoryCalorieTrendProjection(
            range: analytics.range,
            summary: analytics.current,
            today: today
        )
        macroPatterns = HistoryMacroPatternsProjection(patterns: analytics.macroPatterns)
    }
}

struct HistoryMacroPatternsProjection {
    let patterns: [HistoryMacroPattern]
}

struct HistoryCalorieTrendProjection {
    let range: HistoryRange
    let dailyCalorieTarget: Int
    let totalDayCount: Int
    let loggedDayCount: Int
    let averageCaloriesPerLoggedDay: Double
    let points: [HistoryCalorieTrendPoint]

    init(range: HistoryRange, summary: HistoryPeriodSummary, today: Date) {
        let calendar = summary.calendar
        self.range = range
        dailyCalorieTarget = summary.dailyCalorieTarget
        totalDayCount = summary.totalDayCount
        loggedDayCount = summary.loggedDayCount
        averageCaloriesPerLoggedDay = summary.averageCaloriesPerLoggedDay

        switch range {
        case .quarter:
            let weekAxis = HistoryWeekAxis(
                weekStarts: summary.weeklyRollups.map(\.startDate),
                calendar: calendar,
                today: today
            ).weeks
            points = summary.weeklyRollups.enumerated().map { offset, week in
                let averageCalories = week.averageCaloriesPerLoggedDay
                let status = HistoryGoalStatus.calorieStatus(
                    calories: averageCalories,
                    loggedCount: week.loggedDays,
                    targetCalories: week.targetPerLoggedDay
                )
                let startText = week.startDate.dayMonthFormatted(in: calendar)

                return HistoryCalorieTrendPoint(
                    id: "week-\(week.id.ISO8601Format())",
                    index: Double(offset),
                    value: averageCalories,
                    status: status,
                    isLogged: week.loggedDays > 0,
                    xAxisLabel: weekAxis[offset].label ?? "",
                    accessibilityLabel: "Week of \(startText)",
                    accessibilityValue: week.loggedDays == 0
                        ? "No calories logged"
                        : "\(averageCalories.rounded().truncatedSafely) average calories per logged day, \(status.label)"
                )
            }
        case .week, .twoWeeks, .month:
            points = summary.days.enumerated().map { offset, day in
                HistoryCalorieTrendPoint(
                    id: "day-\(day.id.ISO8601Format())",
                    index: Double(offset),
                    value: day.calories,
                    status: day.status,
                    isLogged: day.isLogged,
                    xAxisLabel: Self.dayAxisLabel(for: day.date, range: range, calendar: calendar),
                    accessibilityLabel: day.date.shortFormatted(in: calendar),
                    accessibilityValue: day.isLogged
                        ? "\(day.calories.rounded().truncatedSafely) calories, \(day.status.label)"
                        : "No calories logged"
                )
            }
        }
    }

    var hasLoggedData: Bool {
        points.contains(where: \.isLogged)
    }

    var yAxisUpperBound: Double {
        let largestChartValue = points.map(\.value).max() ?? 0
        let largestReference = max(largestChartValue, Double(dailyCalorieTarget), averageCaloriesPerLoggedDay, 1)
        return largestReference * 1.15
    }

    var cardSummary: HistoryCalorieTrendCardSummary {
        HistoryCalorieTrendCardSummary(
            range: range,
            dailyCalorieTarget: dailyCalorieTarget,
            totalDayCount: totalDayCount,
            loggedDayCount: loggedDayCount,
            hasLoggedData: hasLoggedData,
            averageCaloriesPerLoggedDay: averageCaloriesPerLoggedDay
        )
    }

    /// Non-finite indices are rejected rather than truncated: `truncatedSafely`
    /// answers 0 for NaN and the infinities, which would silently label the
    /// first day for an axis value that means nothing.
    func point(for index: Double) -> HistoryCalorieTrendPoint? {
        guard index.isFinite else { return nil }
        let roundedIndex = index.rounded().truncatedSafely
        guard points.indices.contains(roundedIndex) else { return nil }
        return points[roundedIndex]
    }

    private static func dayAxisLabel(for date: Date, range: HistoryRange, calendar: Calendar) -> String {
        guard range == .month else { return date.weekdayInitial(in: calendar) }
        let isMonday = calendar.component(.weekday, from: date) == 2
        return isMonday ? date.dayMonthFormatted(in: calendar) : ""
    }
}

struct HistoryCalorieTrendPoint: Identifiable {
    let id: String
    let index: Double
    let value: Double
    let status: HistoryGoalStatus
    let isLogged: Bool
    let xAxisLabel: String
    let accessibilityLabel: String
    let accessibilityValue: String
}
