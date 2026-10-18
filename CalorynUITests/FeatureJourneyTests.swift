import XCTest

/// One journey per feature whose screens nothing else drives: multi-add, recipes, meal
/// templates, the missing-food editor, profile editing and the daily reminder.
///
/// Their rules are unit-tested as plain structs; these prove the screens wire those rules
/// to what a user sees. Every outcome is read off a screen the user would check — Today's
/// rows and calorie ring, My Foods, the Settings summary — never off the form that wrote it.
///
/// The figures are arithmetic on the `customFoods` and `overBudgetDay` fixtures: House Salad
/// is 45 kcal per 100g at a 180g serving, Morning Smoothie 60 kcal per 100g at 250g, and the
/// orphaned red wine 68 kcal per 100g logged at 250g.
final class FeatureJourneyTests: UITestCase {
    // MARK: Multi-add

    func testGivenTwoSelectedFoodsWhenOnePortionIsEditedAndBothAreLoggedThenTodayCountsBoth() {
        let app = launch(fixture: .customFoods)
        let today = TodayScreen(app: app)
        let search = FoodSearchScreen(app: app)
        let multiAdd = MultiAddScreen(app: app)

        given("Add Food in selection mode with two foods ticked") {
            today.tap(today.mealHeader("breakfast"))
            search.awaitTappable(search.searchField)
            search.searchField.typeText("Salad")
            // Select stays disabled until there is something to select, and a disabled
            // button is still hittable, so wait for the result rather than the button.
            search.awaitTappable(search.result(named: "House Salad"))
            multiAdd.tap(multiAdd.selectMultiple)
            search.tap(search.result(named: "House Salad"))

            search.searchField.replaceText("Smoothie")
            search.tap(search.result(named: "Morning Smoothie"))
            // Ticking a row leaves the keyboard up, over the review button. Return submits
            // the query and puts it away.
            search.searchField.typeText("\n")
            multiAdd.tap(multiAdd.review)
        }

        when("the salad's portion is doubled in the editor and the batch is logged") {
            multiAdd.tap(multiAdd.item(named: "House Salad"))
            // The shortcuts scale off the portion being edited: half, same, double.
            multiAdd.tap(multiAdd.editorQuickGrams(360))
            // 360g of a 45 kcal/100g food.
            awaitLabel(of: multiAdd.editorCalories, equalTo: "162")
            multiAdd.tap(multiAdd.editorSave)
            XCTAssertTrue(
                multiAdd.item(named: "House Salad").awaitLabel(containing: "360 g"),
                "The review row should show the edited portion"
            )
            multiAdd.tap(multiAdd.commit)
        }

        then("both foods are on Today and the ring counts the edited portion") {
            XCTAssertTrue(today.entry(named: "House Salad").awaitLabel(containing: ", 162 kcal"))
            XCTAssertTrue(today.entry(named: "Morning Smoothie").awaitLabel(containing: ", 150 kcal"))
            // 162 + 150.
            XCTAssertTrue(today.calorieRing.awaitLabel(containing: ", 312 eaten"))
        }
    }

    // MARK: Recipes

