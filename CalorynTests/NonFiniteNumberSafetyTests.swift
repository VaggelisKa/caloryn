import XCTest
@testable import Caloryn

/// `Int(someDouble)` is a trap, not a throwing conversion: NaN, an infinity or
/// anything past `Int64` terminates the process. Every value below reaches such
/// a conversion from user-entered, HealthKit or API data, so each test asserts
/// the number that comes out — a crash here is the failure being pinned.
@MainActor
final class NonFiniteNumberSafetyTests: XCTestCase {
    // MARK: - Today's calorie budget

    func testCalorieBudgetTreatsANonFiniteConsumedTotalAsNothingLogged() {
        for consumed in [Double.nan, .infinity, -.infinity] {
            let budget = makeBudget(consumed: consumed, staticTarget: 2_000)

            XCTAssertEqual(budget.roundedConsumed, 0)
            XCTAssertEqual(budget.remaining, 2_000)
            XCTAssertEqual(budget.overAmount, 0)
            XCTAssertFalse(budget.isOver)
        }
    }

    func testCalorieBudgetClampsAConsumedTotalPastTheIntegerRange() {
        let budget = makeBudget(consumed: 1e30, staticTarget: 2_000)

        // Clamped to the calorie domain, not to `Int.max`: `Int.max` would only
        // move the trap to the subtraction in `remaining`.
        XCTAssertEqual(budget.roundedConsumed, CalorieDomain.maximum)
        XCTAssertEqual(budget.remaining, 0)
        XCTAssertTrue(budget.isOver)
        XCTAssertGreaterThan(budget.overAmount, 0)
    }

    func testCalorieBudgetSurvivesANonFiniteActiveEnergyReading() {
        let budget = makeBudget(
            consumed: 1_800,
            staticTarget: 2_000,
            activeEnergyKcal: .infinity,
            samples: baselineSamples(kcal: 300),
            mode: .dynamicHealth
        )

        XCTAssertGreaterThan(budget.adjustedTarget, 0)
        XCTAssertEqual(budget.roundedConsumed, 1_800)
    }

    // MARK: - Widget snapshot

    func testWidgetCalorieSummaryFloorsANonFiniteConsumedTotal() {
        for consumed in [Double.nan, .infinity, -.infinity, -5] {
            let summary = WidgetCalorieSummary(consumed: consumed, baseTarget: 2_000, target: 2_000)

            XCTAssertEqual(summary.consumed, 0)
            XCTAssertEqual(summary.remaining, 2_000)
            XCTAssertEqual(summary.overAmount, 0)
        }
    }

    func testWidgetCalorieSummaryClampsAConsumedTotalPastTheIntegerRange() {
        let summary = WidgetCalorieSummary(consumed: 1e30, baseTarget: 2_000, target: 2_000)

        XCTAssertEqual(summary.consumed, .max)
        XCTAssertEqual(summary.remaining, 0)
        XCTAssertEqual(summary.progress, 1, accuracy: 0.001)
    }

    // MARK: - History

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

    // MARK: - Portion picker

    func testPortionSelectionSurvivesAServingSizeOfZeroGrams() {
        var selection = PortionSelection(
            shape: PortionSelection.Shape(servingGramsPerUnit: 0),
            initialGrams: 100,
            isExistingEntry: false
        )
        selection.mode = .serving
        selection.modeChanged()

        XCTAssertGreaterThanOrEqual(selection.servingCount, 1)
        XCTAssertTrue(selection.portionGrams.isFinite)
    }

    func testPortionSelectionSurvivesANonFiniteRecipeSize() {
        let shape = PortionSelection.Shape(isRecipe: true, defaultServingGrams: .infinity)
        let selection = PortionSelection(shape: shape, initialGrams: 100, isExistingEntry: false)

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

    // MARK: - Goal and profile readouts

    func testDeficitLabelsSurviveANonFiniteDeficit() {
        for deficit in [Double.infinity, -.infinity, 1e30] {
            var draft = GoalEditDraft(profile: makeProfile())
            draft.calorieDeficit = deficit

            XCTAssertFalse(draft.deficitLabel.isEmpty)
            XCTAssertFalse(SettingsGoalSummary.adjustmentLabel(calorieDeficit: deficit).isEmpty)
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

    // MARK: - App intent

    func testTodayCaloriesIntentRejectsASnapshotWhenTheLiveTotalIsNotFinite() {
        let response = TodayCaloriesIntentResponse.make(
            snapshot: nil,
            currentConsumed: .nan,
            expectedBaseTarget: 2_000,
            expectedTarget: 2_000,
            expectsDynamicTarget: false
        )

        XCTAssertEqual(response, .unavailable("Open Caloryn to refresh today’s calorie snapshot."))
    }

    func testIntentCalorieFormattingSurvivesANonFiniteValue() {
        XCTAssertFalse(IntentNumberFormatting.calories(.nan).isEmpty)
        XCTAssertFalse(IntentNumberFormatting.calories(.infinity).isEmpty)
        XCTAssertFalse(IntentNumberFormatting.calories(1e30).isEmpty)
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
