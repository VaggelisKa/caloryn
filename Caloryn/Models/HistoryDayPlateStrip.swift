import CoreGraphics
import Foundation

/// History's consistency strip as a row of small plates, one per day — or one per week in
/// the 90-day range, where ninety plates would be too small to read.
///
/// A plate is filled with what was eaten against that day's own goal (`historyEaten`); a day
/// over its goal is ringed in ink, and the day still in progress is dashed and lighter. Under
/// and on track are told apart by how full the plate is, so status never rests on colour.
///
/// A week plate is filled with the week's average against its goal, and is ringed only when
/// that average is over goal, by the same band a day is rated by. How consistent the week was
/// is said in words under the plate ("6/7 on track") rather than borrowed from the day
/// statuses: a ring that meant "over" on a day and "few days on track" on a week read the same
/// and said two different things.
///
/// Takes each period reduced to the facts a plate needs, so every outline and label rule is
/// reachable without entries or a store.
struct HistoryDayPlateStrip: Equatable {
    enum Outline: Equatable {
        case standard
        /// The day, or the week's average per logged day, went over its goal.
        case over
        /// The period is still in progress: today, or this week.
        case current
    }

    /// How loudly a plate's label reads: the current period boldest, a ringed one in ink,
    /// the rest quiet.
    enum LabelStyle: Equatable {
        case regular
        case emphasized
        case current
    }

    /// A week's day counts: what the line under its plate is made of.
    ///
    /// The count is out of the week's days in the range (`totalDays`), not its logged days: an
    /// unlogged day was not a day on track, and out of logged days a week with two days logged,
    /// both on track, would read "2/2", as good as a perfect week. The range's first week and
    /// the current one hold only their days inside the range up to today, so neither is
    /// marked down for days it could not have had.
    struct WeekConsistency: Equatable {
        let onTrackDays: Int
        let loggedDays: Int
        let totalDays: Int

        /// "6/7 on track", under the plate.
        var text: String {
            "\(onTrackDays)/\(totalDays) on track"
        }

        /// "6 of 7 days on track", the same count for VoiceOver.
        var spokenText: String {
            "\(onTrackDays) of \(totalDays) \(totalDays == 1 ? "day" : "days") on track"
        }
    }

    /// One day or week, reduced to what its plate draws.
    struct Period: Equatable {
        let start: Date
        let label: String
        /// Everything eaten that day, or the week's average per logged day.
        let calories: Double
        let target: Int
        /// The day's status, or for a week the status of its average per logged day.
        let status: HistoryGoalStatus
        let isCurrent: Bool
        /// A week's day counts; `nil` for a day.
        let consistency: WeekConsistency?

        /// Ringed in ink: over its goal and finished. The period still in progress is dashed
        /// instead, however it stands so far.
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

        /// A week: filled with its average per logged day against its goal, and rated by that
        /// average in the band a day is rated by, as the calorie trend rates its week bars.
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
        /// A week's "6/7 on track"; `nil` for a day.
        let consistencyText: String?
        /// "avg over goal" under a week whose average went over; `nil` otherwise.
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
    /// The strip is one element to VoiceOver. Days are a count per status rather than a
    /// plate-by-plate reading, which at thirty days is a minute of numbers; the thirteen
    /// weeks are read one by one, as the words under their plates say.
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

    /// The gap between two plates in a row.
    static let columnSpacing: CGFloat = 6

    /// The plate size for a row `width` points wide: the strip's own size while its columns
    /// fit, and otherwise as large as they can be and still fit. The column count holds, since
    /// a row is a week (or ten days) and the labels line up by it.
    ///
    /// The strip's own sizes need 316pt (seven plates) and 334pt (ten), so a 320pt-wide phone
    /// under Display Zoom, 280pt between the page margins, drew the strip past the margin.
    /// `nil` (not yet measured) is the strip's own size.
    func plateSize(fittingWidth width: CGFloat?) -> CGFloat {
        guard let width else { return plateSize }
        let gaps = Self.columnSpacing * CGFloat(columnCount - 1)
        let fitted = ((width - gaps) / CGFloat(columnCount)).rounded(.down)
        return max(1, min(plateSize, fitted))
    }

    /// The legend's key for the ink ring. A week is ringed for its average, so its key says so.
    var ringKeyText: String {
        switch granularity {
        case .day: "over goal"
        case .week: Self.weekOverGoalText
        }
    }

    /// The line under a week plate ringed for its average, and the legend's key for that ring.
    static let weekOverGoalText = "avg over goal"

    /// The legend's key for the dashed plate.
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
    /// The strip for a range: a plate per day for 7, 14 and 30 days, a plate per calendar
    /// week for 90.
    ///
    /// Seven columns hold a week to a row, labelled by weekday. Thirty days take ten smaller
    /// plates a row labelled by day of month, since a weekday initial under every one of
    /// thirty plates says nothing. Weeks are numbered as on the weekly chart, W1 the oldest.
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
    /// A week's consistency in the day steps, as the spec has the "Weekly consistency" chart
    /// reuse them: two thirds or more of its logged days on track reads as on track, a third or
    /// more as under, anything less as over, and a week with nothing logged as not logged.
    /// `HistoryTheme.weeklyConsistencyColor` colours the weekly chart by this rule; the 90-day
    /// plates no longer do, and say their consistency in words instead.
    ///
    /// Compared in whole numbers: as a decimal, exactly a third (1 of 3, 2 of 6) fell just
    /// under a 0.34 cut-off and read as over.
    static func weeklyConsistency(onTrackDays: Int, loggedDays: Int) -> HistoryGoalStatus {
        guard loggedDays > 0 else { return .notLogged }
        if onTrackDays * 3 >= loggedDays * 2 { return .onTrack }
        if onTrackDays * 3 >= loggedDays { return .under }
        return .over
    }
}
