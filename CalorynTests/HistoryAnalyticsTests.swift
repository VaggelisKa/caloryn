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
        XCTAssertEqual(analytics.goalComparison.loggedDayDelta, 1)
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
        XCTAssertEqual(middleWeek.onTrackRatio, 2.0 / 3.0, accuracy: 0.001)
        XCTAssertEqual(middleWeek.coverageRatio, 3.0 / 7.0, accuracy: 0.001)
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
        calories: Double = 2_000,
        protein: Double = 0,
        carbs: Double = 0,
        fat: Double = 0
    ) -> FoodLogEntry {
        makeTestEntry(
            date: date,
            foodItem: makeTestFoodItem(
                caloriesPer100g: calories,
                proteinPer100g: protein,
                carbsPer100g: carbs,
                fatPer100g: fat
            ),
            portionGrams: 100
        )
    }
}
