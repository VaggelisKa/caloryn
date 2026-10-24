import XCTest

struct TabBar: Screen {
    let app: XCUIApplication

    enum Destination: String {
        case today = "Today"
        case myFoods = "My Foods"
        case history = "History"
        case settings = "Settings"
    }

    @discardableResult
    func go(to destination: Destination) -> Self {
        let tab = app.tabBars.buttons[destination.rawValue]
        tap(tab)
        return self
    }

    var isVisible: Bool {
        app.tabBars.firstMatch.waitForExistence(timeout: UITestCase.defaultTimeout)
    }
}

struct OnboardingScreen: Screen {
    let app: XCUIApplication

    var getStarted: XCUIElement { element("onboarding.getStarted") }
    var startTracking: XCUIElement { element("onboarding.startTracking") }
    var setManually: XCUIElement { element("onboarding.goalSummary.setManually") }
    var manualCalorieTarget: XCUIElement { element("onboarding.goalSummary.manualTarget") }
    var proteinGoal: XCUIElement { element("onboarding.macroGrams.protein") }
    var carbGoal: XCUIElement { element("onboarding.macroGrams.carbs") }
    var fatGoal: XCUIElement { element("onboarding.macroGrams.fat") }
    var macroAccount: XCUIElement { element("onboarding.macroGrams.account") }

    func activityLevel(_ level: String) -> XCUIElement {
        element("onboarding.activityLevel.option.\(level)")
    }

    static let steps: [Step] = [
        Step(name: "welcome", advanceIdentifier: "onboarding.getStarted"),
        Step(name: "personal-info", advanceIdentifier: "onboarding.personalInfo.continue"),
        Step(name: "activity-level", advanceIdentifier: "onboarding.activityLevel.continue"),
        Step(name: "goal-summary", advanceIdentifier: "onboarding.goalSummary.continue"),
        Step(name: "macro-ratios", advanceIdentifier: "onboarding.macroRatios.continue"),
        Step(name: "nutrients", advanceIdentifier: "onboarding.startTracking")
    ]

    struct Step {
        let name: String
        let advanceIdentifier: String
    }

    func advance(_ step: Step) -> XCUIElement {
        element(step.advanceIdentifier)
    }

    func completeWithDefaults() {
        tap(getStarted)

        for step in Self.steps.dropFirst() {
            tapIfPresent(advance(step), timeout: 5)
        }
    }
}

struct TodayScreen: Screen {
    let app: XCUIApplication

    var calorieRing: XCUIElement { element("today.calorieRing") }
    var copyYesterday: XCUIElement { element("today.copyYesterday") }
    var previousDay: XCUIElement { element("today.previousDay") }
    var nextDay: XCUIElement { element("today.nextDay") }

    func entry(named name: String) -> XCUIElement {
        element("today.entry.\(name)")
    }

    func mealHeader(_ meal: String) -> XCUIElement {
        element("today.mealHeader.\(meal)")
    }

    var isVisible: Bool {
        calorieRing.waitForExistence(timeout: UITestCase.defaultTimeout)
    }

    @discardableResult
    func revealTowardBottom(
        _ element: XCUIElement,
        maximumScrolls: Int = 6,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        reveal(element, maximumScrolls: maximumScrolls, swipe: app.swipeUp, file: file, line: line)
    }

    @discardableResult
    func revealTowardTop(
        _ element: XCUIElement,
        maximumScrolls: Int = 6,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        reveal(element, maximumScrolls: maximumScrolls, swipe: app.swipeDown, file: file, line: line)
    }

    private func reveal(
        _ element: XCUIElement,
        maximumScrolls: Int,
        swipe: () -> Void,
        file: StaticString,
        line: UInt
    ) -> XCUIElement {
        var scrolls = 0
        while !(element.exists && element.isHittable), scrolls < maximumScrolls {
            swipe()
            scrolls += 1
        }
        if !(element.exists && element.isHittable) {
            XCTFail("Never scrolled to \(element)", file: file, line: line)
        }
        return element
    }
}

struct MyFoodsScreen: Screen {
    let app: XCUIApplication

    var createMenu: XCUIElement { element("myFoods.createMenu") }
    var createManualEntry: XCUIElement { element("myFoods.createManualEntry") }

    func food(named name: String) -> XCUIElement {
        element("myFoods.food.\(name)")
    }
}

struct CustomFoodFormScreen: Screen {
    let app: XCUIApplication

    var name: XCUIElement { element("customFood.name") }
    var calories: XCUIElement { element("customFood.calories") }
    var servingSize: XCUIElement { element("customFood.servingSize") }
    var save: XCUIElement { element("customFood.save") }
}

