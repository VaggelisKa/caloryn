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
        captureOnboarding(appearance)
        captureTodayAndSearch(appearance)
        captureSearchInFlight(appearance)
        capturePortionPicker(appearance)
        captureMultiAddReview(appearance)
        captureHistoryDrillDown(appearance)
        captureCalorieTrendDrillDown(appearance)
        captureSettingsAndMyFoods(appearance)
        captureEmptyMyFoods(appearance)
        captureCreationSheets(appearance)
    }

    /// The whole onboarding flow — seven screens, and the only ones a user sees before
    /// there is a profile to see anything else with.
    ///
    /// It is captured first because it comes first, and it exists at all because for a
    /// long time nothing here rendered it: every one of these seven shipped with no
    /// canvas, so the first impression of the app was a system-white (or system-black)
    /// page while every screen behind it was warm. No test failed. The harness reached 18
    /// surfaces and not one of them was reachable without a seeded profile.
    ///
    /// `.empty` is the fixture with no `UserProfile`, which is exactly what
    /// `ContentView` keys onboarding off — no separate launch path is needed.
    private func captureOnboarding(_ appearance: Appearance) {
        let app = launch(fixture: .empty, appearance: appearance)
        let onboarding = OnboardingScreen(app: app)

        for (index, step) in OnboardingScreen.steps.enumerated() {
            let advance = onboarding.advance(step)
            XCTAssertTrue(
                advance.awaitExistence(),
                "Onboarding step '\(step.name)' never appeared, so it was not photographed"
            )
            // The welcome graphic animates for ~2.2s after `onAppear` (three spring
            // entrances, then a 1.5s-delayed re-layout), and the steps that follow fade
            // in with the push. A capture taken mid-animation photographs a half-drawn
            // screen, which reads as a theme problem when it is not one.
            sleep(step.name == "welcome" ? 4 : 1)
            // Lettered rather than named alphabetically, so the census lists these in
            // the order the user walks them.
            let ordinal = String(UnicodeScalar(UInt8(97 + index)))
            attach(app, "00\(ordinal)-onboarding-\(step.name)", appearance)
            advance.tap()
        }
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

    /// Results with the search still running, which no other capture can show.
    ///
    /// The list keeps a trailing spinner row while more results are on the way, and that row
    /// painted its own white background over the sheet canvas. `03-food-search-results` above
    /// cannot catch it: it waits for the search to settle, by which time the row is gone. The
    /// `search-loading` lookup fixture pins the search in flight so the row stays on screen.
    private func captureSearchInFlight(_ appearance: Appearance) {
        // `customFoods` seeds the manual entry the fixture's query matches. Without a local
        // match the view shows a full-screen spinner and never builds the list at all.
        let app = launch(
            fixture: .customFoods,
            appearance: appearance,
            lookupFixture: "search-loading"
        )
        let today = TodayScreen(app: app)

        XCTAssertTrue(today.isVisible, "Today should render")
        let addBreakfast = today.mealHeader("breakfast")
        XCTAssertTrue(addBreakfast.awaitExistence(), "Breakfast add button missing")
        addBreakfast.tap()

        // The fixture pre-fills the query, so the sheet opens straight onto the results list.
        XCTAssertTrue(searchField(in: app).awaitExistence(), "Food search sheet did not present")

        // Waiting for the search field alone would photograph any state of this sheet, and
        // the two states this capture is *not* about — the full-screen spinner and recent
        // foods — both photograph clean. The trailing spinner row only exists on the list
        // that carries a local match and a provider result at once, so assert on one of
        // each: the seeded manual entry, and a product only the pinned fixture supplies.
        XCTAssertTrue(
            result(named: "House Salad", in: app).awaitExistence(),
            "No local match, so this is the full-screen spinner rather than the results list"
        )
        XCTAssertTrue(
            result(named: "Caloryn Greek Yogurt", in: app).exists,
            "No provider result, so the list has no trailing spinner row to photograph"
        )
        sleep(2)
        attach(app, "03c-food-search-in-flight", appearance)
    }

    /// The portion picker, pushed from a search result and so still inside the search sheet —
    /// it takes the sheet canvas, not the page canvas.
    ///
    /// This uses the `customFoods` fixture and searches "House Salad" rather than reusing the
    /// `loggedDay` app above: `foodSearch.result.*` identifiers are only on search results, and
    /// "oat" there matches a logged entry that surfaces in the recent list, which carries no
    /// such identifier. The first version of this capture timed out for exactly that reason.
    private func capturePortionPicker(_ appearance: Appearance) {
        let app = launch(fixture: .customFoods, appearance: appearance)
        let today = TodayScreen(app: app)

        XCTAssertTrue(today.isVisible, "Today should render")
        let addBreakfast = today.mealHeader("breakfast")
        XCTAssertTrue(addBreakfast.awaitExistence(), "Breakfast add button missing")
        addBreakfast.tap()

        let field = searchField(in: app)
        XCTAssertTrue(field.awaitExistence(), "Search field missing")
        field.tap()
        field.typeText("Salad")

        let firstResult = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "foodSearch.result."))
            .firstMatch
        XCTAssertTrue(firstResult.awaitExistence(), "No search result to open a portion for")
        firstResult.tap()

        let calories = app.descendants(matching: .any)
            .matching(identifier: "portionPicker.calories").firstMatch
        XCTAssertTrue(calories.awaitExistence(), "Portion picker did not open")
        sleep(1)
        attach(app, "03b-portion-picker", appearance)
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

    /// The Calorie Trend drill-down, the History tab's other pushed detail.
    ///
    /// It is captured separately rather than by navigating back from Pattern Details: a back
    /// button carries no accessibility identifier, and CLAUDE.md rule 5 bans finding elements
    /// by type. Relaunching is also what every other group here does.
    ///
    /// This screen shipped with no canvas at all while its sibling had one — the whole suite
    /// stayed green because nothing had ever rendered it.
    private func captureCalorieTrendDrillDown(_ appearance: Appearance) {
        let app = launch(fixture: .historyPattern, appearance: appearance)
        let tabs = TabBar(app: app)
        let history = HistoryScreen(app: app)

        XCTAssertTrue(tabs.isVisible, "Tab bar should render")
        tabs.go(to: .history)

        XCTAssertTrue(history.calorieTrendCard.awaitExistence(), "Calorie trend card missing")
        history.calorieTrendCard.tap()
        XCTAssertTrue(
            history.calorieTrendDetails.awaitExistence(),
            "Calorie Trend detail did not open, so its canvas was not captured"
        )
        sleep(1)
        attach(app, "04b-history-calorie-trend", appearance)
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

        // Each review row pushes a portion editor, two levels deep inside the sheet.
        let item = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "multiAdd.item."))
            .firstMatch
        XCTAssertTrue(item.awaitExistence(), "No review row to open the portion editor from")
        item.tap()

        let save = app.descendants(matching: .any)
            .matching(identifier: "multiAdd.editor.save").firstMatch
        XCTAssertTrue(save.awaitExistence(), "Multi-add portion editor did not open")
        sleep(1)
        attach(app, "08b-multi-add-portion-editor", appearance)
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
    ///
    /// The two Settings editors are included because they are `Form`s on a pushed page, a
    /// combination nothing else in the app has — and both shipped with no canvas at all.
    private func captureSettingsAndMyFoods(_ appearance: Appearance) {
        let app = launch(fixture: .customFoods, appearance: appearance)
        let tabs = TabBar(app: app)
        let settings = SettingsScreen(app: app)

        XCTAssertTrue(tabs.isVisible, "Tab bar should render")

        tabs.go(to: .settings)
        sleep(1)
        attach(app, "06-settings", appearance)

        XCTAssertTrue(settings.editGoal.awaitExistence(), "Edit Goal link missing")
        settings.editGoal.tap()
        XCTAssertTrue(settings.saveGoal.awaitExistence(), "Edit Goal did not open")
        sleep(1)
        attach(app, "06b-settings-edit-goal", appearance)
        back(in: app)

        // Settings is a lazy `List`: the Profile section is below the fold and simply is not
        // in the accessibility tree until it is scrolled into view, so waiting for it times
        // out rather than failing fast.
        scrollTo(settings.editProfile, in: app)
        settings.editProfile.tap()
        let activity = app.descendants(matching: .any).matching(identifier: "Activity").firstMatch
        XCTAssertTrue(activity.awaitExistence(), "Edit Profile did not open")
        sleep(1)
        attach(app, "06c-settings-edit-profile", appearance)
        back(in: app)

        tabs.go(to: .myFoods)
        sleep(1)
        attach(app, "07-my-foods", appearance)
    }

    /// My Foods before anything is saved, which is a different view entirely — a
    /// `ContentUnavailableView` rather than the grouped list — and so has none of the
    /// list's canvas or row backgrounds to inherit. Every fixture that reached this tab
    /// before had foods in it, so the state a new user sees first was the one state
    /// nothing here captured.
    private func captureEmptyMyFoods(_ appearance: Appearance) {
        let app = launch(fixture: .profileOnly, appearance: appearance)
        let tabs = TabBar(app: app)

        XCTAssertTrue(tabs.isVisible, "Tab bar should render")
        tabs.go(to: .myFoods)

        let emptyState = app.descendants(matching: .any)
            .matching(identifier: "myFoods.emptyLibrary").firstMatch
        XCTAssertTrue(emptyState.awaitExistence(), "Empty My Foods state missing")
        sleep(1)
        attach(app, "07c-my-foods-empty", appearance)
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

    private func launch(
        fixture: Fixture,
        appearance: Appearance,
        lookupFixture: String? = nil
    ) -> XCUIApplication {
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
        if let lookupFixture {
            app.launchEnvironment["CALORYN_LOOKUP_FIXTURE"] = lookupFixture
        }
        app.launch()
        self.app = app
        return app
    }

    /// Scrolls until `element` is hittable, for rows a lazy `List` has not built yet.
    private func scrollTo(
        _ element: XCUIElement,
        in app: XCUIApplication,
        maxSwipes: Int = 6
    ) {
        for _ in 0 ..< maxSwipes {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.exists && element.isHittable, "Never scrolled to \(element)")
    }

    /// Pops a pushed detail screen.
    ///
    /// `calorynDrillDownNavigation()` replaces the system back button with one the app owns —
    /// the only way to colour it under Liquid Glass — and gives it the accessibility label
    /// "Back", which is what this matches.
    private func back(in app: XCUIApplication) {
        let button = app.buttons["Back"]
        XCTAssertTrue(button.awaitExistence(), "Themed back button missing")
        button.tap()
        sleep(1)
    }

    /// SwiftUI reports this control as a text field rather than a search field, so it is
    /// found by identifier — the element type is not part of the contract (CLAUDE.md rule 5).
    private func searchField(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: "foodSearch.searchField")
            .firstMatch
    }

    /// A row in the search results list. Every row type carries the same identifier prefix,
    /// so this says "this food is listed" without saying which branch built the row.
    private func result(named name: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: "foodSearch.result.\(name)")
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
