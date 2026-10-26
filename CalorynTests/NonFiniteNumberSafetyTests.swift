import XCTest
@testable import Caloryn

@MainActor
final class NonFiniteNumberSafetyTests: XCTestCase {
    func testCalorieBudgetTreatsANonFiniteConsumedTotalAsNothingLogged() {
        for consumed in [Double.nan, .infinity, -.infinity] {
            let budget = CalorieBudget(consumed: consumed, target: 2_000)

            XCTAssertEqual(budget.roundedConsumed, 0)
            XCTAssertEqual(budget.remaining, 2_000)
            XCTAssertEqual(budget.overAmount, 0)
            XCTAssertFalse(budget.isOver)
        }
    }

    func testCalorieBudgetClampsAConsumedTotalPastTheIntegerRange() {
        let budget = CalorieBudget(consumed: 1e30, target: 2_000)

        XCTAssertEqual(budget.roundedConsumed, CalorieDomain.maximum)
        XCTAssertEqual(budget.remaining, 0)
        XCTAssertTrue(budget.isOver)
        XCTAssertGreaterThan(budget.overAmount, 0)
    }

    func testWidgetCalorieSummaryFloorsANonFiniteConsumedTotal() {
        for consumed in [Double.nan, .infinity, -.infinity, -5] {
            let summary = WidgetCalorieSummary(consumed: consumed, target: 2_000)

            XCTAssertEqual(summary.consumed, 0)
            XCTAssertEqual(summary.remaining, 2_000)
            XCTAssertEqual(summary.overAmount, 0)
        }
    }

    func testWidgetCalorieSummaryFloorsANonFiniteMealTotal() {
        let summary = WidgetCalorieSummary(
            consumed: 500,
            target: 2_000,
            mealCalories: [.breakfast: .nan, .lunch: -.infinity, .dinner: 500, .snack: 1e30]
        )

        XCTAssertEqual(summary.kcal(for: .breakfast), 0)
        XCTAssertEqual(summary.kcal(for: .lunch), 0)
        XCTAssertEqual(summary.kcal(for: .dinner), 500)
        XCTAssertEqual(summary.kcal(for: .snack), .max)
    }

    func testWidgetCalorieSummaryClampsAConsumedTotalPastTheIntegerRange() {
        let summary = WidgetCalorieSummary(consumed: 1e30, target: 2_000)

        XCTAssertEqual(summary.consumed, .max)
        XCTAssertEqual(summary.remaining, 0)
        XCTAssertEqual(summary.progress, 1, accuracy: 0.001)
    }

    func testHistoryAnalyticsRendersADayWhoseCaloriesAreNotFinite() {
        let date = makeTestDate(year: 2026, month: 1, day: 30)
        let analytics = HistoryAnalytics(
            entries: [makeEntry(date: date, calories: .infinity)],
            profile: makeProfile(),
            range: .week,
            endDate: date
        )

        let day = analytics.current.days.first(where: \.isLogged)
        XCTAssertNotNil(day)
        XCTAssertEqual(day?.calorieDifference, -2_000)
        let projection = HistoryPatternDiscovery(analytics: analytics).calorieTrend
        XCTAssertFalse(projection.totalDifferenceText.isEmpty)
        XCTAssertFalse(projection.averageDifferenceText.isEmpty)
    }

    func testHistoryAnalyticsRendersADayWhoseCaloriesExceedTheIntegerRange() {
        let date = makeTestDate(year: 2026, month: 1, day: 30)
        let analytics = HistoryAnalytics(
            entries: [makeEntry(date: date, calories: 1e30)],
            profile: makeProfile(),
            range: .week,
            endDate: date
        )

        let projection = HistoryPatternDiscovery(analytics: analytics).calorieTrend
        XCTAssertEqual(projection.totalTargetDelta, CalorieDomain.maximum - 2_000)
        XCTAssertFalse(projection.totalDifferenceText.isEmpty)
    }

