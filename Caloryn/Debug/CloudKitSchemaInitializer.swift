#if DEBUG
import CoreData
import OSLog
import SwiftData

enum CloudKitSchemaInitializer {
    static let flag = "-initialize-cloudkit-schema"

    private enum Failure: Error {
        case modelUnavailable
    }

    private static let logger = Logger(
        subsystem: "www.caloryn",
        category: "CloudKitSchema"
    )

    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains(flag)
    }

    static func run(
        models: [any PersistentModel.Type] = CalorynModelSchema.models,
        containerIdentifier: String = CalorynModelSchema.cloudKitContainerIdentifier
    ) {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "CloudKitSchemaInitializer", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        do {
            try? FileManager.default.removeItem(at: directory)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try autoreleasepool {
                try initializeSchema(
                    models: models,
                    containerIdentifier: containerIdentifier,
                    storeURL: directory.appending(path: "Schema.store")
                )
            }
            logger.notice("Initialized the CloudKit development schema for \(containerIdentifier, privacy: .public)")
        } catch {
            logger.error("Could not initialize the CloudKit schema: \(String(describing: error), privacy: .public)")
        }
    }

    private static func initializeSchema(
        models: [any PersistentModel.Type],
        containerIdentifier: String,
        storeURL: URL
    ) throws {
        guard let model = NSManagedObjectModel.makeManagedObjectModel(for: models) else {
            throw Failure.modelUnavailable
        }
        let description = NSPersistentStoreDescription(url: storeURL)
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: containerIdentifier
        )
        description.shouldAddStoreAsynchronously = false
        let container = NSPersistentCloudKitContainer(name: "CloudKitSchema", managedObjectModel: model)
        container.persistentStoreDescriptions = [description]
        var loadError: (any Error)?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let loadError {
            throw loadError
        }
        try container.initializeCloudKitSchema()
        for store in container.persistentStoreCoordinator.persistentStores {
            try container.persistentStoreCoordinator.remove(store)
        }
    }
}
#endif