struct FoodSearchScreen: Screen {
    let app: XCUIApplication

    var searchField: XCUIElement { element("foodSearch.searchField") }
    var scan: XCUIElement { element("foodSearch.scanBarcode") }
    var close: XCUIElement { element("foodSearch.close") }

    func result(named name: String) -> XCUIElement {
        element("foodSearch.result.\(name)")
    }
}

struct PastedFoodScreen: Screen {
    let app: XCUIApplication

    var paste: XCUIElement { element("foodSearch.pasteLink") }
    var copyInstructions: XCUIElement { element("foodSearch.copyChatbotInstructions") }

    var name: XCUIElement { element("pastedFood.name") }
    var calories: XCUIElement { element("pastedFood.calories") }
    var protein: XCUIElement { element("pastedFood.protein") }
    var carbs: XCUIElement { element("pastedFood.carbs") }
    var fat: XCUIElement { element("pastedFood.fat") }
    var meal: XCUIElement { element("pastedFood.meal") }
    var grams: XCUIElement { element("pastedFood.grams") }
    var addBlockedReason: XCUIElement { element("pastedFood.addBlockedReason") }
    var add: XCUIElement { element("pastedFood.add") }
    var disabledAdd: XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ AND isEnabled == false", "pastedFood.add"))
            .firstMatch
    }
    var cancel: XCUIElement { element("pastedFood.cancel") }
    var addAgain: XCUIElement { element("pastedFood.alreadyLogged.addAgain") }
    var keepSingle: XCUIElement { element("pastedFood.alreadyLogged.cancel") }
    var dismissRejection: XCUIElement { element("foodSearch.pasteRejection.ok") }

    func text(containing substring: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", substring))
            .firstMatch
    }
}

struct BarcodeScannerScreen: Screen {
    let app: XCUIApplication

    var close: XCUIElement { element("barcodeScanner.close") }
}

struct PortionPickerScreen: Screen {
    let app: XCUIApplication

    var calories: XCUIElement { element("portionPicker.calories") }
    var save: XCUIElement { element("portionPicker.save") }
    var delete: XCUIElement { element("portionPicker.delete") }
    var back: XCUIElement { element("portionPicker.back") }

    var amountBox: XCUIElement { element("portionPicker.amountBox") }

    func quickGrams(_ grams: Int) -> XCUIElement {
        element("portionPicker.quickGrams.\(grams)")
    }

    func typeGrams(_ grams: Int) {
        tap(amountBox)
        app.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6))
        app.typeText("\(grams)")
    }

    @discardableResult
    func awaitCalories(
        _ calorieCount: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        let matches = NSPredicate(format: "label == %@", "\(calorieCount)")
        let expectation = XCTNSPredicateExpectation(predicate: matches, object: calories)
        let settled = XCTWaiter().wait(for: [expectation], timeout: UITestCase.defaultTimeout) == .completed
        if !settled {
            XCTFail(
                "Calorie preview showed \(calories.label) rather than \(calorieCount)",
                file: file,
                line: line
            )
        }
        return settled
    }
}

struct NutritionDetailsScreen: Screen {
    let app: XCUIApplication

    var title: XCUIElement { element("nutritionDetails.title") }
    var consumedCalories: XCUIElement { element("nutritionDetails.consumedCalories") }
}

struct HistoryScreen: Screen {
    let app: XCUIApplication

    var rangePicker: XCUIElement { element("history.rangePicker") }
    var averageCalories: XCUIElement { element("history.goalSummary.metric.kcal/day-avg") }
    var calorieTrendCard: XCUIElement { element("history.calorieTrend.card") }
    var calorieTrendDetails: XCUIElement { element("history.calorieTrend.details") }
    var recurringPatternCard: XCUIElement { element("history.recurringPattern.card") }
    var recurringPatternDetails: XCUIElement { element("history.recurringPattern.details") }
    var supportingPatternDay: XCUIElement { element("history.recurringPattern.supportingDay") }
    var expandedSupportingPatternDay: XCUIElement {
        element("history.recurringPattern.supportingDay.details")
    }

    func selectRange(_ label: String) {
        tap(rangeButton(label))
    }

    func rangeButton(_ label: String) -> XCUIElement {
        let scoped = rangePicker.buttons[label]
        return scoped.exists ? scoped : app.buttons[label]
    }