    func testCalorieTrendLookupIgnoresANonFiniteChartIndex() {
        let date = makeTestDate(year: 2026, month: 1, day: 30)
        let analytics = HistoryAnalytics(
            entries: [makeEntry(date: date, calories: 2_000)],
            profile: makeProfile(),
            range: .week,
            endDate: date
        )
        let trend = HistoryPatternDiscovery(analytics: analytics).calorieTrend

        XCTAssertNotNil(trend.point(for: 0))
        XCTAssertNil(trend.point(for: .nan))
        XCTAssertNil(trend.point(for: .infinity))
        XCTAssertNil(trend.point(for: -.infinity))
    }

    func testPortionSelectionSurvivesAServingSizeOfZeroGrams() {
        var selection = PortionSelection(
            shape: PortionSelection.Shape(servingGramsPerUnit: 0),
            initialGrams: 100,
            preservesExactGrams: false
        )
        selection.mode = .serving
        selection.modeChanged()

        XCTAssertGreaterThanOrEqual(selection.servingCount, 1)
        XCTAssertTrue(selection.portionGrams.isFinite)
    }

    func testPortionSelectionSurvivesANonFiniteRecipeSize() {
        let shape = PortionSelection.Shape(isRecipe: true, defaultServingGrams: .infinity)
        let selection = PortionSelection(shape: shape, initialGrams: 100, preservesExactGrams: false)

        XCTAssertEqual(
            PortionSelection.quickGramOptions(for: shape),
            PortionSelection.fallbackQuickGramOptions
        )
        XCTAssertEqual(selection.gramsInput, "100")
    }

    func testPortionSelectionSurvivesANonFinitePortion() {
        let shape = PortionSelection.Shape(servingGramsPerUnit: 30)

        XCTAssertEqual(
            PortionSelection.formattedGrams(.nan),
            "\(PortionSelection.minimumGrams)"
        )
        XCTAssertEqual(
            PortionSelection.formattedGrams(.infinity),
            "\(PortionSelection.minimumGrams)"
        )
        XCTAssertGreaterThanOrEqual(
            PortionSelection.normalizedServingCount(for: .infinity, shape: shape),
            1
        )
    }

    func testDeficitLabelsSurviveANonFiniteDeficit() {
        for deficit in [Double.infinity, -.infinity, 1e30] {
            var draft = GoalEditDraft(profile: makeProfile())
            draft.calorieDeficit = deficit

            XCTAssertFalse(draft.deficitLabel.isEmpty)
            XCTAssertFalse(
                SettingsGoalSummary.goalSubtitle(calorieDeficit: deficit, isManualOverride: false).isEmpty
            )
        }
    }

    func testHeightReadoutsSurviveANonFiniteHeight() {
        XCTAssertEqual(OnboardingPersonalInfo.heightLabel(.nan), "0 cm")
        XCTAssertEqual(OnboardingPersonalInfo.heightLabel(.infinity), "0 cm")

        let summary = SettingsProfileSummary(
            age: 30,
            sex: .male,
            heightCm: .infinity,
            weightKg: 80,
            activityLevel: .moderatelyActive
        )
        XCTAssertEqual(summary.heightText, "0 cm")
    }

    func testTodayCaloriesIntentRejectsASnapshotWhenTheLiveTotalIsNotFinite() {
        let response = TodayCaloriesIntentResponse.make(
            snapshot: nil,
            currentConsumed: .nan,
            expectedTarget: 2_000
        )

        XCTAssertEqual(response, .unavailable("Open Caloryn to refresh today’s calorie snapshot."))
    }

    func testIntentCalorieFormattingSurvivesANonFiniteValue() {
        XCTAssertFalse(IntentNumberFormatting.calories(.nan).isEmpty)
        XCTAssertFalse(IntentNumberFormatting.calories(.infinity).isEmpty)
        XCTAssertFalse(IntentNumberFormatting.calories(1e30).isEmpty)
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

    private func makeEntry(date: Date, calories: Double) -> FoodLogEntry {
        makeTestEntry(
            date: date,
            mealType: .breakfast,
            foodItem: makeTestFoodItem(name: "Test Food", caloriesPer100g: calories),
            portionGrams: 100
        )
    }
}
