import XCTest

/// Photographs the surfaces whose chrome iPhone Duo rearranges — the vertical bar on the
/// outer display, sheets, pushed details with a custom back button, the regular-width
/// pages of the inner display — in whatever pose the simulator is currently in, so one run
/// per pose builds a contact sheet.
///
/// The pose is not set here: `devicectl device orientation set` rotates the device, a
/// `devicectl device appResize` session hosts the app at any size, and the fold is a Device
/// Hub control. Name the run with `CALORYN_POSE` (for example `inner-portrait`) so
/// attachments from different poses do not collide. Every capture launches the app afresh,
/// so a screen that cannot be reached costs that capture and nothing else. See
/// `docs/design/iphone-duo.md` for the recipe.
final class PoseScreenshotTests: UITestCase {
    private var pose: String {
        ProcessInfo.processInfo.environment["CALORYN_POSE"] ?? "pose"
    }

    override func setUp() {
        super.setUp()
        continueAfterFailure = true
    }

    func testCaptureDuoSurfaces() {
        captureToday()
        captureNutritionDetails()
        captureSettings()
        captureGoalEdit()
        captureProfileEdit()
        captureHistory()
        captureHistoryDrillDown()
        captureMyFoods()
        captureCreationSheet()
        captureOnboarding()
    }

    private func captureToday() {
        let app = launch(fixture: .overBudgetDay)
        guard TodayScreen(app: app).calorieRing.awaitExistence() else { return }
        settle()
        attach(app, "01-today")
    }

    private func captureNutritionDetails() {
        let app = launch(fixture: .overBudgetDay)
        let today = TodayScreen(app: app)
        guard today.calorieRing.awaitExistence() else { return }
        today.calorieRing.tap()
        guard NutritionDetailsScreen(app: app).consumedCalories.awaitExistence() else { return }
        settle()
        attach(app, "02-nutrition-details")
    }

    private func captureSettings() {
        let app = launch(fixture: .loggedDay)
        guard openTab(.settings, in: app) else { return }
        guard SettingsScreen(app: app).editGoal.awaitExistence() else { return }
        settle()
        attach(app, "03-settings")
    }

    private func captureGoalEdit() {
        let app = launch(fixture: .loggedDay)
        guard openTab(.settings, in: app) else { return }
        let settings = SettingsScreen(app: app)
        guard settings.editGoal.awaitExistence() else { return }
        settings.editGoal.tap()
        guard settings.saveGoal.awaitExistence() else { return }
        settle()
        attach(app, "04-goal-edit")
    }

    private func captureProfileEdit() {
        let app = launch(fixture: .loggedDay)
        guard openTab(.settings, in: app) else { return }
        let settings = SettingsScreen(app: app)
        // Settings is a lazy `List`: on the closed Duo's short outer display the Profile
        // section is below the fold and not in the accessibility tree until scrolled to.
        guard scrolled(to: settings.editProfile, in: app) else { return }
        settings.editProfile.tap()
        guard app.buttons["Save"].firstMatch.awaitExistence() else { return }
        settle()
        attach(app, "05-profile-edit")
    }

    private func captureHistory() {
        let app = launch(fixture: .historyPattern)
        guard openTab(.history, in: app) else { return }
        guard HistoryScreen(app: app).calorieTrendCard.awaitExistence() else { return }
        settle()
        attach(app, "06-history")
    }

    private func captureHistoryDrillDown() {
        let app = launch(fixture: .historyPattern)
        guard openTab(.history, in: app) else { return }
        let history = HistoryScreen(app: app)
        guard history.calorieTrendCard.awaitExistence() else { return }
        history.calorieTrendCard.tap()
        guard history.calorieTrendDetails.awaitExistence() else { return }
        settle()
        attach(app, "07-history-trend")
    }

    private func captureMyFoods() {
        let app = launch(fixture: .customFoods)
        guard openTab(.myFoods, in: app) else { return }
        guard MyFoodsScreen(app: app).createMenu.awaitExistence() else { return }
        settle()
        attach(app, "08-my-foods")
    }

    private func captureCreationSheet() {
        let app = launch(fixture: .customFoods)
        guard openTab(.myFoods, in: app) else { return }
        let myFoods = MyFoodsScreen(app: app)
        guard myFoods.createMenu.awaitExistence() else { return }
        myFoods.createMenu.tap()
        guard myFoods.createManualEntry.awaitExistence() else { return }
        myFoods.createManualEntry.tap()
        guard CustomFoodFormScreen(app: app).name.awaitExistence() else { return }
        settle()
        attach(app, "09-custom-food-form")
    }

    private func captureOnboarding() {
        let app = launch(fixture: .empty)
        let onboarding = OnboardingScreen(app: app)
        guard onboarding.getStarted.awaitExistence() else { return }
        settle()
        attach(app, "10-onboarding-welcome")
        onboarding.getStarted.tap()
        guard app.buttons["Continue"].firstMatch.awaitExistence() else { return }
        settle()
        attach(app, "11-onboarding-personal-info")
    }

    // MARK: - Helpers

    private func openTab(_ destination: TabBar.Destination, in app: XCUIApplication) -> Bool {
        let tabs = TabBar(app: app)
        guard tabs.isVisible else {
            XCTFail("Tab bar should render")
            return false
        }
        tabs.go(to: destination)
        return true
    }

    private func scrolled(to element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 6) -> Bool {
        for _ in 0 ..< maxSwipes {
            if element.exists && element.isHittable { return true }
            app.swipeUp()
        }
        XCTFail("Never scrolled to \(element)")
        return false
    }

    /// A beat for glass, transitions and the digit roll to finish.
    private func settle() {
        sleep(1)
    }

    /// Every screen, not just the main one: a resizable app session (`devicectl device
    /// appResize`) hosts the app on a second display, and that is the one worth keeping.
    private func attach(_ app: XCUIApplication, _ name: String) {
        for (index, screen) in XCUIScreen.screens.enumerated() {
            let attachment = XCTAttachment(screenshot: screen.screenshot())
            attachment.name = "\(pose)-\(name)-screen\(index)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
