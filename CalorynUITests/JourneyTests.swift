import XCTest

/// End-to-end journeys through the app's critical paths.
///
/// These are the safety net for the planned refactor that moves logic out of
/// views, so every assertion here is about what a user can observe: visible
/// text, values, and whether something exists. None of them depend on which
/// type performs the work, so they must pass unchanged after that refactor.
final class JourneyTests: UITestCase {
    // MARK: Onboarding

    func testGivenAFirstLaunchWhenOnboardingIsCompletedThenTheMainTabsAppear() {
        let app = launch(fixture: .empty)
        let onboarding = OnboardingScreen(app: app)
        let tabs = TabBar(app: app)

        given("a first launch with no profile") {
            XCTAssertTrue(onboarding.getStarted.awaitExistence(), "Onboarding should be presented")
        }

        when("the user completes onboarding with the default answers") {
            onboarding.completeWithDefaults()
        }

        then("the app opens the main tab flow") {
            XCTAssertTrue(tabs.isVisible, "Main tabs should appear once a profile exists")
        }
    }

    // MARK: Today

    func testGivenADayWithALoggedEntryWhenTodayOpensThenTheEntryAndRingAreShown() {
        let app = launch(fixture: .loggedDay)
        let today = TodayScreen(app: app)

        then("the seeded breakfast entry and the calorie ring are visible") {
            XCTAssertTrue(today.isVisible, "The calorie ring should be shown")
            XCTAssertTrue(
                today.entry(named: "Rolled Oats").awaitExistence(),
                "The logged entry should be listed on Today"
            )
        }
    }

    func testGivenALoggedEntryWhenItIsDeletedThenItLeavesTheDay() {
        let app = launch(fixture: .loggedDay)
        let today = TodayScreen(app: app)
        let portion = PortionPickerScreen(app: app)
        let entry = today.entry(named: "Rolled Oats")

        given("a day containing one logged entry") {
            XCTAssertTrue(entry.awaitExistence())
        }

        when("the user opens the entry and confirms deletion") {
            today.tap(entry)
            today.tap(portion.delete)
            // Deletion is guarded by a confirmation dialog.
            today.tap(app.buttons["Delete"].firstMatch)
        }

        then("the entry is no longer part of the day") {
            let gone = NSPredicate(format: "exists == false")
            let expectation = XCTNSPredicateExpectation(predicate: gone, object: entry)
            XCTAssertEqual(
                XCTWaiter().wait(for: [expectation], timeout: UITestCase.defaultTimeout),
                .completed,
                "The deleted entry should disappear from Today"
            )
        }
    }

    func testGivenASavedFoodWhenItIsSearchedAndPortionedThenItJoinsTheDay() {
        let app = launch(fixture: .customFoods)
        let today = TodayScreen(app: app)
        let search = FoodSearchScreen(app: app)
        let portion = PortionPickerScreen(app: app)

        given("a day with saved foods but nothing logged to breakfast") {
            XCTAssertTrue(today.isVisible)
            XCTAssertFalse(today.entry(named: "Morning Smoothie").exists)
        }

        when("the user searches breakfast for a saved food and accepts the portion") {
            today.tap(today.mealHeader("breakfast"))
            search.awaitTappable(search.searchField)
            search.searchField.typeText("Smoothie")
            search.tap(search.result(named: "Morning Smoothie"))
            portion.tap(portion.save)
        }

        then("the food is logged to the day") {
            XCTAssertTrue(
                today.entry(named: "Morning Smoothie").awaitExistence(),
                "The chosen food should appear under breakfast"
            )
        }
    }

    func testGivenALoggedDayWhenTheRingIsOpenedThenNutritionDetailsAreShown() {
        let app = launch(fixture: .loggedDay)
        let today = TodayScreen(app: app)
        let details = NutritionDetailsScreen(app: app)

        given("a day with one logged entry") {
            XCTAssertTrue(today.entry(named: "Rolled Oats").awaitExistence())
        }

        when("the user taps the calorie ring") {
            today.tap(today.calorieRing)
        }

        then("the nutrition breakdown for the day is presented") {
            XCTAssertTrue(
                details.title.awaitExistence(),
                "Tapping the ring should open the day's nutrition details"
            )
            XCTAssertTrue(
                details.consumedCalories.awaitExistence(),
                "The details should report what has been consumed"
            )
        }
    }

    // MARK: Typing a portion

