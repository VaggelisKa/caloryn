import XCTest
@testable import Caloryn

/// `Double.truncatedSafely` stops `Int(_:)` trapping, but it clamps to
/// `Int.min` / `Int.max` — and the *next* integer operation on such a value
/// traps in turn. `target - Int.min` overflows, `abs(Int.min)` overflows, and
/// a month of `Int.max` targets summed overflows. Every test below drives an
/// extreme number through a public entry point and asserts the figure that
/// comes out; a crash here is the trap-moved-downstream defect being pinned.
@MainActor
final class CalorieOverflowSafetyTests: XCTestCase {
    // MARK: - Today's calorie card

    func testCalorieBudgetRendersAConsumedTotalPastTheNegativeIntegerRange() {
        let budget = makeBudget(consumed: -1e30, staticTarget: 2_000)

        XCTAssertEqual(budget.roundedConsumed, -CalorieDomain.maximum)
        XCTAssertEqual(budget.remaining, 2_000 + CalorieDomain.maximum)
        XCTAssertEqual(budget.overAmount, 0)
        XCTAssertFalse(budget.isOver)
    }

    func testCalorieBudgetRendersAConsumedTotalPastThePositiveIntegerRange() {
        let budget = makeBudget(consumed: 1e30, staticTarget: 2_000)

        XCTAssertEqual(budget.roundedConsumed, CalorieDomain.maximum)
        XCTAssertEqual(budget.remaining, 0)
        XCTAssertEqual(budget.overAmount, CalorieDomain.maximum - 2_000)
        XCTAssertTrue(budget.isOver)
    }

    func testCalorieBudgetRendersAStaticTargetPastTheCalorieDomain() {
        let budget = makeBudget(consumed: 1_800, staticTarget: .max)

        XCTAssertEqual(budget.adjustedTarget, CalorieDomain.maximum)
        XCTAssertEqual(budget.remaining, CalorieDomain.maximum - 1_800)
        XCTAssertEqual(budget.overAmount, 0)
    }

    func testCalorieBudgetRendersAnExtremeTargetWhileActivityIsAdjustingIt() {
        let budget = makeBudget(
            consumed: 1_800,
            staticTarget: .max,
            activeEnergyKcal: 900,
            samples: baselineSamples(kcal: 300),
            mode: .dynamicHealth
        )

        XCTAssertLessThanOrEqual(budget.adjustedTarget, CalorieDomain.maximum)
        XCTAssertGreaterThan(budget.remaining, 0)
    }

    // MARK: - History

    func testHistoryDayDifferenceSurvivesACalorieTotalPastTheNegativeIntegerRange() {
        let date = makeTestDate(year: 2026, month: 1, day: 30)
        let analytics = HistoryAnalytics(
            entries: [makeEntry(date: date, calories: -1e30)],
            profile: makeProfile(),
            range: .week,
            endDate: date
        )

        let day = analytics.current.days.first(where: \.isLogged)
        XCTAssertEqual(day?.calorieDifference, -CalorieDomain.maximum - 2_000)
        XCTAssertEqual(day?.makeDetail().calorieDifference, -CalorieDomain.maximum - 2_000)
    }

    func testHistoryTrendSurvivesACalorieTotalPastTheNegativeIntegerRange() {
        let date = makeTestDate(year: 2026, month: 1, day: 30)
        let analytics = HistoryAnalytics(
            entries: [makeEntry(date: date, calories: -1e30)],
            profile: makeProfile(),
            range: .week,
            endDate: date
        )
        let trend = HistoryPatternDiscovery(analytics: analytics).calorieTrend

        XCTAssertEqual(trend.totalTargetDelta, -CalorieDomain.maximum - 2_000)
        XCTAssertFalse(trend.totalDifferenceText.isEmpty)
        XCTAssertFalse(trend.averageDifferenceText.isEmpty)
    }

    /// `abs(Int.min)` traps, and the biggest-swing headline sorts logged days
    /// by the absolute difference.
    func testHistoryHeadlineSurvivesADayWhoseDifferenceIsTheMostNegativePossible() {
        let date = makeTestDate(year: 2026, month: 1, day: 30)
        guard let earlier = Calendar.current.date(byAdding: .day, value: -1, to: date) else {
            return XCTFail("Could not build the earlier test date")
        }
        let analytics = HistoryAnalytics(
            entries: [
                makeEntry(date: date, calories: -1e30),
                makeEntry(date: earlier, calories: 2_000)
            ],
            profile: makeProfile(),
            range: .week,
            endDate: date
        )
        let trend = HistoryPatternDiscovery(analytics: analytics).calorieTrend

        XCTAssertNotNil(trend.biggestInconsistencyText)
    }

