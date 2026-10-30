import XCTest
@testable import Caloryn

@MainActor
final class WidgetSnapshotStoreTests: XCTestCase {
    private var directoryURL: URL!

    override func setUp() async throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    override func tearDown() async throws {
        if let directoryURL {
            try? FileManager.default.removeItem(at: directoryURL)
        }
        directoryURL = nil
    }

    func testSnapshotRoundTripsThroughTheSharedStore() throws {
        let store = WidgetSnapshotStore(directoryURL: directoryURL)
        let snapshot = DailyWidgetSnapshot.placeholder(at: Date(timeIntervalSince1970: 1_700_000_000))

        try store.save(snapshot)

        XCTAssertEqual(try store.load(), snapshot)
    }

    func testSnapshotRoundTripsItsMeals() throws {
        let store = WidgetSnapshotStore(directoryURL: directoryURL)
        let snapshot = DailyWidgetSnapshot(
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            dayStart: Date(timeIntervalSince1970: 1_700_000_000).startOfDay,
            state: .ready,
            calories: WidgetCalorieSummary(
                consumed: 963,
                target: 2_000,
                mealCalories: [.snack: 118, .breakfast: 382, .lunch: 463]
            )
        )

        try store.save(snapshot)
        let loaded = try XCTUnwrap(try store.load())

        XCTAssertEqual(loaded, snapshot)
        XCTAssertEqual(
            loaded.calories.meals,
            [
                WidgetMealCalories(meal: .breakfast, kcal: 382),
                WidgetMealCalories(meal: .lunch, kcal: 463),
                WidgetMealCalories(meal: .snack, kcal: 118),
            ]
        )
        XCTAssertNil(loaded.calories.kcal(for: .dinner))
    }

    func testASnapshotSavedBeforeMealsWereRecordedStillLoads() throws {
        let json = """
        {"activityRefreshedAt":null,"calories":{"baseTarget":2000,"consumed":800,"dynamicAdjustment":0,"target":2000},\
        "dayStart":"2023-11-14T00:00:00Z","generatedAt":"2023-11-14T22:13:20Z","schemaVersion":1,"state":"ready",\
        "usesDynamicTarget":false}
        """
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try Data(json.utf8).write(to: directoryURL.appendingPathComponent(WidgetConstants.snapshotFileName))
        let store = WidgetSnapshotStore(directoryURL: directoryURL)

        let loaded = try XCTUnwrap(try store.load())

        XCTAssertEqual(loaded.calories.consumed, 800)
        XCTAssertEqual(loaded.calories.meals, [])
        XCTAssertEqual(loaded.state, .ready)
    }

    func testASnapshotSavedWithAnAutoAdjustedTargetLoadsAsUnavailable() throws {
        let json = """
        {"activityRefreshedAt":null,"calories":{"baseTarget":2000,"consumed":800,"dynamicAdjustment":200,"target":2200},\
        "dayStart":"2023-11-14T00:00:00Z","generatedAt":"2023-11-14T22:13:20Z","schemaVersion":1,"state":"ready",\
        "usesDynamicTarget":true}
        """
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try Data(json.utf8).write(to: directoryURL.appendingPathComponent(WidgetConstants.snapshotFileName))
        let store = WidgetSnapshotStore(directoryURL: directoryURL)

        let loaded = try XCTUnwrap(try store.load())
        let nextDay = try XCTUnwrap(ISO8601DateFormatter().date(from: "2023-11-15T12:00:00Z"))

        XCTAssertEqual(loaded.state, .unavailable)
        XCTAssertEqual(loaded.displaySnapshot(at: nextDay).snapshot.state, .unavailable)
    }

    func testMissingSnapshotReturnsNil() throws {
        let store = WidgetSnapshotStore(directoryURL: directoryURL)

        XCTAssertNil(try store.load())
    }

    func testUnsupportedSnapshotIsRejectedBeforeWriting() {
        let store = WidgetSnapshotStore(directoryURL: directoryURL)
        let snapshot = DailyWidgetSnapshot(
            generatedAt: .now,
            dayStart: .now.startOfDay,
            state: .ready,
            calories: WidgetCalorieSummary(consumed: 800, target: 2_000),
            schemaVersion: WidgetConstants.currentSchemaVersion + 1
        )

        XCTAssertThrowsError(try store.save(snapshot)) { error in
            XCTAssertEqual(
                error as? WidgetSnapshotStoreError,
                .unsupportedSchemaVersion(WidgetConstants.currentSchemaVersion + 1)
            )
        }
    }

    func testNewDayResetsConsumedCaloriesAndMarksTheSnapshotStale() throws {
        let calendar = Calendar(identifier: .gregorian)
        let day = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 12)))
        let nextDay = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: day))
        let snapshot = DailyWidgetSnapshot(
            generatedAt: day,
            dayStart: calendar.startOfDay(for: day),
            state: .ready,
            calories: WidgetCalorieSummary(
                consumed: 1_200,
                target: 2_100,
                mealCalories: [.breakfast: 1_200]
            )
        )

        let result = snapshot.displaySnapshot(at: nextDay, calendar: calendar)

        XCTAssertTrue(result.isStale)
        XCTAssertEqual(result.snapshot.calories.consumed, 0)
        XCTAssertEqual(result.snapshot.calories.meals, [])
        XCTAssertEqual(result.snapshot.calories.target, 2_100)
    }

    func testRenderIdentityIgnoresGeneratedAtButTracksCalorieChanges() {
        let dayStart = Date(timeIntervalSince1970: 1_700_000_000).startOfDay
        let calories = WidgetCalorieSummary(consumed: 800, target: 2_000)
        let snapshot = DailyWidgetSnapshot(
            generatedAt: dayStart,
            dayStart: dayStart,
            state: .ready,
            calories: calories
        )
        let regenerated = DailyWidgetSnapshot(
            generatedAt: dayStart.addingTimeInterval(3_600),
            dayStart: dayStart,
            state: .ready,
            calories: calories
        )
        let changed = DailyWidgetSnapshot(
            generatedAt: dayStart,
            dayStart: dayStart,
            state: .ready,
            calories: WidgetCalorieSummary(consumed: 900, target: 2_000)
        )

        XCTAssertEqual(snapshot.renderIdentity, regenerated.renderIdentity)
        XCTAssertTrue(snapshot.hasSameRenderableContent(as: regenerated))
        XCTAssertNotEqual(snapshot.renderIdentity, changed.renderIdentity)
        XCTAssertFalse(snapshot.hasSameRenderableContent(as: changed))
    }

    func testRenderIdentityTracksCaloriesMovingBetweenMeals() {
        let dayStart = Date(timeIntervalSince1970: 1_700_000_000).startOfDay
        let breakfast = DailyWidgetSnapshot(
            generatedAt: dayStart,
            dayStart: dayStart,
            state: .ready,
            calories: WidgetCalorieSummary(consumed: 800, target: 2_000, mealCalories: [.breakfast: 800])
        )
        let lunch = DailyWidgetSnapshot(
            generatedAt: dayStart,
            dayStart: dayStart,
            state: .ready,
            calories: WidgetCalorieSummary(consumed: 800, target: 2_000, mealCalories: [.lunch: 800])
        )

        XCTAssertFalse(breakfast.hasSameRenderableContent(as: lunch))
    }
}