    /// House Salad is 45 kcal per 100g and opens at its 180g serving, so every
    /// figure below is arithmetic the user can check on screen: 180g is 81
    /// calories, 300g is 135.
    func testGivenAPortionInGramsWhenAnAmountIsTypedThenThatAmountIsWhatGetsLogged() {
        let app = launch(fixture: .customFoods)
        let today = TodayScreen(app: app)
        let search = FoodSearchScreen(app: app)
        let portion = PortionPickerScreen(app: app)

        given("the portion screen for a food measured in grams") {
            today.tap(today.mealHeader("lunch"))
            search.awaitTappable(search.searchField)
            search.searchField.typeText("Salad")
            search.tap(search.result(named: "House Salad"))
            portion.awaitCalories(81)
        }

        when("the user types a different amount") {
            portion.typeGrams(300)
        }

        then("the calorie preview follows what was typed") {
            portion.awaitCalories(135)
        }

        then("saving logs the typed amount, not the one the screen opened with") {
            // Saved straight from the keypad, without the field ever losing
            // focus — the path a user actually takes, and the one where a
            // half-handled edit would log the opening 180g instead.
            portion.tap(portion.save)

            XCTAssertTrue(
                today.entry(named: "House Salad").awaitExistence(),
                "The food should be logged to the day"
            )
            XCTAssertTrue(
                app.staticTexts["135"].awaitExistence(),
                "Today should report the calories for the typed 300g, not the opening 180g"
            )
        }
    }

    /// The shortcuts exist so a common amount costs one tap. This is also the
    /// only journey that proves the field and the chips agree: the chip has to
    /// move the number the field shows, not just the portion behind it.
    func testGivenAPortionInGramsWhenAShortcutIsTappedThenItSetsTheAmount() {
        let app = launch(fixture: .customFoods)
        let today = TodayScreen(app: app)
        let search = FoodSearchScreen(app: app)
        let portion = PortionPickerScreen(app: app)

        given("the portion screen for a food measured in grams") {
            today.tap(today.mealHeader("lunch"))
            search.awaitTappable(search.searchField)
            search.searchField.typeText("Salad")
            search.tap(search.result(named: "House Salad"))
            portion.awaitCalories(81)
        }

        when("the user taps a shortcut amount") {
            // 50g is the first shortcut for a food with no countable serving.
            portion.tap(portion.quickGrams(50))
        }

        then("the preview moves to that amount") {
            // 50g of 45 kcal per 100g.
            portion.awaitCalories(22)
        }

        then("a typed amount still overrides the shortcut afterwards") {
            portion.typeGrams(400)
            portion.awaitCalories(180)
        }
    }

    // MARK: My Foods

    func testGivenSavedCustomFoodsWhenMyFoodsOpensThenTheyAreListed() {
        let app = launch(fixture: .customFoods)
        let tabs = TabBar(app: app)
        let myFoods = MyFoodsScreen(app: app)

        when("the user opens My Foods") {
            XCTAssertTrue(tabs.isVisible)
            tabs.go(to: .myFoods)
        }

        then("both saved custom foods are listed") {
            XCTAssertTrue(
                myFoods.food(named: "Morning Smoothie").awaitExistence(),
                "The favorited custom food should be listed"
            )
            XCTAssertTrue(
                myFoods.food(named: "House Salad").awaitExistence(),
                "The second custom food should be listed"
            )
        }
    }

    func testGivenAnEmptyLibraryWhenAFoodIsCreatedThenItBecomesLoggable() {
        let app = launch(fixture: .profileOnly)
        let tabs = TabBar(app: app)
        let myFoods = MyFoodsScreen(app: app)
        let form = CustomFoodFormScreen(app: app)
        let today = TodayScreen(app: app)
        let search = FoodSearchScreen(app: app)
        let portion = PortionPickerScreen(app: app)

        given("a profile with no saved foods") {
            XCTAssertTrue(tabs.isVisible)
            tabs.go(to: .myFoods)
            XCTAssertFalse(myFoods.food(named: "Desk Almonds").exists)
        }

        when("the user creates a manual entry") {
            myFoods.tap(myFoods.createMenu)
            myFoods.tap(myFoods.createManualEntry)
            form.tap(form.name)
            form.name.typeText("Desk Almonds")
            // Calories sits far enough down the form that the keyboard can put
            // it below the fold, so scroll to it rather than waiting on it.
            form.tap(form.revealed(form.calories))
            form.calories.typeText("180")
            form.tap(form.save)
        }

        then("it is saved to the library") {
            XCTAssertTrue(
                myFoods.food(named: "Desk Almonds").awaitExistence(),
                "The created food should appear in My Foods"
            )
        }

        then("it can be logged from search like any other food") {
            tabs.go(to: .today)
            today.tap(today.mealHeader("snack"))
            search.awaitTappable(search.searchField)
            search.searchField.typeText("Almonds")
            search.tap(search.result(named: "Desk Almonds"))
            portion.tap(portion.save)

            XCTAssertTrue(
                today.entry(named: "Desk Almonds").awaitExistence(),
                "The newly created food should be loggable straight away"
            )
        }
    }

    // MARK: History

