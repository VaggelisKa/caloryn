import Foundation

struct HistoryPatternDiscovery {
    let calorieTrend: HistoryCalorieTrendProjection
    let macroPatterns: HistoryMacroPatternsProjection
    let weeklyConsistency: HistoryWeeklyConsistencyProjection

    init(analytics: HistoryAnalytics) {
        calorieTrend = HistoryCalorieTrendProjection(
            range: analytics.range,
            summary: analytics.current
        )
        macroPatterns = HistoryMacroPatternsProjection(patterns: analytics.macroPatterns)
        weeklyConsistency = HistoryWeeklyConsistencyProjection(summary: analytics.current)
    }
}

struct HistoryMacroPatternsProjection {
    let patterns: [HistoryMacroPattern]

    var summaryText: String? {
        let loggedPatterns = patterns.filter { $0.current.loggedDays > 0 }
        guard let weakest = loggedPatterns.min(by: { $0.current.hitDays < $1.current.hitDays }) else {
            return nil
        }

        return "\(weakest.nutrient.compactName) was the least consistent macro at \(weakest.current.hitDays) of \(weakest.current.loggedDays) logged days."
    }
}

struct HistoryWeeklyConsistencyProjection {
    let weeks: [HistoryWeekSummary]
    let loggedDayCount: Int
    let totalDayCount: Int

    init(summary: HistoryPeriodSummary) {
        weeks = summary.weeklyRollups
        loggedDayCount = summary.loggedDayCount
        totalDayCount = summary.totalDayCount
    }

    var bestWeek: HistoryWeekSummary? {
        weeks
            .filter { $0.loggedDays > 0 }
            .max {
                if $0.onTrackRatio == $1.onTrackRatio {
                    return $0.loggedDays < $1.loggedDays
                }
                return $0.onTrackRatio < $1.onTrackRatio
            }
    }

    var headlineText: String? {
        guard let bestWeek else { return nil }
        return "Best week had \(bestWeek.onTrackDays) of \(bestWeek.loggedDays) logged \(dayLabel(for: bestWeek.loggedDays)) on track."
    }

    private func dayLabel(for count: Int) -> String {
        count == 1 ? "day" : "days"
    }
}

struct HistoryCalorieTrendProjection {
    let range: HistoryRange
    let dailyCalorieTarget: Int
    let totalDayCount: Int
    let loggedDayCount: Int
    let onTrackLoggedDayCount: Int
    let averageCaloriesPerLoggedDay: Double
    let averageTargetPerLoggedDay: Int
    let loggedDayTargetTotal: Int
    let hasEstimatedTargets: Bool
    let totalCalories: Double
    let biggestInconsistencyText: String?
    let points: [HistoryCalorieTrendPoint]