    func testGivenARecipeBuiltFromAnIngredientWhenItIsSavedThenItLogsAtItsWholeWeight() {
        let app = launch(fixture: .customFoods)
        let tabs = TabBar(app: app)
        let myFoods = MyFoodsScreen(app: app)
        let forms = CreationFormScreen(app: app)
        let today = TodayScreen(app: app)
        let search = FoodSearchScreen(app: app)
        let portion = PortionPickerScreen(app: app)

        given("the recipe form, named") {
            XCTAssertTrue(tabs.isVisible)
            tabs.go(to: .myFoods)
            myFoods.tap(myFoods.createMenu)
            myFoods.tap(forms.createRecipe)
            forms.awaitTappable(forms.recipeName).typeText("Salad Bowl")
        }

        when("200g of a saved food is added as its one ingredient and the recipe is saved") {
            forms.tap(forms.addIngredient)
            search.awaitTappable(search.searchField)
            search.searchField.typeText("Salad")
            search.tap(search.result(named: "House Salad"))
            retype("200", into: forms.amountGrams)
            // 200g of a 45 kcal/100g food.
            awaitLabel(of: forms.amountCalories, equalTo: "90")
            forms.tap(forms.saveAmount)
            forms.tap(forms.saveRecipe)
        }

        then("My Foods lists it") {
            XCTAssertTrue(
                myFoods.food(named: "Salad Bowl").awaitExistence(),
                "The saved recipe should appear in My Foods"
            )
        }

        then("logging it defaults to the whole recipe") {
            tabs.go(to: .today)
            today.tap(today.mealHeader("lunch"))
            search.awaitTappable(search.searchField)
            search.searchField.typeText("Bowl")
            search.tap(search.result(named: "Salad Bowl"))
            portion.awaitCalories(90)
            portion.tap(portion.save)

            XCTAssertTrue(today.entry(named: "Salad Bowl").awaitLabel(containing: ", 90 kcal"))
            XCTAssertTrue(today.calorieRing.awaitLabel(containing: ", 90 eaten"))
        }
    }

    // MARK: Meal templates

    func testGivenASavedMealWhenItIsChosenFromAddFoodThenItsItemsAreLogged() {
        let app = launch(fixture: .customFoods)
        let tabs = TabBar(app: app)
        let myFoods = MyFoodsScreen(app: app)
        let forms = CreationFormScreen(app: app)
        let today = TodayScreen(app: app)
        let search = FoodSearchScreen(app: app)

        given("a meal of one smoothie, saved from My Foods") {
            XCTAssertTrue(tabs.isVisible)
            tabs.go(to: .myFoods)
            myFoods.tap(myFoods.createMenu)
            myFoods.tap(forms.createMeal)
            forms.awaitTappable(forms.mealName).typeText("Desk Lunch")
            forms.tap(forms.addMealItem)
            search.awaitTappable(search.searchField)
            search.searchField.typeText("Smoothie")
            search.tap(search.result(named: "Morning Smoothie"))
            // The item opens at the food's 250g serving.
            awaitLabel(of: forms.amountCalories, equalTo: "150")
            forms.tap(forms.saveAmount)
            forms.tap(forms.saveMeal)

            XCTAssertTrue(
                forms.libraryMeal(named: "Desk Lunch").awaitLabel(containing: "150 kilocalories"),
                "My Foods should list the meal with its total"
            )
        }

        when("the meal is chosen from lunch's Add Food") {
            tabs.go(to: .today)
            today.tap(today.mealHeader("lunch"))
            search.awaitTappable(search.searchField)
            search.searchField.typeText("Desk")
            search.tap(forms.firstMealResult)
        }

        then("its item is logged to the day") {
            XCTAssertTrue(today.entry(named: "Morning Smoothie").awaitLabel(containing: ", 150 kcal"))
            XCTAssertTrue(today.calorieRing.awaitLabel(containing: ", 150 eaten"))
        }
    }

    // MARK: Missing food

    func testGivenAnEntryWhoseFoodWasDeletedWhenItsPortionIsEditedThenTodayRecountsIt() {
        let app = launch(fixture: .overBudgetDay)
        let today = TodayScreen(app: app)
        let editor = MissingFoodEntryScreen(app: app)
        let wine = today.entry(named: "Red wine")

        given("the red wine, logged at 250g from a food that no longer exists") {
            XCTAssertTrue(today.isVisible)
            today.revealTowardBottom(wine)
            // 250g at 68 kcal per 100g.
            XCTAssertTrue(wine.label.contains(", 170 kcal"), "Unexpected starting row: \(wine.label)")
        }

        when("the user opens it and changes the portion to 100g") {
            today.tap(wine)
            // The field's frame spans the whole row and ends on the "g" beside the well, and
            // the well's padding takes no taps, so the text's trailing edge is further in.
            retype("100", into: editor.portion, atTrailingOffset: 0.88)
            editor.tap(editor.save)
        }

        then("Today recounts the entry from its own snapshot") {
            XCTAssertTrue(today.revealTowardBottom(wine).awaitLabel(containing: ", 68 kcal"))
        }
    }

