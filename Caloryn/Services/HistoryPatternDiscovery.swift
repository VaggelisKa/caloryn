import Foundation

struct HistoryPatternDiscovery {
    let calorieTrend: HistoryCalorieTrendProjection
    let macroPatterns: HistoryMacroPatternsProjection
    let weeklyConsistency: HistoryWeeklyConsistencyProjection

    init(analytics: HistoryAnalytics, today: Date) {
        calorieTrend = HistoryCalorieTrendProjection(
            range: analytics.range,
            summary: analytics.current,
            today: today
        )
        macroPatterns = HistoryMacroPatternsProjection(patterns: analytics.macroPatterns)
        weeklyConsistency = HistoryWeeklyConsistencyProjection(summary: analytics.current, today: today)
    }
}

struct HistoryMacroPatternsProjection {
    let patterns: [HistoryMacroPattern]
}

struct HistoryWeeklyConsistencyProjection {
    let weeks: [HistoryWeekSummary]
    let loggedDayCount: Int
    let totalDayCount: Int
    let calendar: Calendar
    let today: Date

    init(summary: HistoryPeriodSummary, today: Date = .now) {
        weeks = summary.weeklyRollups
        loggedDayCount = summary.loggedDayCount
        totalDayCount = summary.totalDayCount
        calendar = summary.calendar
        self.today = today
    }

    var chart: HistoryWeeklyConsistencyChart {
        HistoryWeeklyConsistencyChart(
            tallies: weeks.map { week in
                HistoryWeeklyConsistencyChart.Tally(
                    startDate: week.startDate,
                    onTrackDays: week.onTrackDays,
                    loggedDays: week.loggedDays
                )
            },
            calendar: calendar,
            today: today
        )
    }
}

struct HistoryCalorieTrendProjection {
    let range: HistoryRange
    /// Taken from the summary rather than accepted as a parameter: a defaulted
    /// `calendar: Calendar = .current` silently succeeded at the wrong answer
    /// whenever a caller forgot it, which is exactly how the detail screen came
    /// to label foreign-zone days from the host calendar.
    let calendar: Calendar
    let dailyCalorieTarget: Int
    let totalDayCount: Int
    let loggedDayCount: Int
    let onTrackLoggedDayCount: Int
    let averageCaloriesPerLoggedDay: Double
    let averageTargetPerLoggedDay: Int
    let loggedDayTargetTotal: Int
    let hasEstimatedTargets: Bool
    let totalCalories: Double
    let furthestFromGoal: HistoryCalorieTrendFurthestFromGoal?
    let points: [HistoryCalorieTrendPoint]

