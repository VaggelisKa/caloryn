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
        let dailyCalorieTarget = profile?.dailyCalorieTarget ?? 2_000

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
                goalKind: goalKind,
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

    init(
        dates: [Date],
        entriesByDate: [Date: [FoodLogEntry]],
        dailyCalorieTarget: Int,
        calendar: Calendar
    ) {
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
    case day(HistoryDayDetail)
    case week(HistoryWeekSummary)

    var id: String {
        switch self {
        case .day(let detail):
            "day-\(detail.id.ISO8601Format())"
        case .week(let week):
            "week-\(week.id.ISO8601Format())"
        }
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
    let detail: HistoryDayDetail

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
        let computedStatus = Self.status(
            calories: calories,
            entryCount: entryCount,
            dailyCalorieTarget: dailyCalorieTarget
        )
        status = computedStatus
        detail = HistoryDayDetail(
            date: date,
            entries: entries,
            dailyCalorieTarget: dailyCalorieTarget,
            status: computedStatus
        )
    }

    func value(for nutrient: TrackedNutrient) -> Double {
        detail.value(for: nutrient)
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

struct HistoryDayDetail: Identifiable {
    let date: Date
    let dailyCalorieTarget: Int
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
        Int(calories.rounded()) - dailyCalorieTarget
    }

    init(
        date: Date,
        entries: [FoodLogEntry],
        dailyCalorieTarget: Int,
        status: HistoryGoalStatus? = nil
    ) {
        self.date = date
        self.dailyCalorieTarget = dailyCalorieTarget
        entryCount = entries.count
        totalPortionGrams = entries.reduce(0) { $0 + $1.portionGrams }
        calories = entries.reduce(0) { $0 + $1.calories }
        proteinG = entries.reduce(0) { $0 + $1.proteinG }
        carbsG = entries.reduce(0) { $0 + $1.carbsG }
        fatG = entries.reduce(0) { $0 + $1.fatG }
        fiberG = entries.reduce(0) { $0 + $1.fiberG }
        sugarsG = entries.reduce(0) { $0 + ($1.sugarsG ?? 0) }
        addedSugarsG = entries.reduce(0) { $0 + ($1.addedSugarsG ?? 0) }
        saturatedFatG = entries.reduce(0) { $0 + ($1.saturatedFatG ?? 0) }
        sodiumG = entries.reduce(0) { $0 + ($1.sodiumG ?? 0) }
        cholesterolG = entries.reduce(0) { $0 + ($1.cholesterolG ?? 0) }
        alcoholG = entries.reduce(0) { $0 + ($1.alcoholG ?? 0) }
        self.status = status ?? Self.status(
            calories: calories,
            entryCount: entryCount,
            dailyCalorieTarget: dailyCalorieTarget
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
            guard let grade = entry.foodItem?.nutriscoreGrade?.lowercased(),
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
