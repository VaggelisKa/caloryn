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
    private var pendingApply: Task<Void, Never>?
    private let logger = Logger(
        subsystem: "www.caloryn",
        category: "DailyReminder"
    )

    init(center: any ReminderNotificationCenter = UNUserNotificationCenter.current()) {
        self.center = center
    }

    /// Reconciliation suspends at several awaits, so overlapping calls could
    /// otherwise interleave and let an older plan finish last. Chaining each
    /// call on the previous one keeps applies strictly ordered.
    ///
    /// `force` skips the dedupe guard so callers can re-check authorization
    /// even when the plan itself hasn't changed (e.g. on app foreground,
    /// after permission was revoked in iOS Settings).
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

        var scheduledEveryReminder = true

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
                scheduledEveryReminder = false
                logger.error("Unable to schedule daily reminder: \(error.localizedDescription, privacy: .public)")
            }
        }

        // A partial apply must not be cached as applied, or the dedupe guard
        // would keep skipping the failed days until the plan next changes.
        lastAppliedPlan = scheduledEveryReminder ? plan : nil
    }

    private func removeAllPendingReminders() async {
        let stale = await center.pendingReminderIdentifiers()
        guard !stale.isEmpty else { return }
        center.removePendingRequests(withIdentifiers: stale)
    }
}
