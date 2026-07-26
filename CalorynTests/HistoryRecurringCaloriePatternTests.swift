import XCTest
@testable import Caloryn

@MainActor
final class HistoryRecurringCaloriePatternTests: XCTestCase {
    private let now = makeTestDate(year: 2026, month: 2, day: 1)
    private let target = 2_000

    func testEvidenceWindowIsThirtyCalendarDaysEndingYesterdayAndExcludesToday() throws {
        let window = HistoryRecurringCaloriePatternEngine().evidenceWindow(
            now: now,
            calendar: .current
        )

        XCTAssertEqual(window.lowerBound, makeTestDate(year: 2026, month: 1, day: 2).startOfDay)
        XCTAssertEqual(window.upperBound, makeTestDate(year: 2026, month: 1, day: 31).startOfDay)
        XCTAssertFalse(window.contains(now.startOfDay))

        let supportingDates = [
            makeTestDate(year: 2026, month: 1, day: 3),
            makeTestDate(year: 2026, month: 1, day: 12),
            makeTestDate(year: 2026, month: 1, day: 20),
            makeTestDate(year: 2026, month: 1, day: 29),
        ]
        let comparisonDates = [
            makeTestDate(year: 2026, month: 1, day: 4),
            makeTestDate(year: 2026, month: 1, day: 13),
            makeTestDate(year: 2026, month: 1, day: 21),
            makeTestDate(year: 2026, month: 1, day: 30),
        ]
        var entries = supportingDates.flatMap { aboveDay(on: $0) }
        entries += comparisonDates.flatMap { onTrackDay(on: $0) }
        entries += onTrackDay(on: now)
        let exactTargets = Dictionary(
            uniqueKeysWithValues: (supportingDates + comparisonDates + [now]).map { ($0, target) }
        )

        let pattern = try XCTUnwrap(discover(entries, exactTargets: exactTargets))
        XCTAssertEqual(pattern.eligibleDayCount, 8)
        XCTAssertFalse(pattern.supportingDays.contains { Calendar.current.isDate($0.date, inSameDayAs: now) })
    }

    func testUnloggedAndEstimatedTargetDaysAreExcluded() throws {
        let fridays = dates(2026, 1, [2, 9, 16, 23, 30])
        let comparison = dates(2026, 1, [3, 5, 6, 7, 8])
        let estimatedDate = makeTestDate(year: 2026, month: 1, day: 10)
        let unloggedSnapshotDate = makeTestDate(year: 2026, month: 1, day: 11)
        var entries = fridays.prefix(4).flatMap { weekdayAboveDay(on: $0) }
        entries += onTrackDay(on: fridays[4])
        entries += comparison.flatMap { onTrackDay(on: $0) }
        entries += weekdayAboveDay(on: estimatedDate)

        let exactDates = fridays + comparison + [unloggedSnapshotDate]
        let pattern = try XCTUnwrap(discover(
            entries,
            exactTargets: Dictionary(uniqueKeysWithValues: exactDates.map { ($0, target) }),
            policy: weekdayOnlyPolicy
        ))

        XCTAssertEqual(pattern.eligibleDayCount, 10)
        XCTAssertEqual(pattern.supportingDays.count, 4)
        XCTAssertFalse(pattern.supportingDays.contains {
            Calendar.current.isDate($0.date, inSameDayAs: estimatedDate)
        })
    }

    func testWeekdayCandidateSupportsAboveAndBelowOutcomes() throws {
        let fridays = dates(2026, 1, [2, 9, 16, 23, 30])
        let comparison = dates(2026, 1, [3, 5, 6, 7, 8, 10])

        let aboveEntries = fridays.prefix(4).flatMap { weekdayAboveDay(on: $0) }
            + onTrackDay(on: fridays[4])
            + comparison.flatMap { onTrackDay(on: $0) }
        let belowEntries = fridays.prefix(4).flatMap { weekdayBelowDay(on: $0) }
            + onTrackDay(on: fridays[4])
            + comparison.flatMap { onTrackDay(on: $0) }
        let exact = Dictionary(uniqueKeysWithValues: (fridays + comparison).map { ($0, target) })

        let above = try XCTUnwrap(discover(aboveEntries, exactTargets: exact, policy: weekdayOnlyPolicy))
        let below = try XCTUnwrap(discover(belowEntries, exactTargets: exact, policy: weekdayOnlyPolicy))

        XCTAssertEqual(above.outcome, .above)
        XCTAssertEqual(above.mealType, .dinner)
        XCTAssertEqual(below.outcome, .below)
        XCTAssertEqual(below.mealType, .dinner)
    }

