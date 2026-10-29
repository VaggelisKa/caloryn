import Foundation

struct HistoryRecurringCaloriePatternPolicy {
    static let standard = HistoryRecurringCaloriePatternPolicy()

    let windowDayCount: Int
    let minimumWeekdayOccurrences: Int
    let minimumWeekdayOutcomeRate: Double
    let minimumOutcomeRateSeparation: Double
    let minimumMealOnlyGroupCount: Int
    let minimumMealOnlyComparisonCount: Int
    let minimumMealOnlyCalendarWeekCount: Int
    let minimumTargetRelativeMealDifference: Double
    let minimumMealAttribution: Double

    init(
        windowDayCount: Int = 30,
        minimumWeekdayOccurrences: Int = 4,
        minimumWeekdayOutcomeRate: Double = 0.80,
        minimumOutcomeRateSeparation: Double = 0.40,
        minimumMealOnlyGroupCount: Int = 4,
        minimumMealOnlyComparisonCount: Int = 4,
        minimumMealOnlyCalendarWeekCount: Int = 3,
        minimumTargetRelativeMealDifference: Double = 0.10,
        minimumMealAttribution: Double = 0.50
    ) {
        self.windowDayCount = windowDayCount
        self.minimumWeekdayOccurrences = minimumWeekdayOccurrences
        self.minimumWeekdayOutcomeRate = minimumWeekdayOutcomeRate
        self.minimumOutcomeRateSeparation = minimumOutcomeRateSeparation
        self.minimumMealOnlyGroupCount = minimumMealOnlyGroupCount
        self.minimumMealOnlyComparisonCount = minimumMealOnlyComparisonCount
        self.minimumMealOnlyCalendarWeekCount = minimumMealOnlyCalendarWeekCount
        self.minimumTargetRelativeMealDifference = minimumTargetRelativeMealDifference
        self.minimumMealAttribution = minimumMealAttribution
    }
}

enum HistoryRecurringCalorieOutcome: String, CaseIterable {
    case above
    case below

    var status: HistoryGoalStatus {
        switch self {
        case .above: .over
        case .below: .under
        }
    }

    var direction: String {
        switch self {
        case .above: "over"
        case .below: "under"
        }
    }

    var goalText: String {
        "\(direction) goal"
    }

    var goalTitle: String {
        "\(direction.capitalized) goal"
    }

    var goalDaysText: String {
        "\(direction)-goal days"
    }
}

enum HistoryRecurringCaloriePatternKind: String {
    case weekdayMeal
    case mealOnly
}

struct HistoryRecurringCaloriePatternPhrase: Equatable {
    struct Run: Equatable {
        let text: String
        let isEmphasised: Bool
    }

    let runs: [Run]

    var plainText: String {
        runs.map(\.text).joined()
    }
}

extension HistoryRecurringCaloriePatternPhrase.Run {
    static func plain(_ text: String) -> Self {
        Self(text: text, isEmphasised: false)
    }

    static func emphasised(_ text: String) -> Self {
        Self(text: text, isEmphasised: true)
    }
}

enum HistoryRecurringCaloriePatternWording {
    static func mealName(for mealType: MealType) -> String {
        HistoryMealLabel.rowTitle(for: mealType)
    }

    static func agreeing(
        with mealType: MealType,
        singular: String,
        plural: String
    ) -> String {
        mealType == .snack ? plural : singular
    }

    static func weekdayPlural(_ weekdayName: String) -> String {
        "\(weekdayName)s"
    }

    static func patternDaysName(
        kind: HistoryRecurringCaloriePatternKind,
        weekdayName: String,
        outcome: HistoryRecurringCalorieOutcome,
        supportingDayCount: Int,
        cohortDayCount: Int
    ) -> String {
        switch kind {
        case .weekdayMeal:
            supportingDayCount == cohortDayCount
                ? weekdayPlural(weekdayName)
                : "\(outcome.direction)-goal \(weekdayPlural(weekdayName))"
        case .mealOnly:
            outcome.goalDaysText
        }
    }

    static func calories(_ value: Double) -> String {
        value.rounded().truncatedSafely.formatted()
    }
}

