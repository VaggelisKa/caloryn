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
        // Without snapshots every day falls back to the current profile target,
        // which matches the pre-snapshot behavior of History.
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
                current: current.macroSummary(for: nutrient, target: target, goalKind: goalKind),
                previous: previous.macroSummary(for: nutrient, target: target, goalKind: goalKind)
            )
        }
    }
}

struct HistoryPeriodSummary {
    /// Reference target for period-level chart context (rounded average of the
    /// per-day effective targets). Day and week statuses never use this value —
    /// they compare against their own per-day targets.
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

    /// Sum of the effective targets across logged days, for honest period totals.
    var loggedDayTargetTotal: Int {
        days.filter(\.isLogged).reduce(0) { $0 + $1.dailyCalorieTarget }
    }

    /// Rounded average effective target across logged days; falls back to the
    /// period reference target when nothing is logged.
    var averageTargetPerLoggedDay: Int {
        let loggedDays = days.filter(\.isLogged)
        guard !loggedDays.isEmpty else { return dailyCalorieTarget }
        return (Double(loggedDayTargetTotal) / Double(loggedDays.count)).rounded().truncatedSafely
    }

    /// `true` when at least one logged day has no persisted goal snapshot and
    /// uses the documented current-profile fallback target. Unlogged days are
    /// ignored: nothing is compared against their target, so flagging them
    /// would warn about precision the reader was never shown.
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
        self.dailyCalorieTarget = days.isEmpty
            ? targetResolver.fallbackTarget
            : (Double(days.reduce(0) { $0 + $1.dailyCalorieTarget }) / Double(days.count)).rounded().truncatedSafely
        self.weeklyRollups = Self.weeklyRollups(from: days)
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

enum HistoryCalorieTrendSelection: Identifiable {
    case day(HistoryDaySummary)
    case week(HistoryWeekSummary)

    var id: String {
        switch self {
        case .day(let day):
            "day-\(day.id.ISO8601Format())"
        case .week(let week):
            "week-\(week.id.ISO8601Format())"
        }
    }
}

struct HistoryDaySummary: Identifiable {
    let date: Date
    let entryCount: Int
    let dailyCalorieTarget: Int
    /// `true` when the target is the documented fallback (current profile
    /// target) because no goal snapshot exists for this day.
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
    private let entries: [FoodLogEntry]

    var id: Date { date }
    var isLogged: Bool { entryCount > 0 }
    var calorieDifference: Int {
        calories.rounded().truncatedSafely - dailyCalorieTarget
    }

