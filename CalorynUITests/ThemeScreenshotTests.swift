import UIKit
import XCTest

final class ThemeScreenshotTests: UITestCase {
    func testCaptureMainSurfacesInLightMode() {
        captureAllSurfaces(appearance: .light)
    }

    func testCaptureMainSurfacesInDarkMode() {
        captureAllSurfaces(appearance: .dark)
    }

    private func captureAllSurfaces(appearance: Appearance) {
        captureOnboarding(appearance)
        captureTodayAndSearch(appearance)
        captureOverBudgetDay(appearance)
        captureSearchSkeleton(appearance)
        captureSearchInFlight(appearance)
        captureLookupFailure(appearance, fixture: "search-offline", named: "03e-food-search-offline")
        captureLookupFailure(appearance, fixture: "barcode-not-found", named: "03f-barcode-not-found")
        capturePortionPicker(appearance)
        capturePastedFoodConfirmation(appearance)
        captureMultiAddReview(appearance)
        captureHistoryDrillDown(appearance)
        captureCalorieTrendDrillDown(appearance)
        captureSettingsAndMyFoods(appearance)
        captureEmptyMyFoods(appearance)
        captureCreationSheets(appearance)
    }

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
            let ordinal = String(UnicodeScalar(UInt8(97 + index)))
            attach(app, "00\(ordinal)-onboarding-\(step.name)", appearance)
            advance.tap()
        }
    }

    private func captureTodayAndSearch(_ appearance: Appearance) {
        let app = launch(fixture: .loggedDay, appearance: appearance)
        let today = TodayScreen(app: app)

        XCTAssertTrue(today.isVisible, "Today should render")
        attach(app, "01-today", appearance)

        let addBreakfast = today.mealHeader("breakfast")
        XCTAssertTrue(
            addBreakfast.awaitExistence(),
            "Could not find the breakfast add button, so the food search sheet — the screen "
                + "this harness exists to photograph — was never opened."
        )
        addBreakfast.tap()

        let searchField = self.searchField(in: app)
        XCTAssertTrue(searchField.awaitExistence(), "Food search sheet did not present")
        attach(app, "02-food-search-sheet", appearance)

        searchField.tap()
        searchField.typeText("oat")
        sleep(3)
        attach(app, "03-food-search-results", appearance)
    }

    private func captureLookupFailure(_ appearance: Appearance, fixture: String, named name: String) {
        let app = launch(fixture: .customFoods, appearance: appearance, lookupFixture: fixture)
        let today = TodayScreen(app: app)

        XCTAssertTrue(today.isVisible, "Today should render")
        let addBreakfast = today.mealHeader("breakfast")
        XCTAssertTrue(addBreakfast.awaitExistence(), "Breakfast add button missing")
        addBreakfast.tap()

        XCTAssertTrue(searchField(in: app).awaitExistence(), "Food search sheet did not present")
        sleep(2)
        attach(app, name, appearance)
    }

    private func captureOverBudgetDay(_ appearance: Appearance) {
        let app = launch(fixture: .overBudgetDay, appearance: appearance)
        let today = TodayScreen(app: app)

        XCTAssertTrue(today.isVisible, "Today should render")
        sleep(1)
        attach(app, "01b-today-over-budget", appearance)

        today.calorieRing.tap()
        let consumed = app.descendants(matching: .any)
            .matching(identifier: "nutritionDetails.consumedCalories").firstMatch
        XCTAssertTrue(consumed.awaitExistence(), "Nutrition Details did not open")
        sleep(1)
        attach(app, "01c-nutrition-details", appearance)

        consumed.swipeUp()
        let dataQualityNote = app.descendants(matching: .any)
            .matching(identifier: "nutritionDetails.dataQualityNote").firstMatch
        scrollTo(dataQualityNote, in: app)
        app.swipeUp()
        sleep(1)
        attach(app, "01d-nutrition-details-bottom", appearance)
        dismissSheet(in: app)

        let garlicBread = today.entry(named: "Garlic bread")
        scrollTo(garlicBread, in: app)
        garlicBread.tap()
        let delete = app.descendants(matching: .any)
            .matching(identifier: "portionPicker.delete").firstMatch
        XCTAssertTrue(delete.awaitExistence(), "The edit-mode Portion sheet did not open")
        sleep(1)
        attach(app, "03d-portion-edit", appearance)
        dismissSheet(in: app)

        let redWine = today.entry(named: "Red wine")
        scrollTo(redWine, in: app)
        redWine.tap()
        let portion = app.descendants(matching: .any)
            .matching(identifier: "missingEntry.portion").firstMatch
        XCTAssertTrue(portion.awaitExistence(), "The missing-food editor did not open")
        sleep(1)
        attach(app, "01d-missing-food-editor", appearance)
    }

    private func captureSearchSkeleton(_ appearance: Appearance) {
        let app = launch(
            fixture: .loggedDay,
            appearance: appearance,
            lookupFixture: "search-loading"
        )
        let today = TodayScreen(app: app)

        XCTAssertTrue(today.isVisible, "Today should render")
        let addBreakfast = today.mealHeader("breakfast")
        XCTAssertTrue(addBreakfast.awaitExistence(), "Breakfast add button missing")
        addBreakfast.tap()

        let skeleton = app.descendants(matching: .any)
            .matching(identifier: "foodSearch.loading").firstMatch
        XCTAssertTrue(
            skeleton.awaitExistence(),
            "The sheet is not on the loading skeleton, so this photographs some other state"
        )
        sleep(1)
        attach(app, "03g-food-search-skeleton", appearance)
    }

    private func captureSearchInFlight(_ appearance: Appearance) {
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

        XCTAssertTrue(searchField(in: app).awaitExistence(), "Food search sheet did not present")

        XCTAssertTrue(
            result(named: "House Salad", in: app).awaitExistence(),
            "No local match, so this is the full-screen skeleton rather than the results list"
        )
        XCTAssertTrue(
            result(named: "Caloryn Greek Yogurt", in: app).exists,
            "No provider result, so the list has no trailing skeleton rows to photograph"
        )
        app.swipeUp()
        sleep(2)
        attach(app, "03c-food-search-in-flight", appearance)
    }

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

    private func capturePastedFoodConfirmation(_ appearance: Appearance) {
        let app = launch(fixture: .loggedDay, appearance: appearance)
        let today = TodayScreen(app: app)
        let pasted = PastedFoodScreen(app: app)

        XCTAssertTrue(today.isVisible, "Today should render")
        UIPasteboard.general.string = "caloryn://log?v=1"
            + "&name=Chicken%20Caesar%20salad%20with%20croutons%2C%20parmesan%20and%20extra%20dressing"
            + "&kcal=640&protein=38.5&fat=42"
        let addBreakfast = today.mealHeader("breakfast")
        XCTAssertTrue(addBreakfast.awaitExistence(), "Breakfast add button missing")
        addBreakfast.tap()

        XCTAssertTrue(pasted.paste.awaitExistence(), "The paste panel is missing from the food search sheet")
        sleep(1)
        attach(app, "03h-paste-panel", appearance)
        pasted.paste.tap()
        XCTAssertTrue(
            pasted.addBlockedReason.awaitExistence(),
            "The pasted food confirmation did not open on a link without grams"
        )
        sleep(1)
        attach(app, "03h-pasted-food-confirmation", appearance)
        UIPasteboard.general.string = ""
    }

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

    private func captureMultiAddReview(_ appearance: Appearance) {
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
        sleep(1)
        attach(app, "11b-ingredient-search", appearance)
        ingredient.tap()
        sleep(1)
        attach(app, "12-ingredient-amount", appearance)
    }

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

        scrollTo(settings.editProfile, in: app)
        settings.editProfile.tap()
        let activity = app.descendants(matching: .any).matching(identifier: "Activity").firstMatch
        XCTAssertTrue(activity.awaitExistence(), "Edit Profile did not open")
        sleep(1)
        attach(app, "06c-settings-edit-profile", appearance)
        back(in: app)

        for _ in 0 ..< 4 { app.swipeUp() }
        sleep(1)
        attach(app, "06d-settings-bottom", appearance)

        tabs.go(to: .myFoods)
        sleep(1)
        attach(app, "07-my-foods", appearance)
    }

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

    private func dismissSheet(in app: XCUIApplication) {
        let close = app.buttons["Close"].firstMatch
        if close.waitForExistence(timeout: 3) {
            close.tap()
        } else {
            app.swipeDown(velocity: .fast)
        }
        sleep(1)
    }

    private func back(in app: XCUIApplication) {
        let button = app.buttons["Back"]
        XCTAssertTrue(button.awaitExistence(), "Themed back button missing")
        button.tap()
        sleep(1)
    }

    private func searchField(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: "foodSearch.searchField")
            .firstMatch
    }

    private func result(named name: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: "foodSearch.result.\(name)")
            .firstMatch
    }

    private func attach(_ app: XCUIApplication, _ name: String, _ appearance: Appearance) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = "\(name)-\(appearance.rawValue)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
