import XCTest
@testable import Caloryn

@MainActor
final class CalorieOverflowSafetyTests: XCTestCase {
    func testCalorieBudgetRendersAConsumedTotalPastTheNegativeIntegerRange() {
        let budget = CalorieBudget(consumed: -1e30, target: 2_000)

        XCTAssertEqual(budget.roundedConsumed, -CalorieDomain.maximum)
        XCTAssertEqual(budget.remaining, 2_000 + CalorieDomain.maximum)
        XCTAssertEqual(budget.overAmount, 0)
        XCTAssertFalse(budget.isOver)
    }

    func testCalorieBudgetRendersAConsumedTotalPastThePositiveIntegerRange() {
        let budget = CalorieBudget(consumed: 1e30, target: 2_000)

        XCTAssertEqual(budget.roundedConsumed, CalorieDomain.maximum)
        XCTAssertEqual(budget.remaining, 0)
        XCTAssertEqual(budget.overAmount, CalorieDomain.maximum - 2_000)
        XCTAssertTrue(budget.isOver)
    }

    func testCalorieBudgetRendersAStaticTargetPastTheCalorieDomain() {
        let budget = CalorieBudget(consumed: 1_800, target: .max)

        XCTAssertEqual(budget.target, CalorieDomain.maximum)
        XCTAssertEqual(budget.remaining, CalorieDomain.maximum - 1_800)
        XCTAssertEqual(budget.overAmount, 0)
    }

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
    }

    func testHistoryTrendSurvivesACalorieTotalPastTheNegativeIntegerRange() {
        let date = makeTestDate(year: 2026, month: 1, day: 30)
        let analytics = HistoryAnalytics(
            entries: [makeEntry(date: date, calories: -1e30)],
            profile: makeProfile(),
            range: .week,
            endDate: date
        )
        let trend = HistoryPatternDiscovery(analytics: analytics, today: date).calorieTrend

        XCTAssertTrue(
            trend.cardSummary.chartAccessibilityLabel.contains("Average \((-CalorieDomain.maximum).formatted()) calories")
        )
    }

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
        let trend = HistoryPatternDiscovery(analytics: analytics, today: date).calorieTrend

        XCTAssertTrue(trend.cardSummary.chartAccessibilityLabel.contains("Average \(2_000.formatted()) calories"))
        XCTAssertTrue(trend.yAxisUpperBound.isFinite)
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
        let trend = HistoryPatternDiscovery(analytics: analytics, today: date).calorieTrend

        XCTAssertFalse(trend.points.isEmpty)
        XCTAssertTrue(trend.points.filter(\.isLogged).allSatisfy { $0.status == .under })
        XCTAssertTrue(trend.yAxisUpperBound.isFinite)
    }

    func testReminderRemainingSurvivesAConsumedTotalPastTheNegativeIntegerRange() {
        XCTAssertEqual(
            DailyReminderPlanner.remainingToday(target: 2_000, consumed: -1e30),
            2_000 + CalorieDomain.maximum
        )
        XCTAssertEqual(DailyReminderPlanner.remainingToday(target: 2_000, consumed: 1e30), 0)
        XCTAssertEqual(DailyReminderPlanner.remainingToday(target: .max, consumed: .nan), CalorieDomain.maximum)
        XCTAssertEqual(DailyReminderPlanner.remainingToday(target: 2_000, consumed: 1_500), 500)
    }

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
