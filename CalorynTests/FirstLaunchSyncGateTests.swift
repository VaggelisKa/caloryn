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

    @MainActor
    func testCloudSyncActivitySettlesOnceAndStaysSettled() {
        let activity = CloudSyncActivity(syncsWithCloud: true)
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
    func testADisabledActivityNeverSyncs() {
        XCTAssertFalse(CloudSyncActivity.disabled.syncsWithCloud)
        XCTAssertFalse(CloudSyncActivity.disabled.initialImportSettled)
    }
}
