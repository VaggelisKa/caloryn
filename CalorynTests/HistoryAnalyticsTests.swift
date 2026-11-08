import XCTest
@testable import Caloryn

@MainActor
final class HistoryAnalyticsTests: XCTestCase {
    func testGoalConsistencyCountsLoggedDaysAndCoverageSeparately() {
        let profile = makeProfile()
        let entries = [
            makeEntry(date: makeTestDate(year: 2026, month: 1, day: 30), calories: 2_000),
            makeEntry(date: makeTestDate(year: 2026, month: 1, day: 29), calories: 1_900),
            makeEntry(date: makeTestDate(year: 2026, month: 1, day: 28), calories: 2_100),
            makeEntry(date: makeTestDate(year: 2026, month: 1, day: 27), calories: 1_899),
            makeEntry(date: makeTestDate(year: 2026, month: 1, day: 26), calories: 2_101)
        ]

        let analytics = HistoryAnalytics(
            entries: entries,
            profile: profile,
            range: .week,
            endDate: makeTestDate(year: 2026, month: 1, day: 30)
        )

        XCTAssertEqual(analytics.current.totalDayCount, 7)
        XCTAssertEqual(analytics.current.loggedDayCount, 5)
        XCTAssertEqual(analytics.current.count(for: .onTrack), 3)
        XCTAssertEqual(analytics.current.count(for: .under), 1)
        XCTAssertEqual(analytics.current.count(for: .over), 1)
        XCTAssertEqual(analytics.current.count(for: .notLogged), 2)
        XCTAssertEqual(analytics.current.averageCaloriesPerLoggedDay, 2_000, accuracy: 0.001)
    }

    func testPreviousRangeComparisonUsesEquivalentPreviousPeriod() {
        let profile = makeProfile()
        let currentEntries = [
            makeEntry(date: makeTestDate(year: 2026, month: 1, day: 30), calories: 2_000),
            makeEntry(date: makeTestDate(year: 2026, month: 1, day: 29), calories: 2_000),
            makeEntry(date: makeTestDate(year: 2026, month: 1, day: 28), calories: 2_200)
        ]
        let previousEntries = [
            makeEntry(date: makeTestDate(year: 2026, month: 1, day: 23), calories: 2_000),
            makeEntry(date: makeTestDate(year: 2026, month: 1, day: 22), calories: 2_300)
        ]

        let analytics = HistoryAnalytics(
            entries: currentEntries + previousEntries,
            profile: profile,
            range: .week,
            endDate: makeTestDate(year: 2026, month: 1, day: 30)
        )

        XCTAssertEqual(analytics.current.count(for: .onTrack), 2)
        XCTAssertEqual(analytics.previous.count(for: .onTrack), 1)
        XCTAssertEqual(analytics.goalComparison.onTrackDayDelta, 1)
    }

    func testMacroPatternsUseStrictGoalKinds() {
        let profile = makeProfile()
        let entries = [
            makeEntry(
                date: makeTestDate(year: 2026, month: 1, day: 30),
                protein: 150,
                carbs: 200,
                fat: 66.7
            ),
            makeEntry(
                date: makeTestDate(year: 2026, month: 1, day: 29),
                protein: 149.9,
                carbs: 189.9,
                fat: 70
            ),
            makeEntry(
                date: makeTestDate(year: 2026, month: 1, day: 28),
                protein: 180,
                carbs: 210,
                fat: 60
            )
        ]

        let analytics = HistoryAnalytics(
            entries: entries,
            profile: profile,
            range: .week,
            endDate: makeTestDate(year: 2026, month: 1, day: 30)
        )

        XCTAssertEqual(analytics.macroPatterns.first { $0.nutrient == .protein }?.current.hitDays, 2)
        XCTAssertEqual(analytics.macroPatterns.first { $0.nutrient == .carbs }?.current.hitDays, 2)
        XCTAssertEqual(analytics.macroPatterns.first { $0.nutrient == .fat }?.current.hitDays, 2)
        XCTAssertEqual(analytics.macroPatterns.first { $0.nutrient == .protein }?.current.loggedDays, 3)
    }