    func testWeekdayThresholdQualifiesAtFourOfFiveAndRejectsBelowBoundary() {
        let fridays = dates(2026, 1, [2, 9, 16, 23, 30])
        let comparison = dates(2026, 1, [3, 5, 6, 7, 8, 10])
        let exact = Dictionary(uniqueKeysWithValues: (fridays + comparison).map { ($0, target) })
        let comparisonEntries = comparison.flatMap { onTrackDay(on: $0) }

        let boundary = fridays.prefix(4).flatMap { weekdayAboveDay(on: $0) }
            + onTrackDay(on: fridays[4])
            + comparisonEntries
        let belowBoundary = fridays.prefix(3).flatMap { weekdayAboveDay(on: $0) }
            + fridays.suffix(2).flatMap { onTrackDay(on: $0) }
            + comparisonEntries

        XCTAssertNotNil(discover(boundary, exactTargets: exact, policy: weekdayOnlyPolicy))
        XCTAssertNil(discover(belowBoundary, exactTargets: exact, policy: weekdayOnlyPolicy))
    }

    func testWeekdayOutcomeRateSeparationUsesNonWeekdayEligibleDays() {
        let fridays = dates(2026, 1, [2, 9, 16, 23, 30])
        let otherDates = dates(2026, 1, [3, 4, 5, 6, 7, 8, 10, 11, 12, 13])
        let exact = Dictionary(uniqueKeysWithValues: (fridays + otherDates).map { ($0, target) })
        let fridayEntries = fridays.prefix(4).flatMap { weekdayAboveDay(on: $0) }
            + onTrackDay(on: fridays[4])

        let exactBoundary = fridayEntries
            + otherDates.prefix(4).flatMap {
                day(on: $0, breakfast: 1_000, lunch: 700, dinner: 500, snack: 100)
            }
            + otherDates.suffix(6).flatMap { onTrackDay(on: $0) }
        let belowBoundary = fridayEntries
            + otherDates.prefix(5).flatMap {
                day(on: $0, breakfast: 1_000, lunch: 700, dinner: 500, snack: 100)
            }
            + otherDates.suffix(5).flatMap { onTrackDay(on: $0) }

        XCTAssertNotNil(discover(exactBoundary, exactTargets: exact, policy: weekdayOnlyPolicy))
        XCTAssertNil(discover(belowBoundary, exactTargets: exact, policy: weekdayOnlyPolicy))
    }

    func testMealOnlyRequiresFourDaysFourComparisonsAndThreeCalendarWeeks() {
        let support = dates(2026, 1, [3, 12, 20, 29])
        let comparison = dates(2026, 1, [4, 13, 21, 30])
        let exact = Dictionary(uniqueKeysWithValues: (support + comparison).map { ($0, target) })
        let qualifying = support.flatMap { mealOnlyAboveDay(on: $0) }
            + comparison.flatMap { onTrackDay(on: $0) }

        XCTAssertNotNil(discover(qualifying, exactTargets: exact))

        let threeSupport = Array(support.prefix(3))
        let threeSupportEntries = threeSupport.flatMap { mealOnlyAboveDay(on: $0) }
            + comparison.flatMap { onTrackDay(on: $0) }
        XCTAssertNil(discover(
            threeSupportEntries,
            exactTargets: Dictionary(uniqueKeysWithValues: (threeSupport + comparison).map { ($0, target) })
        ))

        let twoWeekSupport = dates(2026, 1, [5, 6, 12, 13])
        let twoWeekComparison = dates(2026, 1, [20, 21, 22, 23])
        let twoWeekEntries = twoWeekSupport.flatMap { mealOnlyAboveDay(on: $0) }
            + twoWeekComparison.flatMap { onTrackDay(on: $0) }
        XCTAssertNil(discover(
            twoWeekEntries,
            exactTargets: Dictionary(
                uniqueKeysWithValues: (twoWeekSupport + twoWeekComparison).map { ($0, target) }
            )
        ))
    }

    func testLargestMealDifferenceMustPointInOutcomeDirection() {
        let support = dates(2026, 1, [3, 12, 20, 29])
        let comparison = dates(2026, 1, [4, 13, 21, 30])
        let exact = Dictionary(uniqueKeysWithValues: (support + comparison).map { ($0, target) })
        let entries = support.flatMap {
            day(on: $0, breakfast: 600, lunch: 850, dinner: 750)
        } + comparison.flatMap {
            day(on: $0, breakfast: 1_000, lunch: 500, dinner: 500)
        }

        XCTAssertNil(discover(entries, exactTargets: exact))
    }

