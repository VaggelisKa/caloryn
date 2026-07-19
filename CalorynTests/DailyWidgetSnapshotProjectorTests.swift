import XCTest
@testable import Caloryn

final class DailyWidgetSnapshotProjectorTests: XCTestCase {
    func testMissingProfileProducesOnboardingState() {
        let now = makeTestDate(year: 2026, month: 7, day: 15)

        let snapshot = DailyWidgetSnapshotProjector.makeSnapshot(
            profile: nil,
            entries: [],
            now: now
        )

        XCTAssertEqual(snapshot.state, .needsOnboarding)
    }

    func testProjectionOnlyIncludesEntriesFromToday() {
        let now = makeTestDate(year: 2026, month: 7, day: 15)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let profile = makeProfile(target: 2_000)
        let todayFood = makeTestFoodItem(caloriesPer100g: 500)
        let yesterdayFood = makeTestFoodItem(caloriesPer100g: 900)
        let entries = [
            makeTestEntry(date: now, foodItem: todayFood, portionGrams: 100),
            makeTestEntry(date: yesterday, foodItem: yesterdayFood, portionGrams: 100),
        ]

        let snapshot = DailyWidgetSnapshotProjector.makeSnapshot(
            profile: profile,
            entries: entries,
            now: now
        )

        XCTAssertEqual(snapshot.state, .ready)
        XCTAssertEqual(snapshot.calories.consumed, 500)
        XCTAssertEqual(snapshot.calories.target, 2_000)
        XCTAssertEqual(snapshot.calories.remaining, 1_500)
    }

    func testProjectionCarriesDynamicActivityAdjustment() {
        let now = Date.now
        let profile = makeProfile(target: 2_000, mode: .dynamicHealth)
        let samples = (1...7).compactMap { offset -> DailyActiveEnergySample? in
            guard let date = Calendar.current.date(byAdding: .day, value: -offset, to: now.startOfDay) else {
                return nil
            }
            return DailyActiveEnergySample(date: date, activeEnergyKcal: 300)
        }

        let snapshot = DailyWidgetSnapshotProjector.makeSnapshot(
            profile: profile,
            entries: [],
            activeEnergyKcal: 500,
            recentActiveEnergySamples: samples,
            now: now
        )

        XCTAssertTrue(snapshot.usesDynamicTarget)
        XCTAssertEqual(snapshot.calories.dynamicAdjustment, 200)
        XCTAssertEqual(
            snapshot.calories.target,
            snapshot.calories.baseTarget + 200
        )
    }

    private func makeProfile(
        target: Int,
        mode: EnergyCalculationMode = .lifestyleEstimate
    ) -> UserProfile {
        UserProfile(
            age: 30,
            sex: .male,
            heightCm: 180,
            weightKg: 75,
            activityLevel: .moderatelyActive,
            dailyCalorieTarget: target,
            manualOverride: false,
            calorieDeficit: 300,
            energyCalculationMode: mode
        )
    }
}