    /// A calorie target saved past the domain used to make the per-period
    /// target *sum* overflow once enough days were logged.
    func testHistoryPeriodTotalsSurviveATargetPastTheCalorieDomain() {
        let date = makeTestDate(year: 2026, month: 1, day: 30)
        let entries = (0 ..< 20).compactMap { offset in
            Calendar.current.date(byAdding: .day, value: -offset, to: date)
                .map { makeEntry(date: $0, calories: 2_000) }
        }
        let analytics = HistoryAnalytics(
            entries: entries,
            profile: makeProfile(dailyCalorieTarget: .max),
            range: .month,
            endDate: date
        )

        XCTAssertEqual(analytics.current.loggedDayTargetTotal, 20 * CalorieDomain.maximum)
        XCTAssertEqual(analytics.current.averageTargetPerLoggedDay, CalorieDomain.maximum)
        XCTAssertFalse(HistoryPatternDiscovery(analytics: analytics).calorieTrend.totalDifferenceText.isEmpty)
    }

    func testHistoryWeeklyRollupsSurviveATargetPastTheCalorieDomain() {
        let date = makeTestDate(year: 2026, month: 1, day: 30)
        let entries = (0 ..< 60).compactMap { offset in
            Calendar.current.date(byAdding: .day, value: -offset, to: date)
                .map { makeEntry(date: $0, calories: 2_000) }
        }
        let analytics = HistoryAnalytics(
            entries: entries,
            profile: makeProfile(dailyCalorieTarget: .max),
            range: .quarter,
            endDate: date
        )
        let trend = HistoryPatternDiscovery(analytics: analytics).calorieTrend

        XCTAssertFalse(trend.points.isEmpty)
        for point in trend.points {
            XCTAssertGreaterThanOrEqual(point.targetDelta, -2 * CalorieDomain.maximum)
        }
    }

    // MARK: - Daily reminder

    func testReminderRemainingSurvivesAConsumedTotalPastTheNegativeIntegerRange() {
        XCTAssertEqual(
            DailyReminderPlanner.remainingToday(target: 2_000, consumed: -1e30),
            2_000 + CalorieDomain.maximum
        )
        XCTAssertEqual(DailyReminderPlanner.remainingToday(target: 2_000, consumed: 1e30), 0)
        XCTAssertEqual(DailyReminderPlanner.remainingToday(target: .max, consumed: .nan), CalorieDomain.maximum)
        XCTAssertEqual(DailyReminderPlanner.remainingToday(target: 2_000, consumed: 1_500), 500)
    }

    // MARK: - Saved targets

    func testAManualCalorieTargetIsClampedIntoTheCalorieDomain() {
        var draft = GoalEditDraft(profile: makeProfile())
        draft.manualOverride = true
        draft.targetText = "\(Int.max)"

        XCTAssertEqual(draft.manualTarget, CalorieDomain.maximum)
        XCTAssertEqual(draft.effectiveCalorieTarget(tdee: 2_500), CalorieDomain.maximum)
    }

    func testACalculatedTargetIsClampedIntoTheCalorieDomain() {
        XCTAssertEqual(
            NutritionCalculator.defaultTarget(energyExpenditure: .infinity, deficit: 0),
            CalorieDomain.maximum
        )
        XCTAssertEqual(NutritionCalculator.defaultTarget(energyExpenditure: 1e30, deficit: 0), CalorieDomain.maximum)
        XCTAssertEqual(NutritionCalculator.defaultTarget(energyExpenditure: 2_500, deficit: 500), 2_000)
    }

    // MARK: - Factories

    private func makeBudget(
        consumed: Double = 1_800,
        staticTarget: Int = 2_000,
        activeEnergyKcal: Double = 0,
        samples: [DailyActiveEnergySample] = [],
        mode: EnergyCalculationMode = .lifestyleEstimate
    ) -> ActivityCalorieBudget {
        ActivityCalorieBudget(
            consumed: consumed,
            staticTarget: staticTarget,
            bmr: 1_600,
            calorieDeficit: 300,
            activeEnergyKcal: activeEnergyKcal,
            recentActiveEnergySamples: samples,
            calculationMode: mode,
            isManualOverride: false,
            isActivityLoading: false,
            activityMessage: nil,
            date: .now
        )
    }

    private func baselineSamples(kcal: Double, count: Int = 10) -> [DailyActiveEnergySample] {
        (0 ..< count).compactMap { index in
            guard let date = Calendar.current.date(
                byAdding: .day,
                value: -(index + 1),
                to: Date.now.startOfDay
            ) else {
                return nil
            }
            return DailyActiveEnergySample(date: date, activeEnergyKcal: kcal)
        }
    }

    private func makeProfile(dailyCalorieTarget: Int = 2_000) -> UserProfile {
        UserProfile(
            age: 30,
            sex: .male,
            heightCm: 180,
            weightKg: 80,
            activityLevel: .moderatelyActive,
            dailyCalorieTarget: dailyCalorieTarget
        )
    }

    private func makeEntry(date: Date, calories: Double) -> FoodLogEntry {
        makeTestEntry(
            date: date,
            mealType: .breakfast,
            foodItem: makeTestFoodItem(name: "Test Food", caloriesPer100g: calories),
            portionGrams: 100
        )
    }
}