    init(range: HistoryRange, summary: HistoryPeriodSummary) {
        self.range = range
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
        biggestInconsistencyText = Self.biggestInconsistencyText(
            range: range,
            summary: summary
        )

        switch range {
        case .quarter:
            points = summary.weeklyRollups.enumerated().map { offset, week in
                let averageCalories = week.averageCaloriesPerLoggedDay
                let status = HistoryGoalStatus.calorieStatus(
                    calories: averageCalories,
                    loggedCount: week.loggedDays,
                    targetCalories: week.targetPerLoggedDay
                )
                let label = "W\(offset + 1)"

                return HistoryCalorieTrendPoint(
                    id: "week-\(week.id.ISO8601Format())",
                    index: Double(offset),
                    value: averageCalories,
                    targetDelta: averageCalories.rounded().truncatedSafely - week.targetPerLoggedDay,
                    status: status,
                    isLogged: week.loggedDays > 0,
                    xAxisLabel: label,
                    accessibilityLabel: "\(label), week of \(week.startDate.dayMonthFormatted)",
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
                    xAxisLabel: Self.weekdayInitial(for: day.date),
                    accessibilityLabel: day.date.shortFormatted,
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

    var averageDifferenceText: String {
        guard hasLoggedData else { return "No logged days" }
        return Self.differenceText(averageCaloriesPerLoggedDay.rounded().truncatedSafely - averageTargetPerLoggedDay)
    }

    var totalDifferenceText: String {
        guard hasLoggedData else { return "No logged days" }
        return Self.differenceText(totalCalories.rounded().truncatedSafely - loggedDayTargetTotal)
    }

    var totalTargetDelta: Int {
        totalCalories.rounded().truncatedSafely - loggedDayTargetTotal
    }

    /// Shown when some days in range use the documented fallback target
    /// instead of a persisted daily goal snapshot.
    var estimatedTargetNoteText: String? {
        guard hasEstimatedTargets else { return nil }
        return "Days without a saved daily goal are compared with your current target."
    }

    var totalTargetDeltaText: String {
        if totalTargetDelta == 0 { return "On target total" }
        return "\(Self.deltaText(totalTargetDelta, unit: "kcal")) target total"
    }

    /// The point a chart-space x value falls on, or `nil` outside the series.
    ///
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

    func targetDeltaText(_ difference: Int, unit: String) -> String {
        if difference == 0 { return "On target" }
        return "\(Self.deltaText(difference, unit: unit)) target"
    }

    func averageDeltaText(value: Double, unit: String) -> String? {
        guard averageCaloriesPerLoggedDay > 0 else { return nil }

        let difference = (value - averageCaloriesPerLoggedDay).rounded().truncatedSafely
        if difference == 0 {
            return "Matches \(averageLabel) average"
        }

        return "\(abs(difference).formatted()) \(unit) \(difference > 0 ? "above" : "below") \(averageLabel) average"
    }

    static func differenceText(_ difference: Int) -> String {
        if difference > 0 { return "+\(difference.formatted()) over target" }
        if difference < 0 { return "\(abs(difference).formatted()) under target" }
        return "On target"
    }

    static func deltaText(_ difference: Int, unit: String) -> String {
        if difference == 0 { return "On target" }
        return "\(abs(difference).formatted()) \(unit) \(difference > 0 ? "over" : "under")"
    }

    private static func biggestInconsistencyText(
        range: HistoryRange,
        summary: HistoryPeriodSummary
    ) -> String? {
        switch range {
        case .quarter:
            let loggedWeeks = summary.weeklyRollups.filter { $0.loggedDays > 0 }
            guard let week = loggedWeeks.max(by: { lhs, rhs in
                abs(weeklyDelta(lhs, target: lhs.targetPerLoggedDay))
                    < abs(weeklyDelta(rhs, target: rhs.targetPerLoggedDay))
            }) else {
                return nil
            }

            if loggedWeeks.allSatisfy({
                weeklyStatus($0, target: $0.targetPerLoggedDay) == .onTrack
            }) {
                return "Most stable: logged weeks stayed near target"
            }

            return "Biggest swing: week of \(week.startDate.dayMonthFormatted), \(deltaText(weeklyDelta(week, target: week.targetPerLoggedDay), unit: "kcal/day"))"

        case .week, .twoWeeks, .month:
            let loggedDays = summary.days.filter(\.isLogged)
            guard let day = loggedDays.max(by: { lhs, rhs in
                abs(lhs.calorieDifference) < abs(rhs.calorieDifference)
            }) else {
                return nil
            }

            if loggedDays.allSatisfy({ $0.status == .onTrack }) {
                return "Most stable: logged days stayed near target"
            }

            return "Biggest swing: \(day.date.shortFormatted), \(deltaText(day.calorieDifference, unit: "kcal"))"
        }
    }

    private static func weeklyDelta(_ week: HistoryWeekSummary, target: Int) -> Int {
        week.averageCaloriesPerLoggedDay.rounded().truncatedSafely - target
    }

    private static func weeklyStatus(_ week: HistoryWeekSummary, target: Int) -> HistoryGoalStatus {
        HistoryGoalStatus.calorieStatus(
            calories: week.averageCaloriesPerLoggedDay,
            loggedCount: week.loggedDays,
            targetCalories: target
        )
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

    private var averageLabel: String {
        switch range {
        case .week:
            "7-day"
        case .twoWeeks:
            "14-day"
        case .month:
            "30-day"
        case .quarter:
            "90-day"
        }
    }

    private static func weekdayInitial(for date: Date) -> String {
        let weekday = Calendar.current.component(.weekday, from: date)
        return ["S", "M", "T", "W", "T", "F", "S"][max(0, min(weekday - 1, 6))]
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
