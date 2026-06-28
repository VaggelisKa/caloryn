import Foundation

enum HistoryRange: String, CaseIterable, Identifiable {
    case week
    case twoWeeks
    case month
    case quarter

    var id: String { rawValue }

    var days: Int {
        switch self {
        case .week:
            7
        case .twoWeeks:
            14
        case .month:
            30
        case .quarter:
            90
        }
    }

    var label: String {
        switch self {
        case .week:
            "7 Days"
        case .twoWeeks:
            "14 Days"
        case .month:
            "30 Days"
        case .quarter:
            "90 Days"
        }
    }
}

enum HistoryGoalStatus: String, CaseIterable, Identifiable {
    case under
    case onTrack
    case over
    case notLogged

    var id: String { rawValue }

    var label: String {
        switch self {
        case .under:
            "Under"
        case .onTrack:
            "On Track"
        case .over:
            "Over"
        case .notLogged:
            "Not Logged"
        }
    }
}

enum HistoryCoverageLevel: String {
    case high
    case medium
    case low

    var label: String {
        switch self {
        case .high:
            "High confidence"
        case .medium:
            "Medium confidence"
        case .low:
            "Low confidence"
        }
    }
}

struct HistoryAnalytics {
    static let onTrackTolerance = 0.05

    let range: HistoryRange
    let dailyCalorieTarget: Int
    let current: HistoryPeriodSummary
    let previous: HistoryPeriodSummary
    let goalComparison: HistoryGoalComparison
    let macroPatterns: [HistoryMacroPattern]

    init(
        entries: [FoodLogEntry],
        profile: UserProfile?,
        range: HistoryRange,
        endDate: Date = .now,
        calendar: Calendar = .current
    ) {
        self.range = range
        dailyCalorieTarget = profile?.dailyCalorieTarget ?? 2_000

        let groupedEntries = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.date)
        }
        let currentDates = Self.dates(endingAt: endDate, days: range.days, calendar: calendar)
        let previousEndDate = calendar.date(byAdding: .day, value: -1, to: currentDates.first ?? endDate) ?? endDate
        let previousDates = Self.dates(endingAt: previousEndDate, days: range.days, calendar: calendar)

        current = HistoryPeriodSummary(
            dates: currentDates,
            entriesByDate: groupedEntries,
            dailyCalorieTarget: dailyCalorieTarget,
            calendar: calendar
        )
        previous = HistoryPeriodSummary(
            dates: previousDates,
            entriesByDate: groupedEntries,
            dailyCalorieTarget: dailyCalorieTarget,
            calendar: calendar
        )
        goalComparison = HistoryGoalComparison(current: current, previous: previous)
        macroPatterns = Self.macroPatterns(
            current: current,
            previous: previous,
            profile: profile
        )
    }

    private static func dates(endingAt endDate: Date, days: Int, calendar: Calendar) -> [Date] {
        let endDay = calendar.startOfDay(for: endDate)
        let startDay = calendar.date(byAdding: .day, value: -(days - 1), to: endDay) ?? endDay

        return (0..<days).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: startDay)
        }
    }

    private static func macroPatterns(
        current: HistoryPeriodSummary,
        previous: HistoryPeriodSummary,
        profile: UserProfile?
    ) -> [HistoryMacroPattern] {
        guard let profile else { return [] }

        return [TrackedNutrient.protein, .carbs, .fat].compactMap { nutrient in
            guard let target = profile.target(for: nutrient), target > 0 else { return nil }

            let goalKind = profile.goalKind(for: nutrient)
            return HistoryMacroPattern(
                nutrient: nutrient,
                target: target,
                goalKind: goalKind,
                current: current.macroSummary(for: nutrient, target: target, goalKind: goalKind),
                previous: previous.macroSummary(for: nutrient, target: target, goalKind: goalKind)
            )
        }
    }
}

struct HistoryPeriodSummary {
    let startDate: Date
    let endDate: Date
    let dailyCalorieTarget: Int
    let days: [HistoryDaySummary]
    let weeklyRollups: [HistoryWeekSummary]

    var totalDayCount: Int {
        days.count
    }

    var loggedDayCount: Int {
        days.filter(\.isLogged).count
    }

    var coverageRatio: Double {
        guard totalDayCount > 0 else { return 0 }
        return Double(loggedDayCount) / Double(totalDayCount)
    }

    var coverageLevel: HistoryCoverageLevel {
        if coverageRatio >= 0.8 { return .high }
        if coverageRatio >= 0.5 { return .medium }
        return .low
    }

    var averageCaloriesPerLoggedDay: Double {
        let loggedDays = days.filter(\.isLogged)
        guard !loggedDays.isEmpty else { return 0 }
        let total = loggedDays.reduce(0) { $0 + $1.calories }
        return total / Double(loggedDays.count)
    }

    var onTrackLoggedDayCount: Int {
        count(for: .onTrack)
    }

    var statusCounts: [HistoryGoalStatus: Int] {
        HistoryGoalStatus.allCases.reduce(into: [HistoryGoalStatus: Int]()) { counts, status in
            counts[status] = count(for: status)
        }
    }

    init(
        dates: [Date],
        entriesByDate: [Date: [FoodLogEntry]],
        dailyCalorieTarget: Int,
        calendar: Calendar
    ) {
        self.startDate = dates.first ?? .now
        self.endDate = dates.last ?? .now
        self.dailyCalorieTarget = dailyCalorieTarget
        self.days = dates.map { date in
            HistoryDaySummary(
                date: date,
                entries: entriesByDate[calendar.startOfDay(for: date)] ?? [],
                dailyCalorieTarget: dailyCalorieTarget
            )
        }
        self.weeklyRollups = Self.weeklyRollups(from: self.days)
    }

