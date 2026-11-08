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

    static func calorieStatus(
        calories: Double,
        loggedCount: Int,
        targetCalories: Int
    ) -> HistoryGoalStatus {
        guard loggedCount > 0 else { return .notLogged }
        guard targetCalories > 0 else { return .onTrack }

        let target = Double(targetCalories)
        if calories < target * (1 - HistoryAnalytics.onTrackTolerance) {
            return .under
        }
        if calories > target * (1 + HistoryAnalytics.onTrackTolerance) {
            return .over
        }
        return .onTrack
    }
}

struct HistoryAnalytics {
    static let onTrackTolerance = 0.05

    let range: HistoryRange
    let calendar: Calendar
    let current: HistoryPeriodSummary
    let previous: HistoryPeriodSummary
    let goalComparison: HistoryGoalComparison
    let macroPatterns: [HistoryMacroPattern]

    init(
        entries: [FoodLogEntry],
        profile: UserProfile?,
        range: HistoryRange,
        endDate: Date = .now,
        calendar: Calendar = .current,
        targetResolver: HistoryDayTargetResolver? = nil
    ) {
        self.range = range
        self.calendar = calendar
        let resolver = targetResolver ?? HistoryDayTargetResolver(
            fallbackTarget: profile?.dailyCalorieTarget ?? 2_000
        )

        let groupedEntries = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.date)
        }
        let currentDates = Self.dates(endingAt: endDate, days: range.days, calendar: calendar)
        let previousEndDate = calendar.date(byAdding: .day, value: -1, to: currentDates.first ?? endDate) ?? endDate
        let previousDates = Self.dates(endingAt: previousEndDate, days: range.days, calendar: calendar)

        current = HistoryPeriodSummary(
            dates: currentDates,
            entriesByDate: groupedEntries,
            targetResolver: resolver,
            calendar: calendar
        )
        previous = HistoryPeriodSummary(
            dates: previousDates,
            entriesByDate: groupedEntries,
            targetResolver: resolver,
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
                goalKind: goalKind,
                target: target,
                current: current.macroSummary(for: nutrient, target: target, goalKind: goalKind),
                previous: previous.macroSummary(for: nutrient, target: target, goalKind: goalKind)
            )
        }
    }
}

struct HistoryPeriodSummary {
    let dailyCalorieTarget: Int
    let days: [HistoryDaySummary]
    let weeklyRollups: [HistoryWeekSummary]
    let calendar: Calendar

    var totalDayCount: Int {
        days.count
    }