struct HistoryRecurringCaloriePattern: Identifiable {
    let id: String
    let kind: HistoryRecurringCaloriePatternKind
    let outcome: HistoryRecurringCalorieOutcome
    let weekday: Int?
    let mealType: MealType
    let supportingDays: [HistoryRecurringCaloriePatternDay]
    let cohortDayCount: Int
    let outcomeComparisonCount: Int
    let outcomeComparisonDayCount: Int
    let mealComparisonDayCount: Int
    let eligibleDayCount: Int
    let supportingMealAverageCalories: Double
    let comparisonMealAverageCalories: Double
    let mealDifferenceCalories: Double
    let targetRelativeMealDifference: Double
    let rateSeparation: Double
    let windowStart: Date
    let windowEnd: Date
    /// The calendar this pattern's window, weekday cohorts and supporting days
    /// were derived in, carried on the pattern for the same reason the period
    /// summary carries its own: the drill-down receives the pattern alone.
    let calendar: Calendar

    func dayText(for date: Date) -> String {
        date.shortFormatted(in: calendar)
    }

    var supportingDaysNewestFirst: [HistoryRecurringCaloriePatternDay] {
        supportingDays.sorted { $0.date > $1.date }
    }

    var windowDayCount: Int {
        let start = calendar.startOfDay(for: windowStart)
        let end = calendar.startOfDay(for: windowEnd)
        return (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1
    }

    var mealName: String {
        HistoryRecurringCaloriePatternWording.mealName(for: mealType)
    }

    var headline: String {
        switch kind {
        case .weekdayMeal:
            return "\(weekdayPlural) run \(outcome.goalText)"
        case .mealOnly:
            let verb = HistoryRecurringCaloriePatternWording.agreeing(
                with: mealType,
                singular: "is",
                plural: "are"
            )
            let size = mealDifferenceCalories < 0 ? "smaller" : "bigger"
            return "\(mealName) \(verb) \(size) on \(outcome.goalDaysText)"
        }
    }

    var mealComparison: HistoryRecurringCaloriePatternPhrase {
        let verb = HistoryRecurringCaloriePatternWording.agreeing(
            with: mealType,
            singular: "averages",
            plural: "average"
        )
        let patternAverage = HistoryRecurringCaloriePatternWording.calories(supportingMealAverageCalories)
        let otherAverage = HistoryRecurringCaloriePatternWording.calories(comparisonMealAverageCalories)

        switch kind {
        case .weekdayMeal:
            return HistoryRecurringCaloriePatternPhrase(runs: [
                .plain("\(mealName) \(verb) "),
                .emphasised(patternAverage),
                .plain(" kcal on \(patternDaysName) vs "),
                .emphasised(otherAverage),
                .plain(" other days"),
            ])
        case .mealOnly:
            return HistoryRecurringCaloriePatternPhrase(runs: [
                .plain("\(mealName) \(verb) "),
                .emphasised(patternAverage),
                .plain(" kcal on those days vs "),
                .emphasised(otherAverage),
                .plain(" on others"),
            ])
        }
    }

    var frequencyText: String {
        switch kind {
        case .weekdayMeal:
            let share = supportingDays.count == cohortDayCount
                ? "All \(cohortDayCount)"
                : "\(supportingDays.count) of \(cohortDayCount)"
            return "\(share) \(weekdayPlural) \(outcome.goalText)"
        case .mealOnly:
            return "Across \(supportingDays.count) \(outcome.goalDaysText)"
        }
    }

    var weekdayName: String {
        Self.weekdayName(for: weekday)
    }

    private var weekdayPlural: String {
        HistoryRecurringCaloriePatternWording.weekdayPlural(weekdayName)
    }

    private var patternDaysName: String {
        HistoryRecurringCaloriePatternWording.patternDaysName(
            kind: kind,
            weekdayName: weekdayName,
            outcome: outcome,
            supportingDayCount: supportingDays.count,
            cohortDayCount: cohortDayCount
        )
    }

    private static func weekdayName(for weekday: Int?) -> String {
        switch weekday {
        case 1: "Sunday"
        case 2: "Monday"
        case 3: "Tuesday"
        case 4: "Wednesday"
        case 5: "Thursday"
        case 6: "Friday"
        case 7: "Saturday"
        default: ""
        }
    }
}

struct HistoryRecurringCaloriePatternDay: Identifiable {
    let date: Date
    let dailyCalorieTarget: Int
    let totalCalories: Double
    let mealCalories: Double
    let mealFoods: [HistoryFoodSummary]

    var id: Date { date }
}

struct HistoryRecurringCaloriePatternEngine {
    private static let comparisonEpsilon = 0.000_000_001