    init(range: HistoryRange, summary: HistoryPeriodSummary, today: Date) {
        let calendar = summary.calendar
        self.range = range
        self.calendar = calendar
        dailyCalorieTarget = summary.dailyCalorieTarget
        totalDayCount = summary.totalDayCount
        loggedDayCount = summary.loggedDayCount
        onTrackLoggedDayCount = summary.onTrackLoggedDayCount
        averageCaloriesPerLoggedDay = summary.averageCaloriesPerLoggedDay
        averageTargetPerLoggedDay = summary.averageTargetPerLoggedDay
        loggedDayTargetTotal = summary.loggedDayTargetTotal
        hasEstimatedTargets = summary.hasEstimatedTargets
        totalCalories = summary.days
            .filter(\.isLogged)
            .reduce(0) { $0 + $1.calories }
        furthestFromGoal = Self.furthestFromGoal(
            range: range,
            summary: summary,
            calendar: calendar
        )

        switch range {
        case .quarter:
            let weekAxis = HistoryWeeklyConsistencyProjection(summary: summary, today: today).chart.weeks
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
                    targetDelta: averageCalories.roundedCalories - week.targetPerLoggedDay,
                    status: status,
                    isLogged: week.loggedDays > 0,
                    xAxisLabel: weekAxis[offset].axisLabel ?? "",
                    accessibilityLabel: "Week of \(startText)",
                    accessibilityValue: week.loggedDays == 0
                        ? "No calories logged"
                        : "\(averageCalories.rounded().truncatedSafely) average calories per logged day, \(status.label)",
                    selection: .week(week)
                )
            }
        case .week, .twoWeeks, .month:
            points = summary.days.enumerated().map { offset, day in
                HistoryCalorieTrendPoint(
                    id: "day-\(day.id.ISO8601Format())",
                    index: Double(offset),
                    value: day.calories,
                    targetDelta: day.calorieDifference,
                    status: day.status,
                    isLogged: day.isLogged,
                    xAxisLabel: Self.dayAxisLabel(for: day.date, range: range, calendar: calendar),
                    accessibilityLabel: day.date.shortFormatted(in: calendar),
                    accessibilityValue: day.isLogged
                        ? "\(day.calories.rounded().truncatedSafely) calories, \(day.status.label)"
                        : "No calories logged",
                    selection: .day(day)
                )
            }
        }
    }

    var hasLoggedData: Bool {
        loggedPointCount > 0
    }

    var loggedPointCount: Int {
        points.filter(\.isLogged).count
    }

    var canDrillDown: Bool {
        // Gated on logged days, not plotted points: in the 90-day range a point is a calendar
        // week, so three days logged inside one week left the only data the user had unreachable.
        loggedDayCount >= 2
    }

    var yAxisUpperBound: Double {
        let largestChartValue = points.map(\.value).max() ?? 0
        let largestReference = max(largestChartValue, Double(dailyCalorieTarget), averageCaloriesPerLoggedDay, 1)
        return largestReference * 1.15
    }

    var totalTargetDelta: Int {
        totalCalories.roundedCalories - loggedDayTargetTotal
    }

    var estimatedTargetNoteText: String? {
        guard hasEstimatedTargets else { return nil }
        return "Days without a saved daily goal are compared with the goal in effect around then."
    }

    var rangeStats: HistoryCalorieTrendRangeStats {
        HistoryCalorieTrendRangeStats(
            averageCaloriesPerLoggedDay: averageCaloriesPerLoggedDay,
            loggedDayCount: loggedDayCount,
            onTrackLoggedDayCount: onTrackLoggedDayCount,
            totalTargetDelta: totalTargetDelta
        )
    }

    var cardSummary: HistoryCalorieTrendCardSummary {
        HistoryCalorieTrendCardSummary(
            range: range,
            dailyCalorieTarget: dailyCalorieTarget,
            totalDayCount: totalDayCount,
            loggedDayCount: loggedDayCount,
            hasLoggedData: hasLoggedData,
            averageCaloriesPerLoggedDay: averageCaloriesPerLoggedDay,
            totalCalories: totalCalories,
            loggedDayTargetTotal: loggedDayTargetTotal
        )
    }

    func dayText(for date: Date) -> String {
        date.shortFormatted(in: calendar)
    }

    func weekStartText(for date: Date) -> String {
        date.dayMonthFormatted(in: calendar)
    }

    /// Non-finite indices are rejected rather than truncated: `truncatedSafely`
    /// answers 0 for NaN and the infinities, which would silently select the
    /// first day for a gesture value that means nothing. The equivalent
    /// `HistoryChartIndexAxis.slot(for:)` draws the same line.
    func point(for index: Double) -> HistoryCalorieTrendPoint? {
        guard index.isFinite else { return nil }
        let roundedIndex = index.rounded().truncatedSafely
        guard points.indices.contains(roundedIndex) else { return nil }
        return points[roundedIndex]
    }

    func topFoods(for selection: HistoryCalorieTrendSelection) -> [HistoryFoodSummary] {
        switch selection {
        case .day(let day):
            day.makeDetail().topFoods
        case .week(let week):
            topFoods(for: week)
        }
    }

    private static func furthestFromGoal(
        range: HistoryRange,
        summary: HistoryPeriodSummary,
        calendar: Calendar
    ) -> HistoryCalorieTrendFurthestFromGoal? {
        switch range {
        case .quarter:
            let loggedWeeks = summary.weeklyRollups.filter { $0.loggedDays > 0 }
            guard let week = loggedWeeks.max(by: { lhs, rhs in
                abs(weeklyDelta(lhs, target: lhs.targetPerLoggedDay))
                    < abs(weeklyDelta(rhs, target: rhs.targetPerLoggedDay))
            }) else {
                return nil
            }

            return HistoryCalorieTrendFurthestFromGoal(
                periodText: "week of \(week.startDate.dayMonthFormatted(in: calendar))",
                calorieDifference: weeklyDelta(week, target: week.targetPerLoggedDay),
                period: .week
            )

        case .week, .twoWeeks, .month:
            let loggedDays = summary.days.filter(\.isLogged)
            guard let day = loggedDays.max(by: { lhs, rhs in
                abs(lhs.calorieDifference) < abs(rhs.calorieDifference)
            }) else {
                return nil
            }

            return HistoryCalorieTrendFurthestFromGoal(
                periodText: day.date.shortFormatted(in: calendar),
                calorieDifference: day.calorieDifference,
                period: .day
            )
        }
    }

    private static func dayAxisLabel(for date: Date, range: HistoryRange, calendar: Calendar) -> String {
        guard range == .month else { return date.weekdayInitial(in: calendar) }
        let isMonday = calendar.component(.weekday, from: date) == 2
        return isMonday ? date.dayMonthFormatted(in: calendar) : ""
    }

    private static func weeklyDelta(_ week: HistoryWeekSummary, target: Int) -> Int {
        week.averageCaloriesPerLoggedDay.roundedCalories - target
    }

    private func topFoods(for week: HistoryWeekSummary) -> [HistoryFoodSummary] {
        var foods: [String: HistoryPatternFoodAccumulator] = [:]

        for day in week.days where day.isLogged {
            for food in day.makeDetail().topFoods {
                var accumulator = foods[food.id] ?? HistoryPatternFoodAccumulator(id: food.id, name: food.name)
                accumulator.entryCount += food.entryCount
                accumulator.portionGrams += food.portionGrams
                accumulator.calories += food.calories
                foods[food.id] = accumulator
            }
        }

        return foods.values
            .map(\.summary)
            .sorted {
                if $0.calories == $1.calories {
                    return $0.name.localizedStandardCompare($1.name) == .orderedAscending
                }
                return $0.calories > $1.calories
            }
    }
}

struct HistoryCalorieTrendPoint: Identifiable {
    let id: String
    let index: Double
    let value: Double
    let targetDelta: Int
    let status: HistoryGoalStatus
    let isLogged: Bool
    let xAxisLabel: String
    let accessibilityLabel: String
    let accessibilityValue: String
    let selection: HistoryCalorieTrendSelection
}

private struct HistoryPatternFoodAccumulator {
    let id: String
    let name: String
    var entryCount = 0
    var portionGrams: Double = 0
    var calories: Double = 0

    var summary: HistoryFoodSummary {
        HistoryFoodSummary(
            id: id,
            name: name,
            entryCount: entryCount,
            portionGrams: portionGrams,
            calories: calories
        )
    }
}
