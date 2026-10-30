import XCTest
@testable import Caloryn

@MainActor
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

    func testProjectionLeavesTomorrowOutOfADayThatStartsLateForDaylightSaving() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Havana"))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 12)))
        let tomorrow = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: now))
        let food = makeTestFoodItem(caloriesPer100g: 100)
        let todayEntry = makeTestEntry(foodItem: food, portionGrams: 300)
        todayEntry.date = calendar.startOfDay(for: now)
        let tomorrowEntry = makeTestEntry(foodItem: food, portionGrams: 900)
        tomorrowEntry.date = calendar.startOfDay(for: tomorrow)

        let snapshot = DailyWidgetSnapshotProjector.makeSnapshot(
            profile: makeProfile(target: 2_000),
            entries: [todayEntry, tomorrowEntry],
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.calories.consumed, 300)
    }

    func testProjectionSplitsTodayByMealWithSnackSlotsSharingOneKey() {
        let now = makeTestDate(year: 2026, month: 7, day: 15)
        let profile = makeProfile(target: 2_000)
        let food = makeTestFoodItem(caloriesPer100g: 100)
        let entries = [
            makeTestEntry(date: now, mealType: .breakfast, foodItem: food, portionGrams: 300),
            makeTestEntry(date: now, mealType: .snack, foodItem: food, portionGrams: 50, snackIndex: 1),
            makeTestEntry(date: now, mealType: .snack, foodItem: food, portionGrams: 70, snackIndex: 2),
        ]

        let snapshot = DailyWidgetSnapshotProjector.makeSnapshot(
            profile: profile,
            entries: entries,
            now: now
        )

        XCTAssertEqual(snapshot.calories.consumed, 420)
        XCTAssertEqual(
            snapshot.calories.meals,
            [
                WidgetMealCalories(meal: .breakfast, kcal: 300),
                WidgetMealCalories(meal: .snack, kcal: 120),
            ]
        )
    }

    private func makeProfile(
        target: Int
    ) -> UserProfile {
        UserProfile(
            age: 30,
            sex: .male,
            heightCm: 180,
            weightKg: 75,
            activityLevel: .moderatelyActive,
            dailyCalorieTarget: target,
            manualOverride: false,
            calorieDeficit: 300
        )
    }
}