    let policy: HistoryRecurringCaloriePatternPolicy

    init(policy: HistoryRecurringCaloriePatternPolicy = .standard) {
        self.policy = policy
    }

    func discover(
        entries: [FoodLogEntry],
        targetResolver: HistoryDayTargetResolver,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> HistoryRecurringCaloriePattern? {
        let window = evidenceWindow(now: now, calendar: calendar)
        let eligibleDays = eligibleDays(
            entries: entries,
            targetResolver: targetResolver,
            window: window,
            calendar: calendar
        )

        let candidates = weekdayCandidates(
            days: eligibleDays,
            window: window,
            calendar: calendar
        ) + mealOnlyCandidates(
            days: eligibleDays,
            window: window,
            calendar: calendar
        )

        return candidates.sorted { lhs, rhs in
            Self.ranksBefore(lhs, rhs)
        }.first?.pattern
    }

    func evidenceWindow(
        now: Date,
        calendar: Calendar
    ) -> ClosedRange<Date> {
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let start = calendar.date(
            byAdding: .day,
            value: -(policy.windowDayCount - 1),
            to: yesterday
        ) ?? yesterday
        return start ... yesterday
    }

    private func eligibleDays(
        entries: [FoodLogEntry],
        targetResolver: HistoryDayTargetResolver,
        window: ClosedRange<Date>,
        calendar: Calendar
    ) -> [EligibleDay] {
        let entriesByDay = Dictionary(grouping: entries) {
            calendar.startOfDay(for: $0.date)
        }

        return entriesByDay.compactMap { date, dayEntries in
            guard window.contains(date), !dayEntries.isEmpty else { return nil }
            let target = targetResolver.target(for: date, calendar: calendar)
            guard !target.isEstimated, target.calories > 0 else { return nil }

            return EligibleDay(
                date: date,
                entries: dayEntries,
                target: target.calories
            )
        }
        .sorted { $0.date < $1.date }
    }

    private func weekdayCandidates(
        days: [EligibleDay],
        window: ClosedRange<Date>,
        calendar: Calendar
    ) -> [Candidate] {
        (1...7).flatMap { weekday in
            let cohort = days.filter {
                calendar.component(.weekday, from: $0.date) == weekday
            }
            guard cohort.count >= policy.minimumWeekdayOccurrences else { return [Candidate]() }

            let outcomeBaseline = days.filter {
                calendar.component(.weekday, from: $0.date) != weekday
            }
            guard !outcomeBaseline.isEmpty else { return [Candidate]() }

            return HistoryRecurringCalorieOutcome.allCases.compactMap { outcome in
                let supporting = cohort.filter { $0.status == outcome.status }
                let outcomeRate = Double(supporting.count) / Double(cohort.count)
                guard outcomeRate + Self.comparisonEpsilon
                    >= policy.minimumWeekdayOutcomeRate else {
                    return nil
                }

                let comparisonOutcomeCount = outcomeBaseline.filter {
                    $0.status == outcome.status
                }.count
                let comparisonOutcomeRate = Double(comparisonOutcomeCount) / Double(outcomeBaseline.count)
                let rateSeparation = outcomeRate - comparisonOutcomeRate
                guard rateSeparation + Self.comparisonEpsilon
                    >= policy.minimumOutcomeRateSeparation else {
                    return nil
                }

                // The meal baseline is every other eligible logged day, including
                // an occasional same-weekday day with a different outcome.
                let supportingDates = Set(supporting.map(\.date))
                let mealComparison = days.filter { !supportingDates.contains($0.date) }
                guard !mealComparison.isEmpty,
                      let mealDifference = qualifyingMealDifference(
                        supporting: supporting,
                        comparison: mealComparison,
                        outcome: outcome
                      ) else {
                    return nil
                }

                let identifier = [
                    HistoryRecurringCaloriePatternKind.weekdayMeal.rawValue,
                    weekday.formatted(),
                    outcome.rawValue,
                    mealDifference.meal.rawValue,
                ].joined(separator: "|")

                let pattern = HistoryRecurringCaloriePattern(
                    id: identifier,
                    kind: .weekdayMeal,
                    outcome: outcome,
                    weekday: weekday,
                    mealType: mealDifference.meal,
                    supportingDays: supporting.map {
                        patternDay(from: $0, meal: mealDifference.meal)
                    },
                    cohortDayCount: cohort.count,
                    outcomeComparisonCount: comparisonOutcomeCount,
                    outcomeComparisonDayCount: outcomeBaseline.count,
                    mealComparisonDayCount: mealComparison.count,
                    eligibleDayCount: days.count,
                    supportingMealAverageCalories: mealDifference.supportingAverage,
                    comparisonMealAverageCalories: mealDifference.comparisonAverage,
                    mealDifferenceCalories: mealDifference.calorieDifference,
                    targetRelativeMealDifference: mealDifference.targetRelativeDifference,
                    rateSeparation: rateSeparation,
                    windowStart: window.lowerBound,
                    windowEnd: window.upperBound,
                    calendar: calendar
                )

                return Candidate(
                    pattern: pattern,
                    supportingDayCount: supporting.count
                )
            }
        }
    }

    private func mealOnlyCandidates(
        days: [EligibleDay],
        window: ClosedRange<Date>,
        calendar: Calendar
    ) -> [Candidate] {
        HistoryRecurringCalorieOutcome.allCases.compactMap { outcome in
            let supporting = days.filter { $0.status == outcome.status }
            let comparison = days.filter { $0.status != outcome.status }
            guard supporting.count >= policy.minimumMealOnlyGroupCount,
                  comparison.count >= policy.minimumMealOnlyComparisonCount,
                  calendarWeekCount(for: supporting, calendar: calendar)
                    >= policy.minimumMealOnlyCalendarWeekCount,
                  let mealDifference = qualifyingMealDifference(
                    supporting: supporting,
                    comparison: comparison,
                    outcome: outcome
                  ) else {
                return nil
            }

            let totalDifference = average(supporting.map(\.totalCalories))
                - average(comparison.map(\.totalCalories))
            guard abs(totalDifference) > 0,
                  abs(mealDifference.calorieDifference) / abs(totalDifference)
                    + Self.comparisonEpsilon >= policy.minimumMealAttribution else {
                return nil
            }

            let identifier = [
                HistoryRecurringCaloriePatternKind.mealOnly.rawValue,
                outcome.rawValue,
                mealDifference.meal.rawValue,
            ].joined(separator: "|")
            let pattern = HistoryRecurringCaloriePattern(
                id: identifier,
                kind: .mealOnly,
                outcome: outcome,
                weekday: nil,
                mealType: mealDifference.meal,
                supportingDays: supporting.map {
                    patternDay(from: $0, meal: mealDifference.meal)
                },
                cohortDayCount: supporting.count,
                outcomeComparisonCount: 0,
                outcomeComparisonDayCount: comparison.count,
                mealComparisonDayCount: comparison.count,
                eligibleDayCount: days.count,
                supportingMealAverageCalories: mealDifference.supportingAverage,
                comparisonMealAverageCalories: mealDifference.comparisonAverage,
                mealDifferenceCalories: mealDifference.calorieDifference,
                targetRelativeMealDifference: mealDifference.targetRelativeDifference,
                rateSeparation: 1,
                windowStart: window.lowerBound,
                windowEnd: window.upperBound,
                calendar: calendar
            )

            return Candidate(
                pattern: pattern,
                supportingDayCount: supporting.count
            )
        }
    }

    private func qualifyingMealDifference(
        supporting: [EligibleDay],
        comparison: [EligibleDay],
        outcome: HistoryRecurringCalorieOutcome
    ) -> MealDifference? {
        guard !supporting.isEmpty, !comparison.isEmpty else { return nil }

        // The meal with the largest absolute average calorie difference wins.
        // Stable meal raw values resolve exact ties before direction/materiality
        // are tested, so a weaker second-place meal cannot rescue a candidate.
        let differences = MealType.allCases.map { meal -> MealDifference in
            let supportingAverage = average(supporting.map { $0.calories(for: meal) })
            let comparisonAverage = average(comparison.map { $0.calories(for: meal) })

            // Average per-day meal/target shares rather than dividing aggregate
            // calories by a current or blended target. This gives every exact
            // historical target its own denominator and never reinterprets it.
            let targetRelativeDifference = average(
                supporting.map { $0.targetRelativeCalories(for: meal) }
            ) - average(
                comparison.map { $0.targetRelativeCalories(for: meal) }
            )

            return MealDifference(
                meal: meal,
                supportingAverage: supportingAverage,
                comparisonAverage: comparisonAverage,
                targetRelativeDifference: targetRelativeDifference
            )
        }

        guard let largest = differences.sorted(by: { lhs, rhs in
            if abs(lhs.calorieDifference) == abs(rhs.calorieDifference) {
                return lhs.meal.rawValue < rhs.meal.rawValue
            }
            return abs(lhs.calorieDifference) > abs(rhs.calorieDifference)
        }).first else {
            return nil
        }

        let pointsInOutcomeDirection: Bool
        switch outcome {
        case .above:
            pointsInOutcomeDirection = largest.calorieDifference > 0
                && largest.targetRelativeDifference > 0
        case .below:
            pointsInOutcomeDirection = largest.calorieDifference < 0
                && largest.targetRelativeDifference < 0
        }

        guard pointsInOutcomeDirection,
              abs(largest.targetRelativeDifference) + Self.comparisonEpsilon
                >= policy.minimumTargetRelativeMealDifference else {
            return nil
        }
        return largest
    }

    private func calendarWeekCount(
        for days: [EligibleDay],
        calendar: Calendar
    ) -> Int {
        Set(days.map { day in
            let components = calendar.dateComponents(
                [.yearForWeekOfYear, .weekOfYear],
                from: day.date
            )
            return "\(components.yearForWeekOfYear ?? 0)-\(components.weekOfYear ?? 0)"
        }).count
    }

    private func patternDay(
        from day: EligibleDay,
        meal: MealType
    ) -> HistoryRecurringCaloriePatternDay {
        let mealEntries = day.entries.filter { $0.mealType == meal }
        return HistoryRecurringCaloriePatternDay(
            date: day.date,
            dailyCalorieTarget: day.target,
            totalCalories: day.totalCalories,
            mealCalories: day.calories(for: meal),
            mealFoods: foodSummaries(from: mealEntries)
        )
    }

    private func foodSummaries(
        from entries: [FoodLogEntry]
    ) -> [HistoryFoodSummary] {
        var accumulators: [String: FoodAccumulator] = [:]

        for entry in entries {
            let name = entry.historicalFoodName
            let key = name
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { continue }

            var accumulator = accumulators[key] ?? FoodAccumulator(id: key, name: name)
            accumulator.entryCount += 1
            accumulator.portionGrams += entry.portionGrams
            accumulator.calories += entry.calories
            accumulators[key] = accumulator
        }

        return accumulators.values
            .map(\.summary)
            .sorted {
                if $0.calories == $1.calories {
                    return $0.name.localizedStandardCompare($1.name) == .orderedAscending
                }
                return $0.calories > $1.calories
            }
    }

    private func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func ranksBefore(_ lhs: Candidate, _ rhs: Candidate) -> Bool {
        if lhs.pattern.rateSeparation != rhs.pattern.rateSeparation {
            return lhs.pattern.rateSeparation > rhs.pattern.rateSeparation
        }
        if abs(lhs.pattern.targetRelativeMealDifference)
            != abs(rhs.pattern.targetRelativeMealDifference) {
            return abs(lhs.pattern.targetRelativeMealDifference)
                > abs(rhs.pattern.targetRelativeMealDifference)
        }
        if lhs.supportingDayCount != rhs.supportingDayCount {
            return lhs.supportingDayCount > rhs.supportingDayCount
        }
        return lhs.pattern.id < rhs.pattern.id
    }
}

private extension HistoryRecurringCaloriePatternEngine {
    struct EligibleDay {
        let date: Date
        let entries: [FoodLogEntry]
        let target: Int

        var totalCalories: Double {
            entries.reduce(0) { $0 + $1.calories }
        }

        var status: HistoryGoalStatus {
            HistoryGoalStatus.calorieStatus(
                calories: totalCalories,
                loggedCount: entries.count,
                targetCalories: target
            )
        }

        func calories(for meal: MealType) -> Double {
            entries
                .filter { $0.mealType == meal }
                .reduce(0) { $0 + $1.calories }
        }

        func targetRelativeCalories(for meal: MealType) -> Double {
            calories(for: meal) / Double(target)
        }
    }

    struct MealDifference {
        let meal: MealType
        let supportingAverage: Double
        let comparisonAverage: Double
        let targetRelativeDifference: Double

        var calorieDifference: Double {
            supportingAverage - comparisonAverage
        }
    }

    struct Candidate {
        let pattern: HistoryRecurringCaloriePattern
        let supportingDayCount: Int
    }

    struct FoodAccumulator {
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
}