    // MARK: Profile

    func testGivenAProfileWhenAgeAndSexAreEditedThenSettingsSummarisesTheNewValues() {
        let app = launch(fixture: .profileOnly)
        let tabs = TabBar(app: app)
        let settings = SettingsScreen(app: app)
        let profile = ProfileEditScreen(app: app)

        given("Settings showing a 30-year-old male profile") {
            XCTAssertTrue(tabs.isVisible)
            tabs.go(to: .settings)
            scroll(to: profile.settingsAge, in: app)
            scroll(to: settings.editProfile, in: app)
            XCTAssertTrue(profile.settingsAge.label.hasSuffix(", 30"), profile.settingsAge.label)
            XCTAssertTrue(profile.settingsSex.label.contains("Male"), profile.settingsSex.label)
        }

        when("the user edits the profile: one year older, female") {
            settings.tap(settings.editProfile)
            // The stepper is one adjustable element, minus at its leading end and plus at
            // its trailing end; iOS has no `increment()`, so tap where the plus is drawn.
            profile.awaitTappable(profile.age)
                .coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
                .tap()
            XCTAssertEqual(profile.age.value as? String, "31", "The plus should add a year")
            profile.tap(profile.sex("female"))
            profile.tap(profile.save)
        }

        then("the Settings summary reports the saved values") {
            XCTAssertTrue(profile.settingsAge.awaitLabel(containing: ", 31"))
            XCTAssertTrue(profile.settingsSex.awaitLabel(containing: "Female"))
        }
    }

    // MARK: Daily reminder

