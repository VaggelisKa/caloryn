import XCTest
@testable import Caloryn

final class ContextualFoodSuggestionRankerTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testSparseGlobalHistoryProducesNoSuggestions() {
        let foodID = UUID()
        let now = date(2026, 7, 22, 11)
        let result = rank(
            foodIDs: [foodID],
            observations: [
                observation(foodID: foodID, date: date(2026, 7, 22, 11)),
                observation(foodID: foodID, date: date(2026, 7, 21, 11)),
            ],
            now: now
        )

        XCTAssertTrue(result.isEmpty)
    }

    func testCandidateRequiresTwoOccurrencesOnTwoDaysAndTargetMealHistory() {
        let eligible = UUID()
        let oneDayOnly = UUID()
        let wrongMeal = UUID()
        let now = date(2026, 7, 22, 11)
        let result = rank(
            foodIDs: [eligible, oneDayOnly, wrongMeal],
            observations: [
                observation(foodID: eligible, date: date(2026, 7, 22, 11)),
                observation(foodID: eligible, date: date(2026, 7, 21, 11)),
                observation(foodID: eligible, date: date(2026, 7, 20, 11)),
                observation(foodID: oneDayOnly, date: date(2026, 7, 22, 8)),
                observation(foodID: oneDayOnly, date: date(2026, 7, 22, 9)),
                observation(foodID: wrongMeal, date: date(2026, 7, 22, 18), meal: .dinner),
                observation(foodID: wrongMeal, date: date(2026, 7, 21, 18), meal: .dinner),
            ],
            now: now
        )

        XCTAssertEqual(result.map(\.foodID), [eligible])
    }

    func testScoreUsesDocumentedMealTimeWeekdayRecencyAndFrequencyWeights() throws {
        let foodID = UUID()
        let now = date(2026, 7, 22, 11) // Wednesday, midday bucket
        let result = rank(
            foodIDs: [foodID],
            observations: [
                observation(foodID: foodID, date: date(2026, 7, 22, 11), meal: .breakfast),
                observation(foodID: foodID, date: date(2026, 7, 15, 12), meal: .breakfast),
                observation(foodID: foodID, date: date(2026, 7, 14, 18), meal: .lunch),
            ],
            now: now
        )
        let score = try XCTUnwrap(result.first?.score)

        XCTAssertEqual(score.meal, 40 * 2 / 3, accuracy: 0.0001)
        XCTAssertEqual(score.time, 15 * 2 / 3, accuracy: 0.0001)
        XCTAssertEqual(score.weekday, 10 * 2 / 3, accuracy: 0.0001)
        XCTAssertEqual(score.recency, 25)
        XCTAssertEqual(score.frequency, 3)
        XCTAssertEqual(score.total, 71.3333, accuracy: 0.001)
    }

    func testTimeScoreIsZeroForRetroactiveDestination() throws {
        let foodID = UUID()
        let now = date(2026, 7, 22, 11)
        let result = ContextualFoodSuggestionRanker.rank(
            candidates: [candidate(foodID)],
            observations: [
                observation(foodID: foodID, date: date(2026, 7, 22, 11)),
                observation(foodID: foodID, date: date(2026, 7, 21, 11)),
                observation(foodID: foodID, date: date(2026, 7, 20, 11)),
            ],
            destinationDate: date(2026, 7, 21, 11),
            destinationMeal: .breakfast,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(try XCTUnwrap(result.first).score.time, 0)
    }

    func testHistoryOutsideNinetyDayWindowDoesNotQualify() {
        let foodID = UUID()
        let now = date(2026, 7, 22, 11)
        let result = rank(
            foodIDs: [foodID],
            observations: [
                observation(foodID: foodID, date: date(2026, 4, 22, 11)),
                observation(foodID: foodID, date: date(2026, 4, 21, 11)),
                observation(foodID: foodID, date: date(2026, 4, 20, 11)),
            ],
            now: now
        )

        XCTAssertTrue(result.isEmpty)
    }

    func testTiesResolveByFoodUUIDAndLimitIsFive() {
        let foodIDs = (1...7).map {
            UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", $0))!
        }.reversed()
        let now = date(2026, 7, 22, 11)
        let observations = foodIDs.flatMap { foodID in
            [0, 1, 2].map { offset in
                observation(
                    foodID: foodID,
                    date: calendar.date(byAdding: .day, value: -offset, to: now)!
                )
            }
        }
        let result = rank(
            foodIDs: Array(foodIDs),
            observations: observations,
            now: now
        )

        XCTAssertEqual(result.count, 5)
        XCTAssertEqual(
            result.map(\.foodID.uuidString),
            (1...5).map { String(format: "00000000-0000-0000-0000-%012d", $0) }
        )
    }

    func testUnavailableCandidateAndUnsafePortionAreExcluded() {
        let unavailable = UUID()
        let unsafe = UUID()
        let now = date(2026, 7, 22, 11)
        let observations = [unavailable, unsafe].flatMap { foodID in
            [0, 1, 2].map { offset in
                observation(
                    foodID: foodID,
                    date: calendar.date(byAdding: .day, value: -offset, to: now)!
                )
            }
        }
        let result = ContextualFoodSuggestionRanker.rank(
            candidates: [
                ContextualSuggestionCandidate(
                    foodID: unavailable,
                    isAvailable: false,
                    resolvedPortionGrams: 100
                ),
                ContextualSuggestionCandidate(
                    foodID: unsafe,
                    isAvailable: true,
                    resolvedPortionGrams: .infinity
                ),
            ],
            observations: observations,
            destinationDate: now,
            destinationMeal: .breakfast,
            now: now,
            calendar: calendar
        )

        XCTAssertTrue(result.isEmpty)
    }

    private func rank(
        foodIDs: [UUID],
        observations: [ContextualSuggestionObservation],
        now: Date
    ) -> [ContextualFoodSuggestion] {
        ContextualFoodSuggestionRanker.rank(
            candidates: foodIDs.map(candidate),
            observations: observations,
            destinationDate: now,
            destinationMeal: .breakfast,
            now: now,
            calendar: calendar
        )
    }

    private func candidate(_ foodID: UUID) -> ContextualSuggestionCandidate {
        ContextualSuggestionCandidate(
            foodID: foodID,
            isAvailable: true,
            resolvedPortionGrams: 100
        )
    }

    private func observation(
        foodID: UUID,
        date: Date,
        meal: MealType = .breakfast
    ) -> ContextualSuggestionObservation {
        ContextualSuggestionObservation(
            entryID: UUID(),
            foodID: foodID,
            logDate: calendar.startOfDay(for: date),
            createdAt: date,
            meal: meal
        )
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int
    ) -> Date {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour
        ))!
    }
}

