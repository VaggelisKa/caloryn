import Foundation

/// The privacy-minimized input used by contextual suggestion ranking.
///
/// Names, barcodes, nutrition, health data, and search traffic never enter the
/// ranker. The adapter below creates this snapshot entirely from local models.
struct ContextualSuggestionCandidate: Equatable {
    let foodID: UUID
    let isAvailable: Bool
    let resolvedPortionGrams: Double
}

struct ContextualSuggestionObservation: Equatable {
    let entryID: UUID
    let foodID: UUID
    let logDate: Date
    let createdAt: Date
    let meal: MealType
}

struct ContextualFoodSuggestion: Identifiable, Equatable {
    enum Reason: String, Equatable {
        case sameMeal
        case usualTime
        case sameWeekday
        case recentlyUsed
        case frequentlyUsed

        var displayName: String {
            switch self {
            case .sameMeal: "Often logged for this meal"
            case .usualTime: "Often logged around this time"
            case .sameWeekday: "Often logged on this weekday"
            case .recentlyUsed: "Logged recently"
            case .frequentlyUsed: "Logged on several days"
            }
        }
    }

    struct Score: Equatable {
        let meal: Double
        let time: Double
        let weekday: Double
        let recency: Double
        let frequency: Double

        nonisolated var total: Double { meal + time + weekday + recency + frequency }
    }

    let foodID: UUID
    let resolvedPortionGrams: Double
    let score: Score
    let lastLogDate: Date
    let reasons: [Reason]

    var id: UUID { foodID }
}

enum ContextualFoodSuggestionRanker {
    static let historyDayCount = 90
    static let minimumGlobalHistoryDays = 3
    static let minimumCandidateOccurrences = 2
    static let minimumCandidateDays = 2
    static let minimumScore = 55.0
    static let maximumSuggestions = 5

    static func rank(
        candidates: [ContextualSuggestionCandidate],
        observations: [ContextualSuggestionObservation],
        destinationDate: Date,
        destinationMeal: MealType,
        now: Date,
        calendar: Calendar = .current
    ) -> [ContextualFoodSuggestion] {
        let today = calendar.startOfDay(for: now)
        guard let historyStart = calendar.date(
            byAdding: .day,
            value: -(historyDayCount - 1),
            to: today
        ) else {
            return []
        }

        let candidateByID = Dictionary(
            uniqueKeysWithValues: candidates.map { ($0.foodID, $0) }
        )
        let eligibleIDs = Set(
            candidates
                .filter {
                    $0.isAvailable
                        && FavoriteFoodLogging.isSafePortion($0.resolvedPortionGrams)
                }
                .map(\.foodID)
        )
        let history = observations.filter { observation in
            let day = calendar.startOfDay(for: observation.logDate)
            return eligibleIDs.contains(observation.foodID)
                && day >= historyStart
                && day <= today
        }
        let globalDays = Set(history.map { calendar.startOfDay(for: $0.logDate) })
        guard globalDays.count >= minimumGlobalHistoryDays else { return [] }

        let destinationDay = calendar.startOfDay(for: destinationDate)
        let appliesTimeContext = calendar.isDate(destinationDay, inSameDayAs: today)
        let targetTimeBucket = TimeBucket(date: now, calendar: calendar)
        let targetWeekday = calendar.component(.weekday, from: destinationDay)
        let grouped = Dictionary(grouping: history, by: \.foodID)

        return grouped.compactMap { foodID, foodHistory in
            guard let candidate = candidateByID[foodID],
                  foodHistory.count >= minimumCandidateOccurrences else {
                return nil
            }

            let distinctDays = Set(
                foodHistory.map { calendar.startOfDay(for: $0.logDate) }
            )
            guard distinctDays.count >= minimumCandidateDays else { return nil }

            let matchingMealCount = foodHistory.count { $0.meal == destinationMeal }
            guard matchingMealCount > 0 else { return nil }

            let count = Double(foodHistory.count)
            let mealScore = 40 * Double(matchingMealCount) / count
            let timeScore: Double
            if appliesTimeContext {
                let matchingTimeCount = foodHistory.count {
                    TimeBucket(date: $0.createdAt, calendar: calendar) == targetTimeBucket
                }
                timeScore = 15 * Double(matchingTimeCount) / count
            } else {
                timeScore = 0
            }
            let matchingWeekdayCount = foodHistory.count {
                calendar.component(.weekday, from: $0.logDate) == targetWeekday
            }
            let weekdayScore = 10 * Double(matchingWeekdayCount) / count
            let lastLogDate = foodHistory.map(\.logDate).max() ?? .distantPast
            let recencyDays = max(
                0,
                calendar.dateComponents(
                    [.day],
                    from: calendar.startOfDay(for: lastLogDate),
                    to: today
                ).day ?? historyDayCount
            )
            let recencyScore = recencyScore(daysAgo: recencyDays)
            let frequencyScore = Double(min(10, distinctDays.count))
            let score = ContextualFoodSuggestion.Score(
                meal: mealScore,
                time: timeScore,
                weekday: weekdayScore,
                recency: recencyScore,
                frequency: frequencyScore
            )
            guard score.total >= minimumScore else { return nil }

            return ContextualFoodSuggestion(
                foodID: foodID,
                resolvedPortionGrams: candidate.resolvedPortionGrams,
                score: score,
                lastLogDate: lastLogDate,
                reasons: reasons(for: score)
            )
        }
        .sorted(by: suggestionSort)
        .prefix(maximumSuggestions)
        .map { $0 }
    }

