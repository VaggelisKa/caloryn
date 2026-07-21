import UserNotifications
import XCTest
@testable import Caloryn

final class FakeReminderCenter: ReminderNotificationCenter, @unchecked Sendable {
    var status: UNAuthorizationStatus = .authorized
    var pending: [String] = []
    var removedIdentifierBatches: [[String]] = []
    var addedRequests: [UNNotificationRequest] = []

    func authorizationStatus() async -> UNAuthorizationStatus {
        status
    }

    func pendingReminderIdentifiers() async -> [String] {
        pending
    }

    func removePendingRequests(withIdentifiers identifiers: [String]) {
        removedIdentifierBatches.append(identifiers)
        pending.removeAll { identifiers.contains($0) }
    }

    func add(_ request: UNNotificationRequest) async throws {
        addedRequests.append(request)
        pending.append(request.identifier)
    }
}

@MainActor
final class DailyReminderSchedulerTests: XCTestCase {
    private func makePlan(remaining: Int = 450) -> [PlannedReminder] {
        DailyReminderPlanner.makePlan(
            isEnabled: true,
            remainingToday: remaining,
            fullDayTarget: 2_000,
            now: makeTestDate(year: 2026, month: 7, day: 15)
        )
    }

    func testApplyReplacesStaleRequestsAndSchedulesPlan() async {
        let center = FakeReminderCenter()
        center.pending = ["daily-reminder-2026-07-14"]
        let scheduler = DailyReminderScheduler(center: center)

        await scheduler.apply(makePlan())

        XCTAssertEqual(center.removedIdentifierBatches.first, ["daily-reminder-2026-07-14"])
        XCTAssertEqual(center.addedRequests.count, 7)
        XCTAssertEqual(center.addedRequests.first?.identifier, "daily-reminder-2026-07-15")
        XCTAssertEqual(center.addedRequests.first?.content.title, "Daily goal check-in")
        XCTAssertEqual(
            center.addedRequests.first?.content.body,
            "You have 450 calories left to reach today's goal."
        )

        let trigger = center.addedRequests.first?.trigger as? UNCalendarNotificationTrigger
        XCTAssertEqual(trigger?.dateComponents.hour, 21)
        XCTAssertEqual(trigger?.dateComponents.minute, 0)
        XCTAssertEqual(trigger?.repeats, false)
    }

    func testIdenticalPlanIsOnlyAppliedOnce() async {
        let center = FakeReminderCenter()
        let scheduler = DailyReminderScheduler(center: center)

        await scheduler.apply(makePlan())
        await scheduler.apply(makePlan())

        XCTAssertEqual(center.addedRequests.count, 7)
    }

    func testChangedPlanIsReapplied() async {
        let center = FakeReminderCenter()
        let scheduler = DailyReminderScheduler(center: center)

        await scheduler.apply(makePlan(remaining: 450))
        await scheduler.apply(makePlan(remaining: 300))

        XCTAssertEqual(center.addedRequests.count, 14)
        XCTAssertEqual(
            center.addedRequests[7].content.body,
            "You have 300 calories left to reach today's goal."
        )
        XCTAssertEqual(center.pending.count, 7)
    }

    func testDeniedAuthorizationClearsPendingAndAddsNothing() async {
        let center = FakeReminderCenter()
        center.status = .denied
        center.pending = ["daily-reminder-2026-07-15", "daily-reminder-2026-07-16"]
        let scheduler = DailyReminderScheduler(center: center)

        await scheduler.apply(makePlan())

        XCTAssertTrue(center.addedRequests.isEmpty)
        XCTAssertTrue(center.pending.isEmpty)
    }

    func testEmptyPlanClearsPendingWithoutAuthorizationCheck() async {
        let center = FakeReminderCenter()
        center.status = .denied
        center.pending = ["daily-reminder-2026-07-15"]
        let scheduler = DailyReminderScheduler(center: center)

        await scheduler.apply([])

        XCTAssertTrue(center.pending.isEmpty)
        XCTAssertTrue(center.addedRequests.isEmpty)
    }
}