@MainActor
final class ContextualFoodSuggestionAdapterTests: XCTestCase {
    func testAdapterKeepsDuplicateNamesSeparateAndExcludesDeletedSources() {
        let now = makeTestDate(year: 2026, month: 7, day: 22, hour: 11)
        let deletedFood = makeTestFoodItem(name: "Yogurt")
        let liveFood = makeTestFoodItem(name: "Yogurt")
        let deletedEntries = makeEntries(food: deletedFood, now: now)
        let liveEntries = makeEntries(food: liveFood, now: now)
        deletedEntries.forEach { $0.foodItem = nil }

        let suggestions = ContextualFoodSuggestionAdapter.rank(
            foods: [deletedFood, liveFood],
            entries: deletedEntries + liveEntries,
            destinationDate: now,
            destinationMeal: .breakfast,
            now: now
        )

        XCTAssertEqual(suggestions.map(\.foodID), [liveFood.id])
    }

    func testAdapterReusesFavoriteLoggingPortionResolution() {
        let now = makeTestDate(year: 2026, month: 7, day: 22, hour: 11)
        let food = makeTestFoodItem(name: "Oats", defaultServingG: 80)
        let entries = makeEntries(food: food, now: now, portions: [120, 130, 175])

        let suggestions = ContextualFoodSuggestionAdapter.rank(
            foods: [food],
            entries: entries,
            destinationDate: now,
            destinationMeal: .breakfast,
            now: now
        )

        XCTAssertEqual(suggestions.first?.resolvedPortionGrams, 175)
    }

    func testAdapterSnapshotContainsNoNamesBarcodesOrNutrition() {
        let candidateFields = Set(Mirror(reflecting: ContextualSuggestionCandidate(
            foodID: UUID(),
            isAvailable: true,
            resolvedPortionGrams: 100
        )).children.compactMap(\.label))
        let observationFields = Set(Mirror(reflecting: ContextualSuggestionObservation(
            entryID: UUID(),
            foodID: UUID(),
            logDate: .now,
            createdAt: .now,
            meal: .lunch
        )).children.compactMap(\.label))

        XCTAssertEqual(candidateFields, ["foodID", "isAvailable", "resolvedPortionGrams"])
        XCTAssertEqual(observationFields, ["entryID", "foodID", "logDate", "createdAt", "meal"])
    }

    func testAdapterNeverInfersAuthoredMealIdentityFromComponentNames() {
        let now = makeTestDate(year: 2026, month: 7, day: 22, hour: 11)
        let component = makeTestFoodItem(name: "Breakfast Bowl")
        let meal = MealTemplate(
            name: "Breakfast Bowl",
            defaultMeal: .breakfast,
            defaultSnackIndex: 0,
            creationOperationID: UUID(),
            creationFingerprint: "meal-history-boundary"
        )
        let entries = makeEntries(food: component, now: now)

        let suggestions = ContextualFoodSuggestionAdapter.rank(
            foods: [component],
            entries: entries,
            destinationDate: now,
            destinationMeal: .breakfast,
            now: now
        )

        XCTAssertEqual(suggestions.map(\.foodID), [component.id])
        XCTAssertFalse(suggestions.map(\.foodID).contains(meal.id))
    }

    private func makeEntries(
        food: FoodItem,
        now: Date,
        portions: [Double] = [100, 100, 100]
    ) -> [FoodLogEntry] {
        portions.enumerated().map { offset, portion in
            let date = Calendar.current.date(byAdding: .day, value: offset - 2, to: now)!
            let entry = makeTestEntry(
                date: date,
                mealType: .breakfast,
                foodItem: food,
                portionGrams: portion
            )
            entry.createdAt = date
            return entry
        }
    }
}
