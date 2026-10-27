import CoreData
import XCTest
@testable import Caloryn

final class FirstLaunchSyncGateTests: XCTestCase {
    func testALocalProfileOpensTheAppWhateverTheCloudIsDoing() {
        for syncs in [true, false] {
            XCTAssertEqual(
                FirstLaunchSyncGate.phase(
                    hasLocalProfile: true,
                    syncsWithCloud: syncs,
                    initialImportSettled: false,
                    waitExpired: false
                ),
                .main
            )
        }
    }

    func testAFreshStoreWaitsForTheInitialImportWhenSyncIsOn() {
        XCTAssertEqual(
            FirstLaunchSyncGate.phase(
                hasLocalProfile: false,
                syncsWithCloud: true,
                initialImportSettled: false,
                waitExpired: false
            ),
            .awaitingCloudImport
        )
    }

    func testAFreshStoreGoesStraightToOnboardingWhenSyncIsOff() {
        XCTAssertEqual(
            FirstLaunchSyncGate.phase(
                hasLocalProfile: false,
                syncsWithCloud: false,
                initialImportSettled: false,
                waitExpired: false
            ),
            .onboarding
        )
    }

    func testASettledImportWithNoProfileShowsOnboarding() {
        XCTAssertEqual(
            FirstLaunchSyncGate.phase(
                hasLocalProfile: false,
                syncsWithCloud: true,
                initialImportSettled: true,
                waitExpired: false
            ),
            .onboarding
        )
    }

    func testTheWaitCeilingFallsBackToOnboarding() {
        XCTAssertEqual(
            FirstLaunchSyncGate.phase(
                hasLocalProfile: false,
                syncsWithCloud: true,
                initialImportSettled: false,
                waitExpired: true
            ),
            .onboarding
        )
    }

    func testOnlyASuccessfulImportOrAFailedSetupSettlesTheGate() {
        XCTAssertTrue(FirstLaunchSyncGate.settlesInitialImport(.importFinished(succeeded: true)))
        XCTAssertTrue(FirstLaunchSyncGate.settlesInitialImport(.setupFinished(succeeded: false)))
        XCTAssertFalse(FirstLaunchSyncGate.settlesInitialImport(.importFinished(succeeded: false)))
        XCTAssertFalse(FirstLaunchSyncGate.settlesInitialImport(.setupFinished(succeeded: true)))
        XCTAssertFalse(FirstLaunchSyncGate.settlesInitialImport(.exportFinished))
    }

    private func isolatedDefaults(_ name: String = #function) -> UserDefaults {
        let suite = "FirstLaunchSyncGateTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @MainActor
    func testCloudSyncActivitySettlesOnceAndStaysSettled() {
        let activity = CloudSyncActivity(syncsWithCloud: true, defaults: isolatedDefaults())
        XCTAssertFalse(activity.initialImportSettled)

        activity.record(.setupFinished(succeeded: true))
        XCTAssertFalse(activity.initialImportSettled)

        activity.record(.importFinished(succeeded: false))
        XCTAssertFalse(activity.initialImportSettled)

        activity.record(.importFinished(succeeded: true))
        XCTAssertTrue(activity.initialImportSettled)

        activity.record(.exportFinished)
        XCTAssertTrue(activity.initialImportSettled)
    }

    @MainActor
    func testTheWaitExpiresAfterTheCeiling() async throws {
        let defaults = isolatedDefaults()
        let activity = CloudSyncActivity(syncsWithCloud: true, waitCeiling: .milliseconds(20), defaults: defaults)
        XCTAssertFalse(activity.waitExpired)

        try await Task.sleep(for: .milliseconds(200))
        XCTAssertTrue(activity.waitExpired)
        XCTAssertFalse(activity.initialImportSettled)
        XCTAssertTrue(defaults.bool(forKey: CloudSyncActivity.waitSpentKey))
    }

    @MainActor
    func testASettledImportSpendsTheWaitForLaterLaunches() {
        let defaults = isolatedDefaults()
        let activity = CloudSyncActivity(syncsWithCloud: true, defaults: defaults)
        activity.record(.importFinished(succeeded: true))
        XCTAssertTrue(defaults.bool(forKey: CloudSyncActivity.waitSpentKey))

        let relaunched = CloudSyncActivity(syncsWithCloud: true, defaults: defaults)
        XCTAssertTrue(relaunched.waitExpired)
        XCTAssertFalse(relaunched.initialImportSettled)
    }

    @MainActor
    func testASpentWaitStartsExpiredWithoutACountdown() async throws {
        let defaults = isolatedDefaults()
        defaults.set(true, forKey: CloudSyncActivity.waitSpentKey)
        let activity = CloudSyncActivity(syncsWithCloud: true, waitCeiling: .seconds(60), defaults: defaults)
        XCTAssertTrue(activity.waitExpired)
        XCTAssertEqual(
            FirstLaunchSyncGate.phase(
                hasLocalProfile: false,
                syncsWithCloud: activity.syncsWithCloud,
                initialImportSettled: activity.initialImportSettled,
                waitExpired: activity.waitExpired
            ),
            .onboarding
        )
    }

    @MainActor
    func testADisabledActivityStartsNoCountdown() async throws {
        let defaults = isolatedDefaults()
        let activity = CloudSyncActivity(syncsWithCloud: false, waitCeiling: .milliseconds(20), defaults: defaults)
        XCTAssertFalse(activity.syncsWithCloud)

        try await Task.sleep(for: .milliseconds(200))
        XCTAssertFalse(activity.waitExpired)
        XCTAssertFalse(activity.initialImportSettled)
        XCTAssertFalse(defaults.bool(forKey: CloudSyncActivity.waitSpentKey))
    }

    func testAnEventStillInProgressIsIgnored() {
        XCTAssertNil(CloudSyncActivity.cloudEvent(type: .import, endDate: nil, succeeded: false))
        XCTAssertNil(CloudSyncActivity.cloudEvent(type: .setup, endDate: nil, succeeded: false))
    }

    func testFinishedEventsMapToTheirOutcome() {
        let now = Date()
        XCTAssertEqual(
            CloudSyncActivity.cloudEvent(type: .setup, endDate: now, succeeded: false),
            .setupFinished(succeeded: false)
        )
        XCTAssertEqual(
            CloudSyncActivity.cloudEvent(type: .import, endDate: now, succeeded: true),
            .importFinished(succeeded: true)
        )
        XCTAssertEqual(
            CloudSyncActivity.cloudEvent(type: .import, endDate: now, succeeded: false),
            .importFinished(succeeded: false)
        )
        XCTAssertEqual(
            CloudSyncActivity.cloudEvent(type: .export, endDate: now, succeeded: true),
            .exportFinished
        )
    }

    func testANotificationWithoutAnEventIsIgnored() {
        let notification = Notification(name: NSPersistentCloudKitContainer.eventChangedNotification)
        XCTAssertNil(CloudSyncActivity.cloudEvent(from: notification))
    }
}
