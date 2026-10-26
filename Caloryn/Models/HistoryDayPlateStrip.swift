import CoreGraphics
import Foundation

struct HistoryDayPlateStrip: Equatable {
    enum Outline: Equatable {
        case standard
        case over
        case current
    }

    enum LabelStyle: Equatable {
        case regular
        case emphasized
        case current
    }

    struct WeekConsistency: Equatable {
        let onTrackDays: Int
        let loggedDays: Int
        let totalDays: Int

        var text: String {
            "\(onTrackDays)/\(totalDays) on track"
        }

        var spokenText: String {
            "\(onTrackDays) of \(totalDays) \(totalDays == 1 ? "day" : "days") on track"
        }
    }

    struct Period: Equatable {
        let start: Date
        let label: String
        let calories: Double
        let target: Int
        let status: HistoryGoalStatus
        let isCurrent: Bool
        let consistency: WeekConsistency?

        var isRingedOverGoal: Bool {
            status == .over && !isCurrent
        }

        init(
            start: Date,
            label: String,
            calories: Double,
            target: Int,
            status: HistoryGoalStatus,
            isCurrent: Bool
        ) {
            self.start = start
            self.label = label
            self.calories = calories
            self.target = target
            self.status = status
            self.isCurrent = isCurrent
            consistency = nil
        }

        init(
            weekStart: Date,
            label: String,
            averageCalories: Double,
            target: Int,
            consistency: WeekConsistency,
            isCurrent: Bool
        ) {
            start = weekStart
            self.label = label
            calories = averageCalories
            self.target = target
            status = HistoryGoalStatus.calorieStatus(
                calories: averageCalories,
                loggedCount: consistency.loggedDays,
                targetCalories: target
            )
            self.isCurrent = isCurrent
            self.consistency = consistency
        }
    }

    struct Plate: Equatable, Identifiable {
        let id: Date
        let label: String
        let donut: CalorieDonutSummary
        let outline: Outline
        let labelStyle: LabelStyle
        let consistencyText: String?
        let overGoalText: String?
    }

    enum Granularity: Equatable {
        case day
        case week
    }

    let granularity: Granularity
    let plates: [Plate]
    let columnCount: Int
    let plateSize: CGFloat
    let statusCounts: [HistoryGoalStatus: Int]
    let accessibilityLabel: String

    init(periods: [Period], granularity: Granularity, columnCount: Int, plateSize: CGFloat) {
        self.granularity = granularity
        self.columnCount = max(1, columnCount)
        self.plateSize = plateSize
        plates = periods.map(Self.plate(for:))
        let statusCounts = Dictionary(grouping: periods, by: \.status).mapValues(\.count)
        self.statusCounts = statusCounts
        accessibilityLabel = Self.accessibilityLabel(
            periods: periods,
            statusCounts: statusCounts,
            granularity: granularity
        )
    }

    static let columnSpacing: CGFloat = 6

    func plateSize(fittingWidth width: CGFloat?) -> CGFloat {
        guard let width else { return plateSize }
        let gaps = Self.columnSpacing * CGFloat(columnCount - 1)
        let fitted = ((width - gaps) / CGFloat(columnCount)).rounded(.down)
        return max(1, min(plateSize, fitted))
    }

    var ringKeyText: String {
        switch granularity {
        case .day: "over goal"
        case .week: Self.weekOverGoalText
        }
    }

    static let weekOverGoalText = "avg over goal"

    var currentKeyText: String {
        switch granularity {
        case .day: "today so far"
        case .week: "this week so far"
        }
    }

    private static func accessibilityLabel(
        periods: [Period],
        statusCounts: [HistoryGoalStatus: Int],
        granularity: Granularity
    ) -> String {
        switch granularity {
        case .day:
            let under = statusCounts[.under, default: 0]
            let onTrack = statusCounts[.onTrack, default: 0]
            let over = statusCounts[.over, default: 0]
            let notLogged = statusCounts[.notLogged, default: 0]
            return "Goal consistency: \(under) under, \(onTrack) on track, \(over) over, \(notLogged) not logged."
        case .week:
            let weeks = periods.compactMap { period -> String? in
                guard let consistency = period.consistency else { return nil }
                let reading = "\(period.label), \(consistency.spokenText)"
                return period.isRingedOverGoal ? "\(reading), average over goal" : reading
            }
            return "Weekly goal consistency: \(weeks.joined(separator: "; "))."
        }
    }

    private static func plate(for period: Period) -> Plate {
        let isLogged = period.status != .notLogged
        let donut = CalorieDonutSummary(
            mealTotals: isLogged ? [.breakfast: period.calories] : [:],
            budget: Double(period.target),
            isOver: period.calories > Double(period.target)
        )

        let outline: Outline
        let labelStyle: LabelStyle
        if period.isCurrent {
            outline = .current
            labelStyle = .current
        } else if period.isRingedOverGoal {
            outline = .over
            labelStyle = .emphasized
        } else {
            outline = .standard
            labelStyle = .regular
        }

        return Plate(
            id: period.start,
            label: period.label,
            donut: donut,
            outline: outline,
            labelStyle: labelStyle,
            consistencyText: period.consistency?.text,
            overGoalText: period.consistency != nil && period.isRingedOverGoal ? weekOverGoalText : nil
        )
    }
}

extension HistoryDayPlateStrip {
    init(range: HistoryRange, summary: HistoryPeriodSummary, today: Date) {
        let calendar = summary.calendar

        switch range {
        case .quarter:
            let currentWeekStart = today.startOfWeek(in: calendar)
            let periods = summary.weeklyRollups.enumerated().map { offset, week in
                Period(
                    weekStart: week.startDate,
                    label: HistoryWeeklyConsistencyChart.label(forOffset: offset),
                    averageCalories: week.averageCaloriesPerLoggedDay,
                    target: week.targetPerLoggedDay,
                    consistency: WeekConsistency(
                        onTrackDays: week.onTrackDays,
                        loggedDays: week.loggedDays,
                        totalDays: week.totalDays
                    ),
                    isCurrent: calendar.isDate(week.startDate, inSameDayAs: currentWeekStart)
                )
            }
            self.init(periods: periods, granularity: .week, columnCount: 7, plateSize: 40)

        case .week, .twoWeeks, .month:
            let isMonth = range == .month
            let periods = summary.days.map { day in
                Period(
                    start: day.date,
                    label: isMonth
                        ? "\(calendar.component(.day, from: day.date))"
                        : day.date.shortWeekday(in: calendar),
                    calories: day.calories,
                    target: day.dailyCalorieTarget,
                    status: day.status,
                    isCurrent: calendar.isDate(day.date, inSameDayAs: today)
                )
            }
            self.init(
                periods: periods,
                granularity: .day,
                columnCount: isMonth ? 10 : 7,
                plateSize: isMonth ? 28 : 40
            )
        }
    }
}

extension HistoryGoalStatus {
    static func weeklyConsistency(onTrackDays: Int, loggedDays: Int) -> HistoryGoalStatus {
        guard loggedDays > 0 else { return .notLogged }
        if onTrackDays * 3 >= loggedDays * 2 { return .onTrack }
        if onTrackDays * 3 >= loggedDays { return .under }
        return .over
    }
}
