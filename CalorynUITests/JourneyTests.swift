import XCTest

final class JourneyTests: UITestCase {
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

    func testGivenTheActivityLevelStepWhenACardIsTappedAwayFromItsTextThenThatLevelIsSelected() {
        let app = launch(fixture: .empty)
        let onboarding = OnboardingScreen(app: app)
        let veryActive = onboarding.activityLevel("veryActive")

        given("the activity level step, with another level selected") {
            onboarding.tap(onboarding.getStarted)
            onboarding.tap(onboarding.element("onboarding.personalInfo.continue"))
            XCTAssertFalse(
                onboarding.awaitTappable(veryActive).isSelected,
                "Very Active should not be the starting choice"
            )
            XCTAssertTrue(
                veryActive.label.contains("Hard exercise"),
                "The row should speak its description, not just its name: \(veryActive.label)"
            )
        }

        then("the whole row is a tap target, not just its text") {
            XCTAssertGreaterThanOrEqual(
                veryActive.frame.height,
                44,
                "A selectable row must offer at least a 44pt tap target"
            )
        }

        when("the user taps the row well right of its text") {
            veryActive.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        }

        then("that level becomes the selected one") {
            let selected = XCTNSPredicateExpectation(
                predicate: NSPredicate { element, _ in
                    (element as? XCUIElement)?.isSelected == true
                },
                object: veryActive
            )
            XCTAssertEqual(
                XCTWaiter().wait(for: [selected], timeout: UITestCase.defaultTimeout),
                .completed,
                "Tapping anywhere on the row should select it"
            )
        }
    }

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

    func testGivenTheKeypadIsOpenWhenTappingOffTheFieldThenItCloses() {
        let app = launch(fixture: .customFoods)
        let today = TodayScreen(app: app)
        let search = FoodSearchScreen(app: app)
        let portion = PortionPickerScreen(app: app)

        given("the keypad is open over the portion screen") {
            today.tap(today.mealHeader("lunch"))
            search.awaitTappable(search.searchField)
            search.searchField.typeText("Salad")
            search.tap(search.result(named: "House Salad"))
            portion.tap(portion.amountBox)
            XCTAssertTrue(
                app.keyboards.firstMatch.awaitExistence(),
                "Tapping the amount should raise the keypad"
            )
        }

        when("the user taps the page away from the field") {
            portion.tap(portion.calories)
        }

        then("the keypad goes away") {
            let gone = NSPredicate(format: "exists == false")
            let expectation = XCTNSPredicateExpectation(predicate: gone, object: app.keyboards.firstMatch)
            XCTAssertEqual(
                XCTWaiter().wait(for: [expectation], timeout: UITestCase.defaultTimeout),
                .completed,
                "A tap off the field should put the keypad away"
            )
        }

        then("the field still works afterwards") {
            portion.typeGrams(250)
            portion.awaitCalories(113)
        }
    }

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
            portion.tap(portion.quickGrams(50))
        }

        then("the preview moves to that amount") {
            portion.awaitCalories(23)
        }

        then("a typed amount still overrides the shortcut afterwards") {
            portion.typeGrams(400)
            portion.awaitCalories(180)
        }
    }

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

                history.awaitRangeSelected(label)

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
        let typedTarget = 2400.formatted(.number)

        given("Settings showing a calculated calorie target") {
            XCTAssertTrue(tabs.isVisible)
            tabs.go(to: .settings)
            XCTAssertTrue(settings.calorieTarget.awaitExistence())
            XCTAssertFalse(
                settings.calorieTarget.label.contains(typedTarget),
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
            XCTAssertTrue(settings.calorieTarget.awaitLabel(containing: typedTarget))
        }
    }

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
                try app.performAccessibilityAudit(for: auditTypes)
            }
        }
    }
}
