import CoreData
import Foundation
import Observation

@MainActor
@Observable
final class CloudSyncActivity {
    let syncsWithCloud: Bool
    private(set) var initialImportSettled = false
    private(set) var waitExpired = false

    @ObservationIgnored private var observer: (any NSObjectProtocol)?
    @ObservationIgnored private let defaults: UserDefaults?

    static let waitSpentKey = "firstLaunchCloudWaitSpent"

    static var disabled: CloudSyncActivity {
        CloudSyncActivity(syncsWithCloud: false)
    }

    convenience init(
        syncsWithCloud: Bool,
        waitCeiling: Duration = FirstLaunchSyncGate.waitCeiling,
        defaults: UserDefaults = .standard
    ) {
        self.init(syncsWithCloud: syncsWithCloud, ceiling: waitCeiling, defaults: defaults)
    }

    #if DEBUG
    static func heldOpenForUITests() -> CloudSyncActivity {
        CloudSyncActivity(syncsWithCloud: true, ceiling: nil, defaults: nil)
    }
    #endif

    private init(syncsWithCloud: Bool, ceiling: Duration?, defaults: UserDefaults?) {
        self.syncsWithCloud = syncsWithCloud
        self.defaults = defaults
        guard syncsWithCloud else { return }
        if defaults?.bool(forKey: Self.waitSpentKey) == true {
            waitExpired = true
            return
        }
        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let event = Self.cloudEvent(from: notification) else { return }
            Task { @MainActor in
                self?.record(event)
            }
        }
        guard let ceiling else { return }
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: ceiling)
            self?.expireWait()
        }
    }

    func record(_ event: FirstLaunchSyncGate.CloudEvent) {
        guard FirstLaunchSyncGate.settlesInitialImport(event) else { return }
        initialImportSettled = true
        spendWait()
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        observer = nil
    }

    private func expireWait() {
        waitExpired = true
        spendWait()
    }

    private func spendWait() {
        defaults?.set(true, forKey: Self.waitSpentKey)
    }

    nonisolated static func cloudEvent(from notification: Notification) -> FirstLaunchSyncGate.CloudEvent? {
        guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event else {
            return nil
        }
        return cloudEvent(type: event.type, endDate: event.endDate, succeeded: event.succeeded)
    }

    nonisolated static func cloudEvent(
        type: NSPersistentCloudKitContainer.EventType,
        endDate: Date?,
        succeeded: Bool
    ) -> FirstLaunchSyncGate.CloudEvent? {
        guard endDate != nil else { return nil }
        switch type {
        case .setup:
            return .setupFinished(succeeded: succeeded)
        case .import:
            return .importFinished(succeeded: succeeded)
        case .export:
            return .exportFinished
        @unknown default:
            return nil
        }
    }
}
