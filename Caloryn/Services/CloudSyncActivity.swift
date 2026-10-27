import CoreData
import Foundation
import Observation

@MainActor
@Observable
final class CloudSyncActivity {
    let syncsWithCloud: Bool
    let waitCeiling: Duration?
    private(set) var initialImportSettled = false

    @ObservationIgnored private var observer: (any NSObjectProtocol)?

    static let disabled = CloudSyncActivity(syncsWithCloud: false)

    init(syncsWithCloud: Bool, waitCeiling: Duration? = FirstLaunchSyncGate.waitCeiling) {
        self.syncsWithCloud = syncsWithCloud
        self.waitCeiling = waitCeiling
        guard syncsWithCloud else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let event = FirstLaunchSyncGate.CloudEvent(notification) else { return }
            Task { @MainActor in
                self?.record(event)
            }
        }
    }

    func record(_ event: FirstLaunchSyncGate.CloudEvent) {
        guard FirstLaunchSyncGate.settlesInitialImport(event) else { return }
        initialImportSettled = true
    }
}

private extension FirstLaunchSyncGate.CloudEvent {
    nonisolated init?(_ notification: Notification) {
        guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event,
              event.endDate != nil else {
            return nil
        }
        switch event.type {
        case .setup:
            self = .setupFinished(succeeded: event.succeeded)
        case .import:
            self = .importFinished(succeeded: event.succeeded)
        case .export:
            self = .exportFinished
        @unknown default:
            return nil
        }
    }
}
