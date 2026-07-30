import Foundation

/// Thresholds for the deterministic recurring-calorie observation shown in History.
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

    var targetText: String {
        "\(rawValue) target"
    }
}

enum HistoryRecurringCaloriePatternKind: String {
    case weekdayMeal
    case mealOnly
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
    let mealDifferenceCalories: Double
    let targetRelativeMealDifference: Double
    let rateSeparation: Double
    let windowStart: Date
    let windowEnd: Date

    var headline: String {
        switch kind {
        case .weekdayMeal:
            "\(weekdayName) \(mealPlural.lowercased()) stood out"
        case .mealOnly:
            "\(mealPlural) stood out on \(outcome.targetText) days"
        }
    }

    var comparisonText: String {
        let roundedDifference = abs(mealDifferenceCalories).rounded().truncatedSafely
        let direction = mealDifferenceCalories > 0 ? "more" : "less"
        let mealName = mealType == .snack ? "Snacks" : mealType.displayName

        switch kind {
        case .weekdayMeal:
            return "\(supportingDays.count) of \(cohortDayCount) logged \(weekdayPlural) were \(outcome.targetText). \(mealName) averaged \(roundedDifference.formatted()) kcal \(direction) than on your other eligible logged days."
        case .mealOnly:
            return "Across \(supportingDays.count) \(outcome.targetText) logged days, \(mealName.lowercased()) averaged \(roundedDifference.formatted()) kcal \(direction) than on your other eligible logged days."
        }
    }

    var basisText: String {
        "Based on \(eligibleDayCount) logged days · Last 30 days"
    }

    var outcomeComparisonText: String {
        switch kind {
        case .weekdayMeal:
            "\(outcomeComparisonCount) of \(outcomeComparisonDayCount) other eligible logged days were \(outcome.targetText)."
        case .mealOnly:
            "\(mealComparisonDayCount) other eligible logged days form the comparison."
        }
    }

    var weekdayName: String {
        Self.weekdayName(for: weekday)
    }

    private var weekdayPlural: String {
        "\(weekdayName)s"
    }

    private var mealPlural: String {
        switch mealType {
        case .breakfast: "Breakfasts"
        case .lunch: "Lunches"
        case .dinner: "Dinners"
        case .snack: "Snacks"
        }
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
                    mealDifferenceCalories: mealDifference.calorieDifference,
                    targetRelativeMealDifference: mealDifference.targetRelativeDifference,
                    rateSeparation: rateSeparation,
                    windowStart: window.lowerBound,
                    windowEnd: window.upperBound
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
                mealDifferenceCalories: mealDifference.calorieDifference,
                targetRelativeMealDifference: mealDifference.targetRelativeDifference,
                rateSeparation: 1,
                windowStart: window.lowerBound,
                windowEnd: window.upperBound
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
            let calorieDifference = average(supporting.map { $0.calories(for: meal) })
                - average(comparison.map { $0.calories(for: meal) })

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
                calorieDifference: calorieDifference,
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
            let storedName = entry.foodName.trimmingCharacters(in: .whitespacesAndNewlines)
            let liveName = entry.foodItem?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let name = storedName.isEmpty ? (liveName.isEmpty ? "Unnamed food" : liveName) : storedName
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
        let calorieDifference: Double
        let targetRelativeDifference: Double
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