    func testTargetRelativeMaterialityQualifiesAtTenPercentAndRejectsBelow() {
        let support = dates(2026, 1, [3, 12, 20, 29])
        let comparison = dates(2026, 1, [4, 13, 21, 30])
        let exact = Dictionary(uniqueKeysWithValues: (support + comparison).map { ($0, target) })
        let comparisonEntries = comparison.flatMap {
            day(on: $0, breakfast: 1_000, lunch: 500, dinner: 500)
        }
        let boundary = support.flatMap {
            day(on: $0, breakfast: 1_000, lunch: 500, dinner: 700)
        } + comparisonEntries
        let belowBoundary = support.flatMap {
            day(on: $0, breakfast: 1_000, lunch: 500, dinner: 699)
        } + comparisonEntries

        XCTAssertNotNil(discover(boundary, exactTargets: exact))
        XCTAssertNil(discover(belowBoundary, exactTargets: exact))
    }

    func testMealOnlyAttributionQualifiesAtHalfAndRejectsBelow() {
        let support = dates(2026, 1, [3, 12, 20, 29])
        let comparison = dates(2026, 1, [4, 13, 21, 30])
        let exact = Dictionary(uniqueKeysWithValues: (support + comparison).map { ($0, target) })
        let comparisonEntries = comparison.flatMap {
            day(on: $0, breakfast: 800, lunch: 700, dinner: 500)
        }
        let boundary = support.flatMap {
            day(on: $0, breakfast: 900, lunch: 800, dinner: 700)
        } + comparisonEntries
        let belowBoundary = support.flatMap {
            day(on: $0, breakfast: 901, lunch: 800, dinner: 700)
        } + comparisonEntries

        XCTAssertNotNil(discover(boundary, exactTargets: exact))
        XCTAssertNil(discover(belowBoundary, exactTargets: exact))
    }

    func testWeekdayMealComparisonIncludesSameWeekdayNonOutcomeDay() throws {
        let fridays = dates(2026, 1, [2, 9, 16, 23, 30])
        let comparison = dates(2026, 1, [3, 5, 6, 7, 8])
        let exact = Dictionary(uniqueKeysWithValues: (fridays + comparison).map { ($0, target) })
        let entries = fridays.prefix(4).flatMap {
            day(on: $0, breakfast: 700, lunch: 700, dinner: 900)
        } + day(on: fridays[4], breakfast: 350, lunch: 350, dinner: 1_300)
            + comparison.flatMap {
                day(on: $0, breakfast: 750, lunch: 750, dinner: 500)
            }

        let pattern = try XCTUnwrap(discover(entries, exactTargets: exact, policy: weekdayOnlyPolicy))

        XCTAssertEqual(pattern.mealComparisonDayCount, 6)
        XCTAssertEqual(pattern.mealDifferenceCalories, 900 - (1_300 + 5 * 500) / 6.0, accuracy: 0.001)
    }

    func testDeterministicRankingUsesStableIdentifierAsFinalTieBreaker() throws {
        let aboveDates = dates(2026, 1, [3, 12, 20, 29])
        let belowDates = dates(2026, 1, [4, 13, 21, 30])
        let exact = Dictionary(uniqueKeysWithValues: (aboveDates + belowDates).map { ($0, target) })
        let entries = aboveDates.flatMap {
            day(on: $0, breakfast: 1_000, lunch: 500, dinner: 800)
        } + belowDates.flatMap {
            day(on: $0, breakfast: 1_000, lunch: 500, dinner: 200)
        }

        let first = try XCTUnwrap(discover(entries, exactTargets: exact))
        let second = try XCTUnwrap(discover(entries.reversed(), exactTargets: exact))

        XCTAssertEqual(first.id, "mealOnly|above|dinner")
        XCTAssertEqual(second.id, first.id)
    }