    @discardableResult
    func awaitRangeSelected(
        _ label: String,
        timeout: TimeInterval = UITestCase.defaultTimeout,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        let selected = NSPredicate(format: "isSelected == true")
        let expectation = XCTNSPredicateExpectation(predicate: selected, object: rangeButton(label))
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        if result != .completed {
            XCTFail("The \(label) range never became the selected segment", file: file, line: line)
        }
        return result == .completed
    }
}

struct SettingsScreen: Screen {
    let app: XCUIApplication

    var calorieTarget: XCUIElement { element("settings.calorieTarget") }
    var editGoal: XCUIElement { element("settings.editGoal") }
    var editProfile: XCUIElement { element("settings.editProfile") }
    var goalTargetField: XCUIElement { element("goalEdit.target") }
    var manualOverride: XCUIElement { element("goalEdit.manualOverride") }
    var saveGoal: XCUIElement { element("goalEdit.save") }
    var proteinGoal: XCUIElement { element("goalEdit.protein") }
    var carbGoal: XCUIElement { element("goalEdit.carbs") }
    var fatGoal: XCUIElement { element("goalEdit.fat") }
    var macroAccount: XCUIElement { element("goalEdit.macroAccount") }

    var export: XCUIElement { element("settings.export") }

    @discardableResult
    func revealExport(
        maximumScrolls: Int = 6,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        var scrolls = 0
        while !(export.exists && export.isHittable), scrolls < maximumScrolls {
            app.swipeUp()
            scrolls += 1
        }
        if !(export.exists && export.isHittable) {
            XCTFail("Never scrolled to \(export)", file: file, line: line)
        }
        return export
    }
}

struct MultiAddScreen: Screen {
    let app: XCUIApplication

    var selectMultiple: XCUIElement { element("foodSearch.selectMultiple") }
    var review: XCUIElement { element("multiAdd.review") }
    var commit: XCUIElement { element("multiAdd.commit") }
    var editorSave: XCUIElement { element("multiAdd.editor.save") }
    var editorCalories: XCUIElement { element("multiAdd.editor.calories") }

    func item(named name: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(
                format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                "multiAdd.item.",
                name
            ))
            .firstMatch
    }

    func editorQuickGrams(_ grams: Int) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(
                format: "identifier == %@ AND label == %@",
                "multiAdd.editor.portion",
                "\(grams) grams"
            ))
            .firstMatch
    }
}

struct CreationFormScreen: Screen {
    let app: XCUIApplication

    var createRecipe: XCUIElement { element("myFoods.createRecipe") }
    var createMeal: XCUIElement { element("myFoods.createMeal") }

    var recipeName: XCUIElement { element("recipe.name") }
    var addIngredient: XCUIElement { element("recipe.addIngredient") }
    var saveRecipe: XCUIElement { element("recipe.save") }

    var mealName: XCUIElement { element("meal.name") }
    var addMealItem: XCUIElement { element("meal.addItem") }
    var saveMeal: XCUIElement { element("meal.save") }

    var amountGrams: XCUIElement { element("ingredientAmount.grams") }
    var amountCalories: XCUIElement { element("ingredientAmount.calories") }
    var saveAmount: XCUIElement { element("ingredientAmount.save") }

    func libraryMeal(named name: String) -> XCUIElement {
        element("myFoods.meal.\(name)")
    }

    var firstMealResult: XCUIElement { element(withIdentifierPrefix: "meal.select.") }
}

struct MissingFoodEntryScreen: Screen {
    let app: XCUIApplication

    var portion: XCUIElement { element("missingEntry.portion") }
    var save: XCUIElement { element("missingEntry.save") }
}

struct ProfileEditScreen: Screen {
    let app: XCUIApplication

    var age: XCUIElement { element("profileEdit.age") }
    var save: XCUIElement { element("profileEdit.save") }

    func sex(_ rawValue: String) -> XCUIElement {
        element("profileEdit.sex.\(rawValue)")
    }

    var settingsAge: XCUIElement { element("settings.profile.age") }
    var settingsSex: XCUIElement { element("settings.profile.sex") }
}

struct DailyReminderScreen: Screen {
    let app: XCUIApplication

    var toggle: XCUIElement { element("settings.dailyReminder.toggle") }
    var time: XCUIElement { element("settings.dailyReminder.time") }
    var timePicker: XCUIElement { element("settings.dailyReminder.timePicker") }
    var openSettings: XCUIElement { element("settings.dailyReminder.openSettings") }

    var isOn: Bool { (toggle.value as? String) == "1" }

    func flip() {
        awaitTappable(toggle)
            .coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5))
            .tap()
    }
}