    func count(for status: HistoryGoalStatus) -> Int {
        days.filter { $0.status == status }.count
    }

    func macroSummary(
        for nutrient: TrackedNutrient,
        target: Double,
        goalKind: NutrientGoalKind
    ) -> HistoryNutrientPeriodSummary {
        let loggedDays = days.filter(\.isLogged)
        let total = loggedDays.reduce(0) { $0 + $1.value(for: nutrient) }
        let hitDays = loggedDays.filter {
            Self.isNutrientHit(
                value: $0.value(for: nutrient),
                target: target,
                goalKind: goalKind
            )
        }

        return HistoryNutrientPeriodSummary(
            loggedDays: loggedDays.count,
            hitDays: hitDays.count,
            averageValue: loggedDays.isEmpty ? 0 : total / Double(loggedDays.count)
        )
    }

    private static func isNutrientHit(
        value: Double,
        target: Double,
        goalKind: NutrientGoalKind
    ) -> Bool {
        guard target > 0 else { return false }

        switch goalKind {
        case .minimum:
            return value >= target
        case .target:
            return value >= target * (1 - HistoryAnalytics.onTrackTolerance)
                && value <= target * (1 + HistoryAnalytics.onTrackTolerance)
        case .maximum:
            return value <= target
        }
    }

    private static func weeklyRollups(from days: [HistoryDaySummary]) -> [HistoryWeekSummary] {
        let groupedDays = Dictionary(grouping: days) { day in
            day.date.startOfWeek
        }

        return groupedDays.keys.sorted().map { startDate in
            let weekDays = groupedDays[startDate, default: []].sorted { $0.date < $1.date }
            return HistoryWeekSummary(
                startDate: startDate,
                endDate: weekDays.last?.date ?? startDate,
                days: weekDays
            )
        }
    }
}

struct HistoryGoalComparison {
    let onTrackDayDelta: Int
    let averageCaloriesDelta: Double
    let loggedDayDelta: Int

    init(current: HistoryPeriodSummary, previous: HistoryPeriodSummary) {
        onTrackDayDelta = current.onTrackLoggedDayCount - previous.onTrackLoggedDayCount
        averageCaloriesDelta = current.averageCaloriesPerLoggedDay - previous.averageCaloriesPerLoggedDay
        loggedDayDelta = current.loggedDayCount - previous.loggedDayCount
    }
}

struct HistoryDaySummary: Identifiable {
    let date: Date
    let entryCount: Int
    let calories: Double
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let status: HistoryGoalStatus

    var id: Date { date }
    var isLogged: Bool { entryCount > 0 }

    init(
        date: Date,
        entries: [FoodLogEntry],
        dailyCalorieTarget: Int
    ) {
        self.date = date
        entryCount = entries.count
        calories = entries.reduce(0) { $0 + $1.calories }
        proteinG = entries.reduce(0) { $0 + $1.proteinG }
        carbsG = entries.reduce(0) { $0 + $1.carbsG }
        fatG = entries.reduce(0) { $0 + $1.fatG }
        status = Self.status(
            calories: calories,
            entryCount: entryCount,
            dailyCalorieTarget: dailyCalorieTarget
        )
    }

    func value(for nutrient: TrackedNutrient) -> Double {
        switch nutrient {
        case .protein:
            proteinG
        case .carbs:
            carbsG
        case .fat:
            fatG
        case .fiber, .sugars, .addedSugars, .saturatedFat, .sodium, .cholesterol, .alcohol:
            0
        }
    }

    private static func status(
        calories: Double,
        entryCount: Int,
        dailyCalorieTarget: Int
    ) -> HistoryGoalStatus {
        guard entryCount > 0 else { return .notLogged }
        guard dailyCalorieTarget > 0 else { return .onTrack }

        let target = Double(dailyCalorieTarget)
        if calories < target * (1 - HistoryAnalytics.onTrackTolerance) {
            return .under
        }
        if calories > target * (1 + HistoryAnalytics.onTrackTolerance) {
            return .over
        }
        return .onTrack
    }
}

struct HistoryWeekSummary: Identifiable {
    let startDate: Date
    let endDate: Date
    let totalDays: Int
    let loggedDays: Int
    let onTrackDays: Int

    var id: Date { startDate }

    var onTrackRatio: Double {
        guard loggedDays > 0 else { return 0 }
        return Double(onTrackDays) / Double(loggedDays)
    }

    var coverageRatio: Double {
        guard totalDays > 0 else { return 0 }
        return Double(loggedDays) / Double(totalDays)
    }

    init(startDate: Date, endDate: Date, days: [HistoryDaySummary]) {
        self.startDate = startDate
        self.endDate = endDate
        totalDays = days.count
        loggedDays = days.filter(\.isLogged).count
        onTrackDays = days.filter { $0.status == .onTrack }.count
    }
}

struct HistoryNutrientPeriodSummary {
    let loggedDays: Int
    let hitDays: Int
    let averageValue: Double
}

struct HistoryMacroPattern: Identifiable {
    let nutrient: TrackedNutrient
    let target: Double
    let goalKind: NutrientGoalKind
    let current: HistoryNutrientPeriodSummary
    let previous: HistoryNutrientPeriodSummary

    var id: String { nutrient.id }

    var hitDayDelta: Int {
        current.hitDays - previous.hitDays
    }

    var averageValueDelta: Double {
        current.averageValue - previous.averageValue
    }
}
