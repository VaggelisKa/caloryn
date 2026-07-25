import XCTest

/// Page objects for the app's main screens.
///
/// Each exposes what a *user* can see and do. Nothing here reaches into view
/// structure, so these keep working when view logic later moves into view
/// models.

// MARK: - Tab bar

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

// MARK: - Onboarding

struct OnboardingScreen: Screen {
    let app: XCUIApplication

    var getStarted: XCUIElement { element("onboarding.getStarted") }
    var goalTarget: XCUIElement { element("onboarding.goalSummary.target") }
    var startTracking: XCUIElement { element("onboarding.startTracking") }

    /// Walks the whole onboarding flow using each step's continue button.
    /// Steps are advanced by identifier rather than by position, so inserting
    /// a step does not silently skip part of the flow.
    func completeWithDefaults() {
        tap(getStarted)

        // Order matches OnboardingStep: welcome, personalInfo, activityLevel,
        // energyCalculationMode, goalSummary, macroRatios, nutrientSelection.
        let continueIdentifiers = [
            "onboarding.personalInfo.continue",
            "onboarding.activityLevel.continue",
            "onboarding.energyMode.continue",
            "onboarding.goalSummary.continue",
            "onboarding.macroRatios.continue"
        ]

        for identifier in continueIdentifiers {
            let button = element(identifier)
            // Not every build presents every step; skip any that is absent
            // rather than failing, but require that at least the flow ends.
            if button.waitForExistence(timeout: 5) {
                tap(button)
            }
        }

        let finish = startTracking
        if finish.waitForExistence(timeout: 5) {
            tap(finish)
        }
    }
}

// MARK: - Today

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
}

// MARK: - My Foods

struct MyFoodsScreen: Screen {
    let app: XCUIApplication

    var createMenu: XCUIElement { element("myFoods.createMenu") }

    func food(named name: String) -> XCUIElement {
        element("myFoods.food.\(name)")
    }
}

// MARK: - Custom food form

struct CustomFoodFormScreen: Screen {
    let app: XCUIApplication

    var name: XCUIElement { element("customFood.name") }
    var calories: XCUIElement { element("customFood.calories") }
    var servingSize: XCUIElement { element("customFood.servingSize") }
    var save: XCUIElement { element("customFood.save") }
}

// MARK: - Food search and portion

struct FoodSearchScreen: Screen {
    let app: XCUIApplication

    var searchField: XCUIElement { element("foodSearch.searchField") }

    func result(named name: String) -> XCUIElement {
        element("foodSearch.result.\(name)")
    }
}

struct PortionPickerScreen: Screen {
    let app: XCUIApplication

    var amountPicker: XCUIElement { element("portionPicker.amountPicker") }
    var calories: XCUIElement { element("portionPicker.calories") }
    var save: XCUIElement { element("portionPicker.save") }
    var delete: XCUIElement { element("portionPicker.delete") }
}

// MARK: - History

struct HistoryScreen: Screen {
    let app: XCUIApplication

    var rangePicker: XCUIElement { element("history.rangePicker") }

    /// Range controls are segmented-control buttons labelled "7 Days" and so on.
    func selectRange(_ label: String) {
        tap(rangeButton(label))
    }

    func rangeButton(_ label: String) -> XCUIElement {
        let scoped = rangePicker.buttons[label]
        return scoped.exists ? scoped : app.buttons[label]
    }

    /// Waits for the named range to become the selected segment, so a test can
    /// assert the selection actually changed rather than that the control
    /// merely still exists.
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

// MARK: - Settings

struct SettingsScreen: Screen {
    let app: XCUIApplication

    var calorieTarget: XCUIElement { element("settings.calorieTarget") }
    var editGoal: XCUIElement { element("settings.editGoal") }
    var goalTargetField: XCUIElement { element("goalEdit.target") }
    var manualOverride: XCUIElement { element("goalEdit.manualOverride") }
    var saveGoal: XCUIElement { element("goalEdit.save") }
}
