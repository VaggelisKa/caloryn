import XCTest

/// Captures the app's main surfaces in both appearances, as attachments.
///
/// This is a **verification harness, not an assertion suite** — for colour. No XCTAssert
/// reads a colour, so a human (or a model) has to look at the image. Snapshot tests cover
/// components; this covers whole screens, which they cannot, because whole screens need a
/// running store, navigation and modal presentation.
///
/// It *does* assert that it reached every screen. A harness that silently photographs the
/// wrong thing is worse than one that fails: the first capture of the search sheet missed
/// it entirely because the identifier uses `MealType.rawValue` (lowercase) rather than
/// `displayName`, and the run still passed.
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
        captureMultiAddReview(appearance)
        captureHistoryDrillDown(appearance)
        captureSettingsAndMyFoods(appearance)
        captureCreationSheets(appearance)
    }

    /// Today, plus the food search sheet — the sheet whose plain list used to paint a
    /// white block over the page background.
    private func captureTodayAndSearch(_ appearance: Appearance) {
        let app = launch(fixture: .loggedDay, appearance: appearance)
        let today = TodayScreen(app: app)

        XCTAssertTrue(today.isVisible, "Today should render")
        attach(app, "01-today", appearance)

        // The meal header doubles as the add-food button. The identifier uses
        // `MealType.rawValue`, which is lowercase — `displayName` is the capitalised one.
        let addBreakfast = today.mealHeader("breakfast")
        XCTAssertTrue(
            addBreakfast.awaitExistence(),
            "Could not find the breakfast add button, so the food search sheet — the screen "
                + "this harness exists to photograph — was never opened."
        )
        addBreakfast.tap()

        // The sheet lands on recent foods before anything is typed. That list and the
        // results list are separate `List`s and were separately unthemed.
        let searchField = self.searchField(in: app)
        XCTAssertTrue(searchField.awaitExistence(), "Food search sheet did not present")
        attach(app, "02-food-search-sheet", appearance)

        searchField.tap()
        searchField.typeText("oat")
        // Results are filtered locally for seeded foods, so this settles quickly; the wait
        // is for the list to re-render rather than for a network call.
        sleep(3)
        attach(app, "03-food-search-results", appearance)
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

        XCTAssertTrue(
            history.recurringPatternCard.awaitExistence(),
            "The historyPattern fixture should surface a recurring pattern card to drill into"
        )
        history.recurringPatternCard.tap()
        XCTAssertTrue(
            history.recurringPatternDetails.awaitExistence(),
            "Pattern Details did not open, so the drill-down navigation bar was not captured"
        )
        sleep(1)
        attach(app, "05-history-drilldown", appearance)
    }

    /// The multi-add review sheet, reached by selecting a result in multi-select mode.
    private func captureMultiAddReview(_ appearance: Appearance) {
        let app = launch(fixture: .customFoods, appearance: appearance)
        let today = TodayScreen(app: app)

        XCTAssertTrue(today.isVisible, "Today should render")
        let addBreakfast = today.mealHeader("breakfast")
        XCTAssertTrue(addBreakfast.awaitExistence(), "Breakfast add button missing")
        addBreakfast.tap()

        // Query first, then enter selection mode: `foodSearch.result.*` identifiers exist on
        // search results rather than on the recent list. "House Salad" comes from the
        // customFoods fixture, so this needs no network provider.
        let field = searchField(in: app)
        XCTAssertTrue(field.awaitExistence(), "Search field missing")
        field.tap()
        field.typeText("Salad")

        let firstResult = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "foodSearch.result."))
            .firstMatch
        XCTAssertTrue(firstResult.awaitExistence(), "No selectable search result")

        let select = app.buttons["Select multiple items"]
        XCTAssertTrue(select.awaitExistence(), "Multi-select toggle missing")
        select.tap()

        firstResult.tap()

        let review = app.descendants(matching: .any).matching(identifier: "multiAdd.review").firstMatch
        XCTAssertTrue(review.awaitExistence(), "Review button missing")
        review.tap()

        let commit = app.descendants(matching: .any).matching(identifier: "multiAdd.commit").firstMatch
        XCTAssertTrue(commit.awaitExistence(), "Multi-add review sheet did not present")
        attach(app, "08-multi-add-review", appearance)
    }

    /// The three creation sheets behind My Foods' + menu, plus the ingredient amount
    /// picker, which is only reachable from inside the recipe form.
    private func captureCreationSheets(_ appearance: Appearance) {
        let app = launch(fixture: .customFoods, appearance: appearance)
        let tabs = TabBar(app: app)
        let myFoods = MyFoodsScreen(app: app)

        XCTAssertTrue(tabs.isVisible, "Tab bar should render")
        tabs.go(to: .myFoods)

        capture(app, sheet: "Create Manual Entry", named: "09-custom-food-form",
                appearance: appearance, menu: myFoods.createMenu)
        capture(app, sheet: "Create Meal", named: "10-meal-form",
                appearance: appearance, menu: myFoods.createMenu)
        capture(app, sheet: "Create Recipe", named: "11-recipe-form",
                appearance: appearance, menu: myFoods.createMenu, dismiss: false)

        // Still inside the recipe form: add an ingredient to reach the amount picker.
        let addIngredient = app.descendants(matching: .any)
            .matching(identifier: "recipe.addIngredient").firstMatch
        XCTAssertTrue(addIngredient.awaitExistence(), "Add Ingredient button missing")
        addIngredient.tap()

        let ingredientField = searchField(in: app)
        XCTAssertTrue(ingredientField.awaitExistence(), "Ingredient search field missing")
        ingredientField.tap()
        ingredientField.typeText("Salad")

        let ingredient = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "foodSearch.result."))
            .firstMatch
        XCTAssertTrue(ingredient.awaitExistence(), "No food to add as an ingredient")
        ingredient.tap()
        sleep(1)
        attach(app, "12-ingredient-amount", appearance)
    }

    /// Opens one sheet from My Foods' create menu, photographs it, and closes it again.
    private func capture(
        _ app: XCUIApplication,
        sheet menuItem: String,
        named name: String,
        appearance: Appearance,
        menu: XCUIElement,
        dismiss shouldDismiss: Bool = true
    ) {
        XCTAssertTrue(menu.awaitExistence(), "My Foods create menu missing")
        menu.tap()
        let item = app.buttons[menuItem]
        XCTAssertTrue(item.awaitExistence(), "Menu item '\(menuItem)' missing")
        item.tap()
        sleep(1)
        attach(app, name, appearance)

        if shouldDismiss {
            let close = app.buttons["Close"].exists
                ? app.buttons["Close"]
                : app.buttons["Cancel"]
            if close.waitForExistence(timeout: 3) { close.tap(); sleep(1) }
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

        /// `XCUIDevice.appearance` is the only thing that actually switches the simulator.
        ///
        /// A `-AppleInterfaceStyle Dark` launch argument does **not** work here: the first
        /// version of this harness used it, and every "dark" reference image it produced
        /// was pixel-identical to its light counterpart. Nothing failed — the images were
        /// simply wrong, which is the failure mode this whole file exists to prevent.
        var device: XCUIDevice.Appearance {
            self == .dark ? .dark : .light
        }
    }

    private func launch(fixture: Fixture, appearance: Appearance) -> XCUIApplication {
        // Setting this immediately before `launch()` is a race: on a simulator that was in
        // the other appearance, the app can come up before the change lands, and the whole
        // run then photographs light images under dark filenames. It is set once per launch
        // and given a moment to settle, and the captured images are checked for the
        // appearance's own tokens afterwards (scripts/theme-screenshots.sh).
        if XCUIDevice.shared.appearance != appearance.device {
            XCUIDevice.shared.appearance = appearance.device
            sleep(2)
        }
        let app = XCUIApplication()
        app.launchArguments += ["-uitest-reset", "-uitest-seed", fixture.rawValue]
        app.launch()
        self.app = app
        return app
    }

    /// SwiftUI reports this control as a text field rather than a search field, so it is
    /// found by identifier — the element type is not part of the contract (CLAUDE.md rule 5).
    private func searchField(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: "foodSearch.searchField")
            .firstMatch
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