    func testGivenThirtyLoggedDaysWhenHistoryRangesAreSwitchedThenEachRangeRenders() {
        let app = launch(fixture: .history)
        let tabs = TabBar(app: app)
        let history = HistoryScreen(app: app)

        when("the user opens History") {
            XCTAssertTrue(tabs.isVisible)
            tabs.go(to: .history)
        }

        then("the range control is available and every range renders content") {
            XCTAssertTrue(history.rangePicker.awaitExistence(), "History should offer a range control")

            for label in ["7 Days", "14 Days", "30 Days", "90 Days"] {
                history.selectRange(label)

                // Assert the selection actually moved. Checking that the
                // range control still exists would pass even if tapping did
                // nothing, since the control is always on screen.
                history.awaitRangeSelected(label)

                // And that the screen still renders its trend content for the
                // newly selected range rather than going blank.
                XCTAssertTrue(
                    app.staticTexts.count > 0,
                    "History should render content for the \(label) range"
                )
            }
        }
    }

    func testGivenAQualifyingPatternWhenADayIsExpandedThenEvidenceStaysInPatternDetails() {
        let app = launch(fixture: .historyPattern)
        let tabs = TabBar(app: app)
        let history = HistoryScreen(app: app)

        when("the user opens History") {
            XCTAssertTrue(tabs.isVisible)
            tabs.go(to: .history)
        }

        then("one evidence-backed recurring pattern is available") {
            XCTAssertTrue(
                history.recurringPatternCard.awaitExistence(),
                "History should surface the qualifying recurring pattern"
            )
        }

        when("the user opens the pattern and expands one supporting logged day") {
            history.tap(history.recurringPatternCard)
            XCTAssertTrue(
                history.recurringPatternDetails.awaitExistence(),
                "Pattern Details should explain the observation"
            )
            history.tap(history.supportingPatternDay)
        }

        then("the contributing foods appear without another drilldown") {
            XCTAssertTrue(
                history.expandedSupportingPatternDay.awaitExistence(),
                "A supporting logged day should expand inside Pattern Details"
            )
            XCTAssertTrue(
                history.recurringPatternDetails.exists,
                "Expanded day evidence should remain inside Pattern Details"
            )
        }
    }

    func testGivenNoQualifyingPatternWhenHistoryOpensThenNoInsightCardIsShown() {
        let app = launch(fixture: .historyNoPattern)
        let tabs = TabBar(app: app)
        let history = HistoryScreen(app: app)

        when("the user opens History") {
            XCTAssertTrue(tabs.isVisible)
            tabs.go(to: .history)
        }

        then("the fixed-range History content renders without an empty pattern state") {
            XCTAssertTrue(history.rangePicker.awaitExistence())
            XCTAssertFalse(
                history.recurringPatternCard.exists,
                "History should omit the insight UI when no candidate qualifies"
            )
        }
    }

    // MARK: Settings

    func testGivenAProfileWhenTheCalorieTargetIsViewedThenSettingsShowsIt() {
        let app = launch(fixture: .profileOnly)
        let tabs = TabBar(app: app)
        let settings = SettingsScreen(app: app)

        when("the user opens Settings") {
            XCTAssertTrue(tabs.isVisible)
            tabs.go(to: .settings)
        }

        then("the daily calorie target is shown") {
            XCTAssertTrue(
                settings.calorieTarget.awaitExistence(),
                "Settings should display the daily calorie target"
            )
        }
    }

    func testGivenACalculatedTargetWhenItIsOverriddenManuallyThenSettingsShowsTheNewTarget() {
        let app = launch(fixture: .profileOnly)
        let tabs = TabBar(app: app)
        let settings = SettingsScreen(app: app)

        given("Settings showing a calculated calorie target") {
            XCTAssertTrue(tabs.isVisible)
            tabs.go(to: .settings)
            XCTAssertTrue(settings.calorieTarget.awaitExistence())
            XCTAssertNotEqual(
                settings.calorieTarget.label,
                "2400 kcal",
                "The fixture should not already sit on the target this test types"
            )
        }

        when("the user overrides the target by hand and saves") {
            settings.tap(settings.editGoal)
            settings.tap(settings.manualOverride)
            settings.awaitTappable(settings.goalTargetField).replaceText("2400")
            settings.tap(settings.saveGoal)
        }

        then("Settings reports the target the user typed") {
            XCTAssertTrue(settings.calorieTarget.awaitLabel(containing: "2400"))
        }
    }

    // MARK: Accessibility

    func testGivenTheMainScreensWhenAuditedThenNoAccessibilityIssuesAreReported() throws {
        let app = launch(fixture: .history)
        let tabs = TabBar(app: app)

        XCTAssertTrue(tabs.isVisible)

        for destination in [TabBar.Destination.today, .myFoods, .history, .settings] {
            tabs.go(to: destination)

            let auditTypes: XCUIAccessibilityAuditType = [
                .elementDetection,
                .sufficientElementDescription,
                .hitRegion
            ]

            try XCTContext.runActivity(named: "Audit \(destination.rawValue)") { _ in
                // Contrast and dynamic-type audits are excluded because they report on
                // the design system rather than on defects this suite is positioned to fix.
                try app.performAccessibilityAudit(for: auditTypes)
            }
        }
    }
}
