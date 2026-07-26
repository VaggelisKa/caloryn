import XCTest

/// Captures the app's main surfaces in both appearances, as attachments.
///
/// This is a **verification harness, not an assertion suite**. It navigates and
/// screenshots; it deliberately asserts almost nothing. Theme regressions are colour
/// problems, and no XCTAssert reads a colour — a human (or a model) has to look at the
/// image. Snapshot tests cover components; this covers whole screens, which snapshot
/// tests cannot, because they need a running store, navigation and modal presentation.
///
/// It exists because the screens that drift are the ones nothing renders in CI. The
/// `cardBackground` token was wrong in every grouped list for as long as it had existed
/// and no test noticed, because no test had ever displayed a grouped list.
///
/// Skipped in `Caloryn-UI` so it does not slow the PR gate. Run it explicitly:
///
/// ```
/// xcodebuild test -project Caloryn.xcodeproj -scheme Caloryn \
///   -only-testing:CalorynUITests/ThemeScreenshotTests \
///   -destination 'id=<UDID>' -resultBundlePath /tmp/theme.xcresult
/// xcrun xcresulttool export attachments --path /tmp/theme.xcresult --output-path /tmp/shots
/// ```
final class ThemeScreenshotTests: UITestCase {
    // MARK: - Light

    func testCaptureMainSurfacesInLightMode() {
        captureAllSurfaces(appearance: .light)
    }

    // MARK: - Dark

    func testCaptureMainSurfacesInDarkMode() {
        captureAllSurfaces(appearance: .dark)
    }

    // MARK: - Capture

    private func captureAllSurfaces(appearance: Appearance) {
        captureTodayAndSearch(appearance)
        captureHistoryDrillDown(appearance)
        captureSettingsAndMyFoods(appearance)
    }

    /// Today, plus the food search sheet — the sheet whose plain list used to paint a
    /// white block over the page background.
    private func captureTodayAndSearch(_ appearance: Appearance) {
        let app = launch(fixture: .loggedDay, appearance: appearance)
        let today = TodayScreen(app: app)

        XCTAssertTrue(today.isVisible, "Today should render")
        attach(app, "01-today", appearance)

        // The meal header doubles as the add-food button.
        let addBreakfast = today.mealHeader("Breakfast")
        if addBreakfast.waitForExistence(timeout: Self.defaultTimeout) {
            addBreakfast.tap()
            // The sheet lands on recent foods before anything is typed. Both that list
            // and the results list used a bare .listStyle(.plain).
            sleep(2)
            attach(app, "02-food-search-sheet", appearance)

            let field = app.searchFields.firstMatch.exists
                ? app.searchFields.firstMatch
                : app.textFields.firstMatch
            if field.waitForExistence(timeout: 4) {
                field.tap()
                field.typeText("oat")
                sleep(3)
                attach(app, "03-food-search-results", appearance)
            } else {
                attach(app, "03-food-search-results-UNREACHED", appearance)
            }
        } else {
            attach(app, "02-food-search-sheet-UNREACHED", appearance)
        }
    }

    /// The History drill-down. Its navigation bar was tinted by a UIKit bridge that has
    /// been deleted in favour of the AccentColor asset, so this is where a regression to
    /// system blue would show.
    private func captureHistoryDrillDown(_ appearance: Appearance) {
        let app = launch(fixture: .historyPattern, appearance: appearance)
        let tabs = TabBar(app: app)
        let history = HistoryScreen(app: app)

        XCTAssertTrue(tabs.isVisible, "Tab bar should render")
        tabs.go(to: .history)
        sleep(1)
        attach(app, "04-history", appearance)

        if history.recurringPatternCard.waitForExistence(timeout: Self.defaultTimeout) {
            history.recurringPatternCard.tap()
            if history.recurringPatternDetails.waitForExistence(timeout: Self.defaultTimeout) {
                sleep(1)
                attach(app, "05-history-drilldown", appearance)
            } else {
                attach(app, "05-history-drilldown-UNREACHED", appearance)
            }
        } else {
            attach(app, "05-history-drilldown-UNREACHED", appearance)
        }
    }

    /// Settings and My Foods are the other two grouped lists, so they carry the same
    /// row-background behaviour as Today.
    private func captureSettingsAndMyFoods(_ appearance: Appearance) {
        let app = launch(fixture: .customFoods, appearance: appearance)
        let tabs = TabBar(app: app)

        XCTAssertTrue(tabs.isVisible, "Tab bar should render")

        tabs.go(to: .settings)
        sleep(1)
        attach(app, "06-settings", appearance)

        tabs.go(to: .myFoods)
        sleep(1)
        attach(app, "07-my-foods", appearance)
    }

    // MARK: - Helpers

    private enum Appearance: String {
        case light, dark

        /// Overriding the style through a launch argument keeps each capture
        /// self-contained, rather than depending on `simctl ui` having been run first
        /// and leaving the device in whatever state the last test left it.
        var launchArguments: [String] {
            ["-AppleInterfaceStyle", rawValue == "dark" ? "Dark" : "Light"]
        }
    }

    private func launch(fixture: Fixture, appearance: Appearance) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest-reset", "-uitest-seed", fixture.rawValue]
        app.launchArguments += appearance.launchArguments
        app.launch()
        self.app = app
        return app
    }

    private func attach(_ app: XCUIApplication, _ name: String, _ appearance: Appearance) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = "\(name)-\(appearance.rawValue)"
        // Without this the attachment is discarded for a passing test, which is every
        // test here — the whole point is the artefact, not the pass.
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
