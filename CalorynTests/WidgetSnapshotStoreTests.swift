import XCTest
@testable import Caloryn

final class WidgetSnapshotStoreTests: XCTestCase {
    private var directoryURL: URL!

    override func setUpWithError() throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    override func tearDownWithError() throws {
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
            calories: WidgetCalorieSummary(consumed: 800, baseTarget: 2_000, target: 2_000),
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
                baseTarget: 1_900,
                target: 2_100,
                dynamicAdjustment: 200
            ),
            usesDynamicTarget: true
        )

        let result = snapshot.displaySnapshot(at: nextDay, calendar: calendar)

        XCTAssertTrue(result.isStale)
        XCTAssertEqual(result.snapshot.calories.consumed, 0)
        XCTAssertEqual(result.snapshot.calories.target, 1_900)
        XCTAssertEqual(result.snapshot.calories.dynamicAdjustment, 0)
    }

    func testRenderIdentityIgnoresGeneratedAtButTracksCalorieChanges() {
        let dayStart = Date(timeIntervalSince1970: 1_700_000_000).startOfDay
        let calories = WidgetCalorieSummary(consumed: 800, baseTarget: 2_000, target: 2_000)
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
            calories: WidgetCalorieSummary(consumed: 900, baseTarget: 2_000, target: 2_000)
        )

        XCTAssertEqual(snapshot.renderIdentity, regenerated.renderIdentity)
        XCTAssertTrue(snapshot.hasSameRenderableContent(as: regenerated))
        XCTAssertNotEqual(snapshot.renderIdentity, changed.renderIdentity)
        XCTAssertFalse(snapshot.hasSameRenderableContent(as: changed))
    }
}
