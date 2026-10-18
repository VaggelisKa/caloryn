import Foundation
import OSLog
import UserNotifications

protocol ReminderNotificationCenter {
    func authorizationStatus() async -> UNAuthorizationStatus
    func pendingReminderIdentifiers() async -> [String]
    func removePendingRequests(withIdentifiers identifiers: [String])
    func add(_ request: UNNotificationRequest) async throws
}

extension UNUserNotificationCenter: ReminderNotificationCenter {
    func authorizationStatus() async -> UNAuthorizationStatus {
        await notificationSettings().authorizationStatus
    }

    func pendingReminderIdentifiers() async -> [String] {
        await pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(DailyReminderPlanner.identifierPrefix) }
    }

    func removePendingRequests(withIdentifiers identifiers: [String]) {
        removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}

@MainActor
final class DailyReminderScheduler {
    private let center: any ReminderNotificationCenter
    private var lastAppliedPlan: [PlannedReminder]?
    private var pendingApply: Task<Void, Never>?
    private let logger = Logger(
        subsystem: "www.caloryn",
        category: "DailyReminder"
    )

    init(center: any ReminderNotificationCenter = UNUserNotificationCenter.current()) {
        self.center = center
    }

    func apply(_ plan: [PlannedReminder], force: Bool = false) async {
        let previous = pendingApply
        let task = Task {
            await previous?.value
            await reconcile(plan, force: force)
        }
        pendingApply = task
        await task.value
    }

    private func reconcile(_ plan: [PlannedReminder], force: Bool) async {
        guard force || plan != lastAppliedPlan else { return }

        var isAuthorized = plan.isEmpty
        if !isAuthorized {
            isAuthorized = (await center.authorizationStatus()) == .authorized
        }
        guard isAuthorized else {
            await removeAllPendingReminders()
            lastAppliedPlan = []
            return
        }

        await removeAllPendingReminders()

        var scheduledEveryReminder = true

        for reminder in plan {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: reminder.fireDateComponents,
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: reminder.identifier,
                content: content,
                trigger: trigger
            )

            do {
                try await center.add(request)
            } catch {
                scheduledEveryReminder = false
                logger.error("Unable to schedule daily reminder: \(error.localizedDescription, privacy: .public)")
            }
        }

        lastAppliedPlan = scheduledEveryReminder ? plan : nil
    }

    private func removeAllPendingReminders() async {
        let stale = await center.pendingReminderIdentifiers()
        guard !stale.isEmpty else { return }
        center.removePendingRequests(withIdentifiers: stale)
    }
}
