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
        XCTAssertEqual(middleWeek.onTrackRatio, 2.0 / 3.0, accuracy: 0.001)
        XCTAssertEqual(middleWeek.coverageRatio, 3.0 / 7.0, accuracy: 0.001)
        XCTAssertEqual(middleWeek.averageCaloriesPerLoggedDay, 2_100, accuracy: 0.001)
        XCTAssertEqual(middleWeek.days.count, 7)
        XCTAssertEqual(middleWeek.days[0].detail.calories, 2_000, accuracy: 0.001)
    }

    func testDayDetailSummarizesMealsAndTopFoods() {
        let profile = makeProfile()
        let date = makeTestDate(year: 2026, month: 1, day: 30)
        let entries = [
            makeEntry(date: date, name: "Oats", mealType: .breakfast, calories: 300),
            makeEntry(date: date, name: "Pasta", mealType: .lunch, calories: 700),
            makeEntry(date: date, name: "Oats", mealType: .snack, calories: 150)
        ]

        let analytics = HistoryAnalytics(
            entries: entries,
            profile: profile,
            range: .week,
            endDate: date
        )

        let detail = analytics.current.days.last!.detail
        XCTAssertEqual(detail.entryCount, 3)
        XCTAssertEqual(detail.mealSummaries.map(\.mealType), [.breakfast, .lunch, .snack])
        XCTAssertEqual(detail.mealSummaries.first { $0.mealType == .lunch }?.calories ?? 0, 700, accuracy: 0.001)
        XCTAssertEqual(detail.topFoods.map(\.name), ["Pasta", "Oats"])
        XCTAssertEqual(detail.topFoods.first { $0.name == "Oats" }?.entryCount, 2)
        XCTAssertEqual(detail.topFoods.first { $0.name == "Oats" }?.calories ?? 0, 450, accuracy: 0.001)
    }

    func testDayDetailIncludesProduceAndNutriscoreSummariesWhenPresent() {
        let profile = makeProfile()
        let date = makeTestDate(year: 2026, month: 1, day: 30)
        let entries = [
            makeEntry(date: date, name: "Apple", calories: 80, nutriscoreGrade: "a", produceKind: .fruit),
            makeEntry(date: date, name: "Broccoli", calories: 60, nutriscoreGrade: "b", produceKind: .vegetable),
            makeEntry(date: date, name: "Cereal", calories: 220, nutriscoreGrade: "c")
        ]

        let analytics = HistoryAnalytics(
            entries: entries,
            profile: profile,
            range: .week,
            endDate: date
        )

        let detail = analytics.current.days.last!.detail
        XCTAssertEqual(detail.produceSummary.totalCount, 2)
        XCTAssertEqual(detail.produceSummary.fruitCount, 1)
        XCTAssertEqual(detail.produceSummary.vegetableCount, 1)
        XCTAssertEqual(detail.nutriscoreDistribution.map(\.grade), ["a", "b", "c"])
        XCTAssertEqual(detail.nutriscoreDistribution.map(\.count), [1, 1, 1])
    }

    func testUnloggedDayDetailPreservesTargetAndEmptyCollections() {
        let profile = makeProfile()
        let endDate = makeTestDate(year: 2026, month: 1, day: 30)

        let analytics = HistoryAnalytics(
            entries: [],
            profile: profile,
            range: .week,
            endDate: endDate
        )

        let detail = analytics.current.days.last!.detail
        XCTAssertFalse(detail.isLogged)
        XCTAssertEqual(detail.dailyCalorieTarget, 2_000)
        XCTAssertEqual(detail.status, .notLogged)
        XCTAssertTrue(detail.mealSummaries.isEmpty)
        XCTAssertTrue(detail.topFoods.isEmpty)
        XCTAssertEqual(detail.produceSummary.totalCount, 0)
        XCTAssertTrue(detail.nutriscoreDistribution.isEmpty)
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
