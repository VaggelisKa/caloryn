import Foundation

enum WidgetSnapshotStoreError: Error, Equatable {
    case appGroupUnavailable
    case unsupportedSchemaVersion(Int)
}

struct WidgetSnapshotStore: Sendable {
    private let directoryURL: URL?

    init(appGroupIdentifier: String = WidgetConstants.appGroupIdentifier) {
        self.directoryURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        )
    }

    init(directoryURL: URL) {
        self.directoryURL = directoryURL
    }

    func load() throws -> DailyWidgetSnapshot? {
        let fileURL = try snapshotFileURL()
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }

        let data = try Data(contentsOf: fileURL)
        let snapshot = try Self.decoder.decode(DailyWidgetSnapshot.self, from: data)
        guard snapshot.schemaVersion == WidgetConstants.currentSchemaVersion else {
            throw WidgetSnapshotStoreError.unsupportedSchemaVersion(snapshot.schemaVersion)
        }
        return snapshot
    }

    func save(_ snapshot: DailyWidgetSnapshot) throws {
        guard snapshot.schemaVersion == WidgetConstants.currentSchemaVersion else {
            throw WidgetSnapshotStoreError.unsupportedSchemaVersion(snapshot.schemaVersion)
        }

        guard let directoryURL else {
            throw WidgetSnapshotStoreError.appGroupUnavailable
        }

        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        let data = try Self.encoder.encode(snapshot)
        try data.write(
            to: directoryURL.appendingPathComponent(WidgetConstants.snapshotFileName),
            options: .atomic
        )
    }

    private func snapshotFileURL() throws -> URL {
        guard let directoryURL else {
            throw WidgetSnapshotStoreError.appGroupUnavailable
        }
        return directoryURL.appendingPathComponent(WidgetConstants.snapshotFileName)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
