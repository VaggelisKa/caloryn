import Foundation
import Testing
@testable import Caloryn

@MainActor
struct WidgetSnapshotBridgeTests {
    private func makeTempDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private static let fixedDayStart = Date(timeIntervalSince1970: 1_700_000_000).startOfDay

    private func makeSnapshot(
        generatedAt: Date,
        consumed: Double = 500,
        target: Int = 2_000
    ) -> DailyWidgetSnapshot {
        DailyWidgetSnapshot(
            generatedAt: generatedAt,
            dayStart: Self.fixedDayStart,
            state: .ready,
            calories: WidgetCalorieSummary(consumed: consumed, target: target)
        )
    }

    @Test("Given no prior snapshot, when publishing, then the snapshot is written to the store")
    func firstPublishWritesToStore() throws {
        let directoryURL = makeTempDirectory()
        let store = WidgetSnapshotStore(directoryURL: directoryURL)
        let coordinator = WidgetSyncCoordinator(store: store)
        let snapshot = makeSnapshot(generatedAt: Date(timeIntervalSince1970: 1_700_000_000))

        coordinator.publish(snapshot)

        #expect(try store.load() == snapshot)
    }

    @Test("Given a snapshot already published in-memory, when publishing another with the same render identity, then the store is not rewritten")
    func republishingSameRenderIdentitySkipsTheWrite() throws {
        let directoryURL = makeTempDirectory()
        let store = WidgetSnapshotStore(directoryURL: directoryURL)
        let coordinator = WidgetSyncCoordinator(store: store)
        let first = makeSnapshot(generatedAt: Date(timeIntervalSince1970: 1_700_000_000))
        let regenerated = makeSnapshot(generatedAt: Date(timeIntervalSince1970: 1_700_003_600))

        coordinator.publish(first)
        coordinator.publish(regenerated)

        #expect(try store.load() == first)
    }

    @Test("Given a snapshot already published, when publishing one with different calories, then the store is overwritten")
    func republishingDifferentContentOverwritesTheStore() throws {
        let directoryURL = makeTempDirectory()
        let store = WidgetSnapshotStore(directoryURL: directoryURL)
        let coordinator = WidgetSyncCoordinator(store: store)
        let first = makeSnapshot(generatedAt: Date(timeIntervalSince1970: 1_700_000_000), consumed: 500)
        let changed = makeSnapshot(generatedAt: Date(timeIntervalSince1970: 1_700_003_600), consumed: 900)

        coordinator.publish(first)
        coordinator.publish(changed)

        #expect(try store.load() == changed)
    }

    @Test("Given a matching snapshot already on disk from a prior launch, when a fresh coordinator publishes an equivalent one, then the on-disk snapshot is left untouched")
    func freshCoordinatorDedupesAgainstDiskOnFirstPublish() throws {
        let directoryURL = makeTempDirectory()
        let store = WidgetSnapshotStore(directoryURL: directoryURL)
        let onDisk = makeSnapshot(generatedAt: Date(timeIntervalSince1970: 1_700_000_000))
        try store.save(onDisk)

        let coordinator = WidgetSyncCoordinator(store: store)
        let regenerated = makeSnapshot(generatedAt: Date(timeIntervalSince1970: 1_700_003_600))

        coordinator.publish(regenerated)

        #expect(try store.load() == onDisk)
    }

    @Test("Given an on-disk snapshot with an unsupported schema version, when publishing a valid snapshot, then the load failure does not block the write")
    func failedDiskLoadDoesNotBlockPublishing() throws {
        let directoryURL = makeTempDirectory()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let incompatible = makeSnapshot(generatedAt: Date(timeIntervalSince1970: 1_700_000_000))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var json = try #require(
            try JSONSerialization.jsonObject(with: encoder.encode(incompatible)) as? [String: Any]
        )
        json["schemaVersion"] = WidgetConstants.currentSchemaVersion + 1
        let data = try JSONSerialization.data(withJSONObject: json)
        try data.write(to: directoryURL.appendingPathComponent(WidgetConstants.snapshotFileName))

        let store = WidgetSnapshotStore(directoryURL: directoryURL)
        let coordinator = WidgetSyncCoordinator(store: store)
        let validSnapshot = makeSnapshot(generatedAt: Date(timeIntervalSince1970: 1_700_003_600), consumed: 700)

        coordinator.publish(validSnapshot)

        #expect(try store.load() == validSnapshot)
    }

    @Test("Given a snapshot with an unsupported schema version, when publishing, then nothing is written and no crash occurs")
    func publishingUnsupportedSchemaVersionWritesNothing() throws {
        let directoryURL = makeTempDirectory()
        let store = WidgetSnapshotStore(directoryURL: directoryURL)
        let coordinator = WidgetSyncCoordinator(store: store)
        let invalid = DailyWidgetSnapshot(
            generatedAt: .now,
            dayStart: .now.startOfDay,
            state: .ready,
            calories: WidgetCalorieSummary(consumed: 500, target: 2_000),
            schemaVersion: WidgetConstants.currentSchemaVersion + 1
        )

        coordinator.publish(invalid)

        #expect(try store.load() == nil)
    }

    @Test("Given a failed publish due to an unsupported schema version, when a subsequent valid snapshot is published, then it still writes successfully")
    func coordinatorRecoversAfterAFailedPublish() throws {
        let directoryURL = makeTempDirectory()
        let store = WidgetSnapshotStore(directoryURL: directoryURL)
        let coordinator = WidgetSyncCoordinator(store: store)
        let invalid = DailyWidgetSnapshot(
            generatedAt: .now,
            dayStart: .now.startOfDay,
            state: .ready,
            calories: WidgetCalorieSummary(consumed: 500, target: 2_000),
            schemaVersion: WidgetConstants.currentSchemaVersion + 1
        )
        coordinator.publish(invalid)

        let validSnapshot = makeSnapshot(generatedAt: Date(timeIntervalSince1970: 1_700_000_000))
        coordinator.publish(validSnapshot)

        #expect(try store.load() == validSnapshot)
    }
}
