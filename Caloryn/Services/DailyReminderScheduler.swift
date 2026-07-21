import Foundation
import OSLog
import UserNotifications

/// Thin seam over UNUserNotificationCenter so the sync logic is testable.
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

/// Mirrors the desired reminder plan into the notification center.
/// Deduplicates against the last applied plan so repeated SwiftData
/// invalidations don't spam the center (same idea as WidgetSyncCoordinator).
@MainActor
final class DailyReminderScheduler {
    private let center: any ReminderNotificationCenter
    private var lastAppliedPlan: [PlannedReminder]?
    private let logger = Logger(
        subsystem: "www.caloryn",
        category: "DailyReminder"
    )

    init(center: any ReminderNotificationCenter = UNUserNotificationCenter.current()) {
        self.center = center
    }

    func apply(_ plan: [PlannedReminder]) async {
        guard plan != lastAppliedPlan else { return }

        // `await` isn't allowed inside a `||` autoclosure, so evaluate the
        // authorization status up front only when there is a plan to schedule.
        var isAuthorized = plan.isEmpty
        if !isAuthorized {
            isAuthorized = (await center.authorizationStatus()) == .authorized
        }
        guard isAuthorized else {
            // iOS suppresses pending requests once permission is revoked, but
            // clearing keeps state honest if permission is granted again later.
            await removeAllPendingReminders()
            lastAppliedPlan = []
            return
        }

        await removeAllPendingReminders()

        for reminder in plan {
            let content = UNMutableNotificationContent()
            content.title = "Daily goal check-in"
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
                logger.error("Unable to schedule daily reminder: \(error.localizedDescription, privacy: .public)")
            }
        }

        lastAppliedPlan = plan
    }

    private func removeAllPendingReminders() async {
        let stale = await center.pendingReminderIdentifiers()
        guard !stale.isEmpty else { return }
        center.removePendingRequests(withIdentifiers: stale)
    }
}
