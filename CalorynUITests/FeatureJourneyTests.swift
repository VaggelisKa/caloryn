import XCTest

final class FeatureJourneyTests: UITestCase {
    func testGivenTwoSelectedFoodsWhenOnePortionIsEditedAndBothAreLoggedThenTodayCountsBoth() {
        let app = launch(fixture: .customFoods)
        let today = TodayScreen(app: app)
        let search = FoodSearchScreen(app: app)
        let multiAdd = MultiAddScreen(app: app)

        given("Add Food in selection mode with two foods ticked") {
            today.tap(today.mealHeader("breakfast"))
            search.awaitTappable(search.searchField)
            search.searchField.typeText("Salad")
            search.awaitTappable(search.result(named: "House Salad"))
            multiAdd.tap(multiAdd.selectMultiple)
            search.tap(search.result(named: "House Salad"))

            search.searchField.replaceText("Smoothie")
            search.tap(search.result(named: "Morning Smoothie"))
            search.searchField.typeText("\n")
            multiAdd.tap(multiAdd.review)
        }

        when("the salad's portion is doubled in the editor and the batch is logged") {
            multiAdd.tap(multiAdd.item(named: "House Salad"))
            multiAdd.tap(multiAdd.editorQuickGrams(360))
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
            XCTAssertTrue(today.calorieRing.awaitLabel(containing: ", 312 eaten"))
        }
    }

    func testGivenAddFoodWhenTheBarcodeScannerIsOpenedAndClosedThenAddFoodReturnsEachTime() {
        XCUIApplication().resetAuthorizationStatus(for: .camera)
        let app = launch(fixture: .profileOnly)
        let today = TodayScreen(app: app)
        let search = FoodSearchScreen(app: app)
        let scanner = BarcodeScannerScreen(app: app)
        addUIInterruptionMonitor(withDescription: "Camera access") { alert in
            alert.buttons["Allow"].tap()
            return true
        }

        given("Add Food is open") {
            today.tap(today.mealHeader("breakfast"))
        }

        for moment in ["while camera access is being asked for", "once camera access is decided"] {
            when("the scanner is opened and closed \(moment)") {
                search.tap(search.scan)
                scanner.tap(scanner.close)
            }

            then("Add Food is back and can open the scanner again") {
                search.awaitTappable(search.scan)
            }
        }
    }

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

    func testGivenAnEntryWhoseFoodWasDeletedWhenItsPortionIsEditedThenTodayRecountsIt() {
        let app = launch(fixture: .overBudgetDay)
        let today = TodayScreen(app: app)
        let editor = MissingFoodEntryScreen(app: app)
        let wine = today.entry(named: "Red wine")

        given("the red wine, logged at 250g from a food that no longer exists") {
            XCTAssertTrue(today.isVisible)
            today.revealTowardBottom(wine)
            XCTAssertTrue(wine.label.contains(", 170 kcal"), "Unexpected starting row: \(wine.label)")
        }

        when("the user opens it and changes the portion to 100g") {
            today.tap(wine)
            retype("100", into: editor.portion, atTrailingOffset: 0.88)
            editor.tap(editor.save)
        }

        then("Today recounts the entry from its own snapshot") {
            XCTAssertTrue(today.revealTowardBottom(wine).awaitLabel(containing: ", 68 kcal"))
        }
    }

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

    func testGivenTheReminderIsOffWhenItIsTurnedOnThenItsTimeCanBeChosenUntilItIsTurnedOff() {
        let app = launch(fixture: .profileOnly)
        let tabs = TabBar(app: app)
        let reminder = DailyReminderScreen(app: app)

        given("Settings with the reminder off") {
            XCTAssertTrue(tabs.isVisible)
            tabs.go(to: .settings)
            scroll(to: reminder.toggle, in: app)
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

    private func retype(_ text: String, into field: XCUIElement, atTrailingOffset offset: CGFloat = 0.97) {
        let hittable = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: field)
        XCTAssertEqual(XCTWaiter().wait(for: [hittable], timeout: UITestCase.defaultTimeout), .completed, "\(field) never became tappable")
        field.coordinate(withNormalizedOffset: CGVector(dx: offset, dy: 0.5)).tap()
        let existing = (field.value as? String)?.count ?? 0
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing + 2))
        field.typeText(text)
    }

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
