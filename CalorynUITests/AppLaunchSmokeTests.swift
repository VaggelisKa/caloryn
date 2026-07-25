import XCTest

/// Proves the UI test target, the launch-argument seeding contract, and the
/// two entry states of the app all work. Journey tests build on these.
final class AppLaunchSmokeTests: UITestCase {
    func testGivenNoProfileWhenAppLaunchesThenOnboardingIsShown() {
        given("a store with no profile") {
            launch(fixture: .empty)
        }

        then("the app presents onboarding rather than the main tabs") {
            // Onboarding is shown whenever no UserProfile exists.
            XCTAssertTrue(
                app.wait(for: .runningForeground, timeout: UITestCase.defaultTimeout),
                "App did not reach the foreground"
            )
            XCTAssertFalse(app.tabBars.firstMatch.exists, "Main tab bar should not be shown before onboarding completes")
        }
    }

    func testGivenACompletedProfileWhenAppLaunchesThenMainTabsAreShown() {
        given("a store containing a completed profile") {
            launch(fixture: .profileOnly)
        }

        then("the app opens straight into the main tab flow") {
            XCTAssertTrue(
                app.wait(for: .runningForeground, timeout: UITestCase.defaultTimeout),
                "App did not reach the foreground"
            )
            XCTAssertTrue(
                app.tabBars.firstMatch.awaitExistence(),
                "Main tab bar should be shown once a profile exists"
            )
        }
    }
}
