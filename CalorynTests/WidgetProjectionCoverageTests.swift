import Foundation
import Testing
@testable import Caloryn

nonisolated private let projectionCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone.current
    return calendar
}()

nonisolated private func localDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
    projectionCalendar.date(
        from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
    )!
}

@MainActor
struct WidgetProjectionCoverageTests {
    @Test("Each plate sector is identified by its kind, so the chart keys are unique")
    func sectorIdentityIsItsKind() {
        let summary = WidgetPlateSummary(calories: WidgetCalorieSummary(
            consumed: 900,
            target: 2_000,
            mealCalories: [.breakfast: 300, .lunch: 400]
        ))

        #expect(summary.sectors.map(\.id) == [.meal(.breakfast), .meal(.lunch), .eaten, .remaining])
        #expect(summary.sectors.map(\.kcal) == [300, 400, 200, 1_100])
        #expect(Set(summary.sectors.map(\.id)).count == summary.sectors.count)
    }

    @Test("Today's projection keeps entries from local midnight up to the next midnight")
    func projectionUsesInjectedCalendarDay() throws {
        let profile = UserProfile(
            age: 30,
            sex: .female,
            heightCm: 165,
            weightKg: 60,
            activityLevel: .lightlyActive,
            dailyCalorieTarget: 1_800,
            manualOverride: true,
            calorieDeficit: 0
        )
        let food = makeTestFoodItem(caloriesPer100g: 100)
        let now = localDate(2026, 7, 25, 9)
        // `makeTestEntry` normalises to the start of the day, so each entry's exact time is
        // set afterwards: these sit on, and one second either side of, both midnights.
        let todayStart = localDate(2026, 7, 25, 0)
        let tomorrowStart = localDate(2026, 7, 26, 0)
        func entry(at date: Date, _ meal: MealType, grams: Double) -> FoodLogEntry {
            let entry = makeTestEntry(mealType: meal, foodItem: food, portionGrams: grams)
            entry.date = date
            return entry
        }
        let entries = [
            entry(at: todayStart.addingTimeInterval(-1), .dinner, grams: 700),
            entry(at: todayStart, .breakfast, grams: 250),
            entry(at: todayStart.addingTimeInterval(1), .breakfast, grams: 10),
            entry(at: tomorrowStart.addingTimeInterval(-1), .snack, grams: 100),
            entry(at: tomorrowStart, .lunch, grams: 900),
            entry(at: tomorrowStart.addingTimeInterval(1), .lunch, grams: 400),
        ]

        let snapshot = DailyWidgetSnapshotProjector.makeSnapshot(
            profile: profile,
            entries: entries,
            now: now,
            calendar: projectionCalendar
        )

        #expect(snapshot.dayStart == localDate(2026, 7, 25, 0))
        #expect(snapshot.calories.consumed == 360)
        #expect(snapshot.calories.target == 1_800)
        #expect(snapshot.calories.remaining == 1_440)
        #expect(snapshot.calories.meals.map(\.meal) == [.breakfast, .snack])
        #expect(snapshot.calories.meals.map(\.kcal) == [260, 100])
    }

    @Test("A projected snapshot survives the app-group file unchanged")
    func projectedSnapshotRoundTripsThroughStore() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WidgetProjectionCoverage-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = WidgetSnapshotStore(directoryURL: directory)
        let food = makeTestFoodItem(caloriesPer100g: 123.4)
        let now = localDate(2026, 7, 25, 18, 30)
        let profile = UserProfile(
            age: 41,
            sex: .male,
            heightCm: 178,
            weightKg: 82,
            activityLevel: .moderatelyActive,
            dailyCalorieTarget: 2_200,
            manualOverride: true,
            calorieDeficit: 0
        )
        let snapshot = DailyWidgetSnapshotProjector.makeSnapshot(
            profile: profile,
            entries: [makeTestEntry(date: now, mealType: .dinner, foodItem: food, portionGrams: 333)],
            now: Date(timeIntervalSince1970: (now.timeIntervalSince1970).rounded()),
            calendar: projectionCalendar
        )

        try store.save(snapshot)

        let loaded = try #require(try store.load())
        #expect(loaded == snapshot)
        #expect(loaded.calories.consumed == 411)
        #expect(loaded.calories.meals.map(\.kcal) == [411])
    }

    @Test("Without a profile the projection asks for onboarding on the injected day")
    func missingProfileNeedsOnboarding() {
        let now = localDate(2026, 7, 25, 0, 30)

        let snapshot = DailyWidgetSnapshotProjector.makeSnapshot(
            profile: nil,
            entries: [makeTestEntry(date: now, foodItem: makeTestFoodItem(), portionGrams: 500)],
            now: now,
            calendar: projectionCalendar
        )

        #expect(snapshot.state == .needsOnboarding)
        #expect(snapshot.dayStart == localDate(2026, 7, 25, 0))
        #expect(snapshot.calories.consumed == 0)
    }
}