    func testCalendarWeekRollupsUseLoggedDaysForOnTrackRatioAndAllDaysForCoverage() {
        let profile = makeProfile()
        let entries = [
            makeEntry(date: makeTestDate(year: 2026, month: 1, day: 5), calories: 2_000),
            makeEntry(date: makeTestDate(year: 2026, month: 1, day: 6), calories: 2_000),
            makeEntry(date: makeTestDate(year: 2026, month: 1, day: 7), calories: 2_300)
        ]

        let analytics = HistoryAnalytics(
            entries: entries,
            profile: profile,
            range: .twoWeeks,
            endDate: makeTestDate(year: 2026, month: 1, day: 14)
        )

        XCTAssertEqual(analytics.current.weeklyRollups.count, 3)

        let middleWeek = analytics.current.weeklyRollups[1]
        XCTAssertEqual(middleWeek.startDate, makeTestDate(year: 2026, month: 1, day: 5).startOfDay)
        XCTAssertEqual(middleWeek.totalDays, 7)
        XCTAssertEqual(middleWeek.loggedDays, 3)
        XCTAssertEqual(middleWeek.onTrackDays, 2)
        XCTAssertEqual(middleWeek.averageCaloriesPerLoggedDay, 2_100, accuracy: 0.001)
        XCTAssertEqual(middleWeek.days.count, 7)
        XCTAssertEqual(middleWeek.days[0].calories, 2_000, accuracy: 0.001)
    }

    func testUnloggedDayPreservesItsTarget() {
        let profile = makeProfile()
        let endDate = makeTestDate(year: 2026, month: 1, day: 30)

        let analytics = HistoryAnalytics(
            entries: [],
            profile: profile,
            range: .week,
            endDate: endDate
        )

        let day = analytics.current.days.last!
        XCTAssertFalse(day.isLogged)
        XCTAssertEqual(day.dailyCalorieTarget, 2_000)
        XCTAssertEqual(day.status, .notLogged)
        XCTAssertEqual(day.calorieDifference, -2_000)
    }

    func testPatternDiscoveryProjectsDailyCalorieTrendPoints() throws {
        let profile = makeProfile()
        let endDate = makeTestDate(year: 2026, month: 1, day: 30)
        let entries = [
            makeEntry(date: endDate.yesterday, calories: 2_000),
            makeEntry(date: endDate, calories: 2_200)
        ]

        let analytics = HistoryAnalytics(
            entries: entries,
            profile: profile,
            range: .week,
            endDate: endDate
        )

        let projection = HistoryPatternDiscovery(analytics: analytics, today: endDate).calorieTrend

        XCTAssertEqual(projection.points.count, 7)
        XCTAssertEqual(projection.points.filter(\.isLogged).count, 2)

        let firstPoint = try XCTUnwrap(projection.points.first)
        XCTAssertFalse(firstPoint.isLogged)
        XCTAssertEqual(firstPoint.value, 0, accuracy: 0.001)
        XCTAssertEqual(firstPoint.status, .notLogged)

        let lastPoint = try XCTUnwrap(projection.points.last)
        XCTAssertTrue(lastPoint.isLogged)
        XCTAssertEqual(lastPoint.value, 2_200, accuracy: 0.001)
        XCTAssertEqual(lastPoint.status, .over)
        XCTAssertEqual(lastPoint.xAxisLabel, "F")
        XCTAssertEqual(lastPoint.accessibilityValue, "2200 calories, Over")
    }

    func testPatternDiscoveryCountsEachMacrosMetDays() {
        let profile = makeProfile()
        let endDate = makeTestDate(year: 2026, month: 1, day: 30)
        let entries = [
            makeEntry(date: endDate.yesterday.yesterday, protein: 150, carbs: 200, fat: 66.7),
            makeEntry(date: endDate.yesterday, protein: 100, carbs: 200, fat: 66.7),
            makeEntry(date: endDate, protein: 100, carbs: 200, fat: 66.7)
        ]

        let analytics = HistoryAnalytics(
            entries: entries,
            profile: profile,
            range: .week,
            endDate: endDate
        )

        let protein = HistoryPatternDiscovery(analytics: analytics, today: endDate).macroPatterns.patterns.first { $0.nutrient == .protein }

        XCTAssertEqual(protein?.current.hitDays, 1)
        XCTAssertEqual(protein?.current.loggedDays, 3)
    }

    private func makeProfile() -> UserProfile {
        UserProfile(
            age: 30,
            sex: .male,
            heightCm: 180,
            weightKg: 80,
            activityLevel: .moderatelyActive,
            dailyCalorieTarget: 2_000
        )
    }

    private func makeEntry(
        date: Date,
        name: String = "Test Food",
        mealType: MealType = .breakfast,
        calories: Double = 2_000,
        protein: Double = 0,
        carbs: Double = 0,
        fat: Double = 0,
        nutriscoreGrade: String? = nil,
        produceKind: ProduceKind? = nil
    ) -> FoodLogEntry {
        makeTestEntry(
            date: date,
            mealType: mealType,
            foodItem: makeTestFoodItem(
                name: name,
                caloriesPer100g: calories,
                proteinPer100g: protein,
                carbsPer100g: carbs,
                fatPer100g: fat,
                nutriscoreGrade: nutriscoreGrade,
                produceKind: produceKind
            ),
            portionGrams: 100
        )
    }
}