    func testSparseWeakConflictingAndNoPatternInputsYieldNoInsight() {
        let sparseDates = dates(2026, 1, [3, 12, 20])
        let sparseExact = Dictionary(uniqueKeysWithValues: sparseDates.map { ($0, target) })
        XCTAssertNil(discover(
            sparseDates.flatMap { mealOnlyAboveDay(on: $0) },
            exactTargets: sparseExact
        ))

        let weakDates = dates(2026, 1, [3, 5, 7, 9, 11, 13, 15, 17])
        let weakEntries = weakDates.enumerated().flatMap { index, date in
            index.isMultiple(of: 2) ? onTrackDay(on: date) : weekdayAboveDay(on: date)
        }
        XCTAssertNil(discover(
            weakEntries,
            exactTargets: Dictionary(uniqueKeysWithValues: weakDates.map { ($0, target) })
        ))

        let conflictingSupport = dates(2026, 1, [3, 12, 20, 29])
        let conflictingComparison = dates(2026, 1, [4, 13, 21, 30])
        let conflictingEntries = conflictingSupport.flatMap {
            day(on: $0, breakfast: 500, lunch: 900, dinner: 900)
        } + conflictingComparison.flatMap {
            day(on: $0, breakfast: 900, lunch: 600, dinner: 500)
        }
        XCTAssertNil(discover(
            conflictingEntries,
            exactTargets: Dictionary(
                uniqueKeysWithValues: (conflictingSupport + conflictingComparison).map { ($0, target) }
            )
        ))
    }

    func testExactHistoricalTargetsAreNotReinterpretedWhenFallbackChangesAndBackfillsRecalculate() throws {
        let support = dates(2026, 1, [3, 12, 20, 29])
        let comparison = dates(2026, 1, [4, 13, 21, 30])
        let allDates = support + comparison
        let entries = support.flatMap { mealOnlyAboveDay(on: $0) }
            + comparison.flatMap { onTrackDay(on: $0) }
        let exact = Dictionary(uniqueKeysWithValues: allDates.map { ($0, target) })

        let lowFallbackPattern = try XCTUnwrap(discover(
            entries,
            exactTargets: exact,
            fallbackTarget: 1_200
        ))
        let highFallbackPattern = try XCTUnwrap(discover(
            entries,
            exactTargets: exact,
            fallbackTarget: 3_000
        ))

        XCTAssertEqual(lowFallbackPattern.id, highFallbackPattern.id)
        XCTAssertEqual(
            lowFallbackPattern.supportingDays.map(\.dailyCalorieTarget),
            Array(repeating: target, count: 4)
        )

        let missingSnapshot = support[0]
        let withoutBackfill = exact.filter {
            !Calendar.current.isDate($0.key, inSameDayAs: missingSnapshot)
        }
        XCTAssertNil(discover(entries, exactTargets: withoutBackfill))
        XCTAssertNotNil(discover(entries, exactTargets: exact))
    }

    func testBelowMealOnlyCandidateUsesMissingMealsAsZero() throws {
        let support = dates(2026, 1, [3, 12, 20, 29])
        let comparison = dates(2026, 1, [4, 13, 21, 30])
        let exact = Dictionary(uniqueKeysWithValues: (support + comparison).map { ($0, target) })
        let entries = support.flatMap {
            day(on: $0, breakfast: 800, lunch: 600, dinner: 0)
        } + comparison.flatMap {
            day(on: $0, breakfast: 800, lunch: 600, dinner: 600)
        }

        let pattern = try XCTUnwrap(discover(entries, exactTargets: exact))

        XCTAssertEqual(pattern.outcome, .below)
        XCTAssertEqual(pattern.mealType, .dinner)
        XCTAssertTrue(pattern.supportingDays.allSatisfy { $0.mealCalories == 0 })
        XCTAssertTrue(pattern.headline.contains("Dinners"))
    }

    func testMaterialityAveragesPerDayHistoricalTargetShares() throws {
        let support = dates(2026, 1, [3, 12, 20, 29])
        let comparison = dates(2026, 1, [4, 13, 21, 30])
        let targets = [1_000, 2_000, 3_000, 4_000]
        var exact: [Date: Int] = [:]
        var entries: [FoodLogEntry] = []

        for (index, date) in support.enumerated() {
            let dayTarget = Double(targets[index])
            exact[date] = targets[index]
            entries += day(
                on: date,
                breakfast: dayTarget * 0.40,
                lunch: dayTarget * 0.40,
                dinner: dayTarget * 0.35
            )
        }
        for (index, date) in comparison.enumerated() {
            let dayTarget = Double(targets[index])
            exact[date] = targets[index]
            entries += day(
                on: date,
                breakfast: dayTarget * 0.40,
                lunch: dayTarget * 0.35,
                dinner: dayTarget * 0.25
            )
        }

        let pattern = try XCTUnwrap(discover(entries, exactTargets: exact))

        XCTAssertEqual(pattern.mealType, .dinner)
        XCTAssertEqual(pattern.targetRelativeMealDifference, 0.10, accuracy: 0.000_001)
        XCTAssertEqual(pattern.supportingDays.map(\.dailyCalorieTarget), targets)
    }