    init(
        date: Date,
        entries: [FoodLogEntry],
        dailyCalorieTarget: Int,
        isTargetEstimated: Bool = false
    ) {
        self.date = date
        self.entries = entries
        self.dailyCalorieTarget = dailyCalorieTarget
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

    func makeDetail() -> HistoryDayDetail {
        HistoryDayDetail(
            date: date,
            entries: entries,
            dailyCalorieTarget: dailyCalorieTarget,
            status: status,
            isTargetEstimated: isTargetEstimated
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

struct HistoryDayDetail: Identifiable {
    let date: Date
    let dailyCalorieTarget: Int
    /// See `HistoryDaySummary.isTargetEstimated`.
    let isTargetEstimated: Bool
    let entryCount: Int
    let totalPortionGrams: Double
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
    let mealSummaries: [HistoryMealSummary]
    let topFoods: [HistoryFoodSummary]
    let produceSummary: ProduceVarietySummary
    let nutriscoreDistribution: [HistoryNutriscoreSummary]

    var id: Date { date }
    var isLogged: Bool { entryCount > 0 }
    var calorieDifference: Int {
        calories.rounded().truncatedSafely - dailyCalorieTarget
    }

    init(
        date: Date,
        entries: [FoodLogEntry],
        dailyCalorieTarget: Int,
        status: HistoryGoalStatus? = nil,
        isTargetEstimated: Bool = false
    ) {
        self.date = date
        self.dailyCalorieTarget = dailyCalorieTarget
        self.isTargetEstimated = isTargetEstimated
        entryCount = entries.count
        totalPortionGrams = entries.reduce(0) { $0 + $1.portionGrams }
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
        self.status = status ?? HistoryGoalStatus.calorieStatus(
            calories: calories,
            loggedCount: entryCount,
            targetCalories: dailyCalorieTarget
        )
        mealSummaries = Self.mealSummaries(from: entries)
        topFoods = Self.topFoods(from: entries)
        produceSummary = ProduceVarietySummary(entries: entries)
        nutriscoreDistribution = Self.nutriscoreDistribution(from: entries)
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

    private static func mealSummaries(from entries: [FoodLogEntry]) -> [HistoryMealSummary] {
        MealType.allCases.compactMap { mealType in
            let mealEntries = entries.filter { $0.mealType == mealType }
            guard !mealEntries.isEmpty else { return nil }

            return HistoryMealSummary(
                mealType: mealType,
                entryCount: mealEntries.count,
                calories: mealEntries.reduce(0) { $0 + $1.calories }
            )
        }
    }

    private static func topFoods(from entries: [FoodLogEntry]) -> [HistoryFoodSummary] {
        var foods: [String: HistoryFoodAccumulator] = [:]

        for entry in entries {
            let name = foodName(for: entry)
            let key = normalizedFoodKey(name)
            guard !key.isEmpty else { continue }

            var accumulator = foods[key] ?? HistoryFoodAccumulator(id: key, name: name)
            accumulator.entryCount += 1
            accumulator.portionGrams += entry.portionGrams
            accumulator.calories += entry.calories
            foods[key] = accumulator
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

    private static func foodName(for entry: FoodLogEntry) -> String {
        let storedName = entry.foodName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !storedName.isEmpty { return storedName }

        let foodItemName = entry.foodItem?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return foodItemName.isEmpty ? "Unnamed food" : foodItemName
    }

    private static func normalizedFoodKey(_ name: String) -> String {
        name
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func nutriscoreDistribution(from entries: [FoodLogEntry]) -> [HistoryNutriscoreSummary] {
        let validGrades = ["a", "b", "c", "d", "e"]
        let order = Dictionary(uniqueKeysWithValues: validGrades.enumerated().map { ($1, $0) })
        let counts = entries.reduce(into: [String: Int]()) { result, entry in
            guard let grade = entry.historicalNutriscoreGrade?.lowercased(),
                  order[grade] != nil else { return }
            result[grade, default: 0] += 1
        }

        return counts.map { grade, count in
            HistoryNutriscoreSummary(grade: grade, count: count)
        }
        .sorted { (order[$0.grade] ?? 0) < (order[$1.grade] ?? 0) }
    }
}

struct HistoryMealSummary: Identifiable {
    let mealType: MealType
    let entryCount: Int
    let calories: Double

    var id: String { mealType.id }
}

struct HistoryFoodSummary: Identifiable {
    let id: String
    let name: String
    let entryCount: Int
    let portionGrams: Double
    let calories: Double
}

struct HistoryNutriscoreSummary: Identifiable {
    let grade: String
    let count: Int

    var id: String { grade }
}

private struct HistoryFoodAccumulator {
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

struct HistoryWeekSummary: Identifiable {
    let startDate: Date
    let days: [HistoryDaySummary]
    let totalDays: Int
    let loggedDays: Int
    let onTrackDays: Int
    let averageCaloriesPerLoggedDay: Double
    /// Rounded average effective target across the week's logged days (all
    /// days when nothing is logged). Weekly status compares average calories
    /// per logged day against this, so a later profile-target change cannot
    /// rewrite a past week's status.
    let targetPerLoggedDay: Int
    /// `true` when any logged day in the week uses the fallback target.
    let hasEstimatedTargets: Bool

    var id: Date { startDate }

    var onTrackRatio: Double {
        guard loggedDays > 0 else { return 0 }
        return Double(onTrackDays) / Double(loggedDays)
    }

    var coverageRatio: Double {
        guard totalDays > 0 else { return 0 }
        return Double(loggedDays) / Double(totalDays)
    }

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
            : (Double(targetDays.reduce(0) { $0 + $1.dailyCalorieTarget }) / Double(targetDays.count)).rounded().truncatedSafely
        hasEstimatedTargets = targetDays.contains(where: \.isTargetEstimated)
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
    let current: HistoryNutrientPeriodSummary
    let previous: HistoryNutrientPeriodSummary

    var id: String { nutrient.id }

    var averageValueDelta: Double {
        current.averageValue - previous.averageValue
    }
}