    var loggedDayCount: Int {
        days.filter(\.isLogged).count
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

    var loggedDayTargetTotal: Int {
        days.filter(\.isLogged).reduce(0) { $0 + $1.dailyCalorieTarget }
    }

    var averageTargetPerLoggedDay: Int {
        let loggedDays = days.filter(\.isLogged)
        guard !loggedDays.isEmpty else { return dailyCalorieTarget }
        return (Double(loggedDayTargetTotal) / Double(loggedDays.count)).roundedCalories
    }

    var hasEstimatedTargets: Bool {
        days.contains { $0.isLogged && $0.isTargetEstimated }
    }

    init(
        dates: [Date],
        entriesByDate: [Date: [FoodLogEntry]],
        targetResolver: HistoryDayTargetResolver,
        calendar: Calendar
    ) {
        let days = dates.map { date -> HistoryDaySummary in
            let target = targetResolver.target(for: date, calendar: calendar)
            return HistoryDaySummary(
                date: date,
                entries: entriesByDate[calendar.startOfDay(for: date)] ?? [],
                dailyCalorieTarget: target.calories,
                isTargetEstimated: target.isEstimated
            )
        }
        self.days = days
        self.calendar = calendar
        self.dailyCalorieTarget = days.isEmpty
            ? CalorieDomain.clamped(targetResolver.fallbackTarget)
            : (Double(days.reduce(0) { $0 + $1.dailyCalorieTarget }) / Double(days.count)).roundedCalories
        self.weeklyRollups = Self.weeklyRollups(from: days, calendar: calendar)
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

    private static func weeklyRollups(
        from days: [HistoryDaySummary],
        calendar: Calendar
    ) -> [HistoryWeekSummary] {
        let groupedDays = Dictionary(grouping: days) { day in
            day.date.startOfWeek(in: calendar)
        }

        return groupedDays.keys.sorted().map { startDate in
            let weekDays = groupedDays[startDate, default: []].sorted { $0.date < $1.date }
            return HistoryWeekSummary(
                startDate: startDate,
                days: weekDays
            )
        }
    }
}

struct HistoryGoalComparison {
    let onTrackDayDelta: Int

    init(current: HistoryPeriodSummary, previous: HistoryPeriodSummary) {
        onTrackDayDelta = current.onTrackLoggedDayCount - previous.onTrackLoggedDayCount
    }
}

struct HistoryDaySummary: Identifiable {
    let date: Date
    let entryCount: Int
    let dailyCalorieTarget: Int
    let isTargetEstimated: Bool
    let calories: Double
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let fiberG: Double
    let sugarsG: Double
    let addedSugarsG: Double
    let saturatedFatG: Double
    let sodiumG: Double
    let cholesterolG: Double
    let alcoholG: Double
    let status: HistoryGoalStatus

    var id: Date { date }
    var isLogged: Bool { entryCount > 0 }
    var calorieDifference: Int {
        calories.roundedCalories - dailyCalorieTarget
    }

    init(
        date: Date,
        entries: [FoodLogEntry],
        dailyCalorieTarget: Int,
        isTargetEstimated: Bool = false
    ) {
        self.date = date
        self.dailyCalorieTarget = CalorieDomain.clamped(dailyCalorieTarget)
        self.isTargetEstimated = isTargetEstimated
        entryCount = entries.count

        let nutrition = entries.reduce(.zero) { $0 + $1.nutrition }
        calories = nutrition.calories
        proteinG = nutrition.proteinG
        carbsG = nutrition.carbsG
        fatG = nutrition.fatG
        fiberG = nutrition.fiberG
        sugarsG = nutrition.sugarsG ?? 0
        addedSugarsG = nutrition.addedSugarsG ?? 0
        saturatedFatG = nutrition.saturatedFatG ?? 0
        sodiumG = nutrition.sodiumG ?? 0
        cholesterolG = nutrition.cholesterolG ?? 0
        alcoholG = nutrition.alcoholG ?? 0
        status = HistoryGoalStatus.calorieStatus(
            calories: calories,
            loggedCount: entryCount,
            targetCalories: dailyCalorieTarget
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
        case .fiber:
            fiberG
        case .sugars:
            sugarsG
        case .addedSugars:
            addedSugarsG
        case .saturatedFat:
            saturatedFatG
        case .sodium:
            sodiumG
        case .cholesterol:
            cholesterolG
        case .alcohol:
            alcoholG
        }
    }
}

struct HistoryFoodSummary: Identifiable {
    let id: String
    let name: String
    let entryCount: Int
    let portionGrams: Double
    let calories: Double
}

struct HistoryWeekSummary: Identifiable {
    let startDate: Date
    let days: [HistoryDaySummary]
    let totalDays: Int
    let loggedDays: Int
    let onTrackDays: Int
    let averageCaloriesPerLoggedDay: Double
    let targetPerLoggedDay: Int
    let hasEstimatedTargets: Bool

    var id: Date { startDate }

    init(startDate: Date, days: [HistoryDaySummary]) {
        self.startDate = startDate
        self.days = days
        let logged = days.filter(\.isLogged)
        totalDays = days.count
        loggedDays = logged.count
        onTrackDays = days.filter { $0.status == .onTrack }.count
        averageCaloriesPerLoggedDay = logged.isEmpty
            ? 0
            : logged.reduce(0) { $0 + $1.calories } / Double(logged.count)
        let targetDays = logged.isEmpty ? days : logged
        targetPerLoggedDay = targetDays.isEmpty
            ? 0
            : (Double(targetDays.reduce(0) { $0 + $1.dailyCalorieTarget }) / Double(targetDays.count)).roundedCalories
        hasEstimatedTargets = logged.contains(where: \.isTargetEstimated)
    }
}

struct HistoryNutrientPeriodSummary {
    let loggedDays: Int
    let hitDays: Int
    let averageValue: Double
}

struct HistoryMacroPattern: Identifiable {
    let nutrient: TrackedNutrient
    let goalKind: NutrientGoalKind
    let target: Double
    let current: HistoryNutrientPeriodSummary
    let previous: HistoryNutrientPeriodSummary

    var id: String { nutrient.id }

    var averageValueDelta: Double {
        current.averageValue - previous.averageValue
    }
}
