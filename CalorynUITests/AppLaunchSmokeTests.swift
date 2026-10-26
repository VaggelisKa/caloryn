import XCTest

final class AppLaunchSmokeTests: UITestCase {
    func testGivenNoProfileWhenAppLaunchesThenOnboardingIsShown() {
        given("a store with no profile") {
            launch(fixture: .empty)
        }

        then("the app presents onboarding rather than the main tabs") {
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