    func testGivenTheReminderIsOffWhenItIsTurnedOnThenItsTimeCanBeChosenUntilItIsTurnedOff() {
        let app = launch(fixture: .profileOnly)
        let tabs = TabBar(app: app)
        let reminder = DailyReminderScreen(app: app)

        given("Settings with the reminder off") {
            XCTAssertTrue(tabs.isVisible)
            tabs.go(to: .settings)
            scroll(to: reminder.toggle, in: app)
            // The switch lives in UserDefaults, which `-uitest-reset` does not clear, so an
            // earlier run can leave it on.
            if reminder.isOn {
                reminder.flip()
                XCTAssertTrue(awaitAbsence(of: reminder.time))
            }
        }

        when("the user turns it on") {
            reminder.flip()
            allowNotificationsIfAsked(thenAwait: reminder.time, deniedSign: reminder.openSettings)
        }

        then("a different time chosen on the wheel is the one the row reports") {
            let before = reminder.time.label
            reminder.tap(reminder.time)
            // The wheel's columns are not elements of their own, so drag the hour column
            // (the leading third) up by about two rows.
            let picker = reminder.awaitTappable(reminder.timePicker)
            picker.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5))
                .press(
                    forDuration: 0.05,
                    thenDragTo: picker.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.25))
                )
            let changed = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "label != %@", before),
                object: reminder.time
            )
            XCTAssertEqual(
                XCTWaiter().wait(for: [changed], timeout: UITestCase.defaultTimeout),
                .completed,
                "Turning the wheel should change the reminder time, still \(before)"
            )

            // Closing the picker keeps the new time.
            let chosen = reminder.time.label
            reminder.tap(reminder.time)
            XCTAssertTrue(awaitAbsence(of: reminder.timePicker), "Tapping the row again should close the wheel")
            XCTAssertEqual(reminder.time.label, chosen)
        }

        then("turning it off again withdraws the time") {
            reminder.flip()
            XCTAssertTrue(awaitAbsence(of: reminder.time), "The time row should go with the reminder")
        }
    }

    // MARK: - Helpers

    /// Settings is a lazy `List`: rows below the fold are not in the accessibility tree
    /// until scrolled toward. A short drag rather than `swipeUp()`, whose momentum carried
    /// the profile rows clean off the top while it brought the button under them in.
    private func scroll(to element: XCUIElement, in app: XCUIApplication, maxDrags: Int = 10) {
        let window = app.windows.firstMatch
        var drags = 0
        while !element.isHittable, drags < maxDrags {
            window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
                .press(
                    forDuration: 0.05,
                    thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
                )
            drags += 1
        }
        XCTAssertTrue(element.isHittable, "Never scrolled to \(element)")
    }

    /// Replaces a number field's contents. Both fields here are right-aligned, so a tap at
    /// the centre can land the cursor before the old digits and `replaceText`'s deletes
    /// then remove nothing: "200" typed over "180" became 200180g. Tapping the trailing
    /// edge puts the cursor after the last digit.
    private func retype(_ text: String, into field: XCUIElement, atTrailingOffset offset: CGFloat = 0.97) {
        // Hittable rather than merely existing: a field in a sheet exists while the sheet
        // is still sliding up, and a tap aimed at it then lands where it used to be.
        let hittable = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: field)
        XCTAssertEqual(XCTWaiter().wait(for: [hittable], timeout: UITestCase.defaultTimeout), .completed, "\(field) never became tappable")
        field.coordinate(withNormalizedOffset: CGVector(dx: offset, dy: 0.5)).tap()
        let existing = (field.value as? String)?.count ?? 0
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing + 2))
        field.typeText(text)
    }

    /// Waits for a figure to read exactly `expected`. Containment would pass "90" for
    /// "90.081", which is how a mistyped amount once slipped through.
    private func awaitLabel(
        of element: XCUIElement,
        equalTo expected: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let matches = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", expected),
            object: element
        )
        if XCTWaiter().wait(for: [matches], timeout: UITestCase.defaultTimeout) != .completed {
            XCTFail("\(element) read \"\(element.label)\" rather than \"\(expected)\"", file: file, line: line)
        }
    }

    private func awaitAbsence(of element: XCUIElement) -> Bool {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        return XCTWaiter().wait(for: [gone], timeout: UITestCase.defaultTimeout) == .completed
    }

    /// The first request on a simulator raises the system's notification prompt; later
    /// runs resolve from the stored answer and raise nothing. One wait covers both: it
    /// ends on whichever of the prompt and `element` appears first.
    ///
    /// The prompt is SpringBoard's, so it carries no identifier this app could set — its
    /// button is found by its label, the one exception to finding elements by identifier.
    ///
    /// A simulator that once answered "Don't Allow" never prompts again, and neither
    /// `simctl privacy` nor `resetAuthorizationStatus(for:)` covers notifications, so the
    /// test cannot put it back. The wait also ends on the app's own denied state so that
    /// case fails saying what to do, rather than as a timeout that reads like a bug.
    private func allowNotificationsIfAsked(thenAwait element: XCUIElement, deniedSign: XCUIElement) {
        let allow = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["Allow"]
        let settled = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in element.exists || allow.exists || deniedSign.exists },
            object: nil
        )
        XCTAssertEqual(
            XCTWaiter().wait(for: [settled], timeout: UITestCase.defaultTimeout),
            .completed,
            "Turning the reminder on neither prompted nor showed its time"
        )
        if deniedSign.exists {
            XCTFail(
                "Notifications are denied for Caloryn on this simulator, so the reminder cannot "
                    + "turn on. Run `xcrun simctl erase <device>` (or allow them in Settings) and rerun."
            )
            return
        }
        if allow.exists {
            allow.tap()
            XCTAssertTrue(element.awaitExistence(), "Allowing notifications should turn the reminder on")
        }
    }
}