    private static func recencyScore(daysAgo: Int) -> Double {
        switch daysAgo {
        case 0: 25
        case 1: 24
        case 2...3: 21
        case 4...7: 17
        case 8...14: 12
        case 15...30: 7
        case 31...60: 3
        case 61...89: 1
        default: 0
        }
    }

    private static func reasons(
        for score: ContextualFoodSuggestion.Score
    ) -> [ContextualFoodSuggestion.Reason] {
        var values: [ContextualFoodSuggestion.Reason] = []
        if score.meal > 0 { values.append(.sameMeal) }
        if score.time > 0 { values.append(.usualTime) }
        if score.weekday > 0 { values.append(.sameWeekday) }
        if score.recency >= 12 { values.append(.recentlyUsed) }
        if score.frequency >= 3 { values.append(.frequentlyUsed) }
        return values
    }

    nonisolated private static func suggestionSort(
        _ lhs: ContextualFoodSuggestion,
        _ rhs: ContextualFoodSuggestion
    ) -> Bool {
        let lhsValues = [
            lhs.score.total,
            lhs.score.meal,
            lhs.score.time,
            lhs.score.weekday,
            lhs.score.recency,
            lhs.score.frequency,
        ]
        let rhsValues = [
            rhs.score.total,
            rhs.score.meal,
            rhs.score.time,
            rhs.score.weekday,
            rhs.score.recency,
            rhs.score.frequency,
        ]
        for (lhsValue, rhsValue) in zip(lhsValues, rhsValues) where lhsValue != rhsValue {
            return lhsValue > rhsValue
        }
        if lhs.lastLogDate != rhs.lastLogDate {
            return lhs.lastLogDate > rhs.lastLogDate
        }
        return lhs.foodID.uuidString < rhs.foodID.uuidString
    }

    private enum TimeBucket: Equatable {
        case late
        case early
        case midday
        case evening

        init(date: Date, calendar: Calendar) {
            switch calendar.component(.hour, from: date) {
            case 4..<10: self = .early
            case 10..<15: self = .midday
            case 15..<21: self = .evening
            default: self = .late
            }
        }
    }
}

@MainActor
enum ContextualFoodSuggestionAdapter {
    static func rank(
        foods: [FoodItem],
        entries: [FoodLogEntry],
        destinationDate: Date,
        destinationMeal: MealType,
        destinationSnackIndex: Int = 0,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [ContextualFoodSuggestion] {
        let candidates = foods.map { food in
            ContextualSuggestionCandidate(
                foodID: food.id,
                isAvailable: FavoriteFoodLogging.isAvailableForLogging(food),
                resolvedPortionGrams: resolvedPortion(
                    for: food,
                    destinationDate: destinationDate,
                    destinationMeal: destinationMeal,
                    destinationSnackIndex: destinationSnackIndex,
                    calendar: calendar
                )
            )
        }
        let observations = entries.compactMap { entry -> ContextualSuggestionObservation? in
            // A missing relationship means the source was deleted. Never fall
            // back to names: duplicate names remain distinct and deletions do
            // not leak stale candidates back into suggestions.
            guard let foodID = entry.foodItem?.id else { return nil }
            return ContextualSuggestionObservation(
                entryID: entry.id,
                foodID: foodID,
                logDate: entry.date,
                createdAt: entry.createdAt,
                meal: entry.mealType
            )
        }
        return ContextualFoodSuggestionRanker.rank(
            candidates: candidates,
            observations: observations,
            destinationDate: destinationDate,
            destinationMeal: destinationMeal,
            now: now,
            calendar: calendar
        )
    }

    static func resolvedPortion(
        for food: FoodItem,
        destinationDate: Date,
        destinationMeal: MealType,
        destinationSnackIndex: Int = 0,
        calendar: Calendar = .current
    ) -> Double {
        let plan = FavoriteFoodLogging.plan(
            for: food,
            destinationMeal: destinationMeal,
            destinationDate: destinationDate,
            destinationSnackIndex: destinationSnackIndex,
            calendar: calendar
        )
        if case .log(let portionGrams) = plan.action {
            return portionGrams
        }
        return fallbackPortion(for: food)
    }

    static func fallbackPortion(for food: FoodItem) -> Double {
        if let serving = food.defaultServingG,
           FavoriteFoodLogging.isSafePortion(serving) {
            return serving
        }
        return 100
    }
}