    func testSnackSlotsAreCombinedIntoOneSnackCategory() throws {
        let support = dates(2026, 1, [3, 12, 20, 29])
        let comparison = dates(2026, 1, [4, 13, 21, 30])
        let exact = Dictionary(uniqueKeysWithValues: (support + comparison).map { ($0, target) })
        var entries = comparison.flatMap { onTrackDay(on: $0) }

        for date in support {
            entries += day(on: date, breakfast: 700, lunch: 700, dinner: 500)
            entries.append(
                makeTestEntry(
                    date: date,
                    mealType: .snack,
                    foodItem: makeTestFoodItem(name: "First snack", caloriesPer100g: 150),
                    portionGrams: 100,
                    snackIndex: 1
                )
            )
            entries.append(
                makeTestEntry(
                    date: date,
                    mealType: .snack,
                    foodItem: makeTestFoodItem(name: "Second snack", caloriesPer100g: 150),
                    portionGrams: 100,
                    snackIndex: 2
                )
            )
        }

        let pattern = try XCTUnwrap(discover(entries, exactTargets: exact))

        XCTAssertEqual(pattern.mealType, .snack)
        XCTAssertTrue(pattern.supportingDays.allSatisfy { $0.mealCalories == 300 })
        XCTAssertTrue(pattern.supportingDays.allSatisfy { $0.mealFoods.count == 2 })
    }

    private var weekdayOnlyPolicy: HistoryRecurringCaloriePatternPolicy {
        HistoryRecurringCaloriePatternPolicy(minimumMealOnlyGroupCount: 100)
    }

    private func discover(
        _ entries: [FoodLogEntry],
        exactTargets: [Date: Int],
        fallbackTarget: Int = 2_000,
        policy: HistoryRecurringCaloriePatternPolicy? = nil
    ) -> HistoryRecurringCaloriePattern? {
        let valuesByDayKey = Dictionary(uniqueKeysWithValues: exactTargets.map { date, target in
            (
                DailyGoalSnapshot.dayKey(for: date),
                DailyGoalSnapshotValues(
                    baseCalorieTarget: target,
                    healthAdjustment: 0,
                    effectiveCalorieTarget: target,
                    calculationMode: .lifestyleEstimate,
                    isManualTarget: false
                )
            )
        })
        return HistoryRecurringCaloriePatternEngine(policy: policy ?? .standard).discover(
            entries: entries,
            targetResolver: HistoryDayTargetResolver(
                fallbackTarget: fallbackTarget,
                valuesByDayKey: valuesByDayKey
            ),
            now: now
        )
    }

    private func dates(_ year: Int, _ month: Int, _ days: [Int]) -> [Date] {
        days.map { makeTestDate(year: year, month: month, day: $0) }
    }

    private func onTrackDay(on date: Date) -> [FoodLogEntry] {
        day(on: date, breakfast: 700, lunch: 700, dinner: 500, snack: 100)
    }

    private func aboveDay(on date: Date) -> [FoodLogEntry] {
        day(on: date, breakfast: 700, lunch: 700, dinner: 800, snack: 100)
    }

    private func mealOnlyAboveDay(on date: Date) -> [FoodLogEntry] {
        day(on: date, breakfast: 700, lunch: 700, dinner: 800, snack: 100)
    }

    private func weekdayAboveDay(on date: Date) -> [FoodLogEntry] {
        day(on: date, breakfast: 950, lunch: 950, dinner: 800, snack: 100)
    }

    private func weekdayBelowDay(on date: Date) -> [FoodLogEntry] {
        day(on: date, breakfast: 450, lunch: 450, dinner: 200, snack: 100)
    }

    private func day(
        on date: Date,
        breakfast: Double,
        lunch: Double,
        dinner: Double,
        snack: Double = 0
    ) -> [FoodLogEntry] {
        [
            (MealType.breakfast, breakfast),
            (.lunch, lunch),
            (.dinner, dinner),
            (.snack, snack),
        ].compactMap { meal, calories in
            guard calories > 0 else { return nil }
            return makeTestEntry(
                date: date,
                mealType: meal,
                foodItem: makeTestFoodItem(
                    name: "\(meal.displayName) evidence",
                    caloriesPer100g: calories
                ),
                portionGrams: 100
            )
        }
    }
}
