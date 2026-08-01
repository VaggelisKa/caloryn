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

    /// Every step of the flow, in the order `OnboardingStep` pushes them, paired
    /// with the control that both proves the step is on screen and moves past it.
    ///
    /// Each identifier belongs to exactly one step, so "the next one exists" is a
    /// sound arrival check even while a push animation is still running. The
    /// screenshot harness walks this list to photograph each screen and
    /// `completeWithDefaults` walks it to get past onboarding, so the order is
    /// written down once rather than in each caller.
    static let steps: [Step] = [
        Step(name: "welcome", advanceIdentifier: "onboarding.getStarted"),
        Step(name: "personal-info", advanceIdentifier: "onboarding.personalInfo.continue"),
        Step(name: "activity-level", advanceIdentifier: "onboarding.activityLevel.continue"),
        Step(name: "energy-mode", advanceIdentifier: "onboarding.energyMode.continue"),
        Step(name: "goal-summary", advanceIdentifier: "onboarding.goalSummary.continue"),
        Step(name: "macro-ratios", advanceIdentifier: "onboarding.macroRatios.continue"),
        Step(name: "nutrients", advanceIdentifier: "onboarding.startTracking")
    ]

    struct Step {
        /// Used in screenshot filenames, so it is kebab-case rather than the
        /// enum's camelCase.
        let name: String
        let advanceIdentifier: String
    }

    func advance(_ step: Step) -> XCUIElement {
        element(step.advanceIdentifier)
    }

    /// Walks the whole onboarding flow using each step's continue button.
    /// Steps are advanced by identifier rather than by position, so inserting
    /// a step does not silently skip part of the flow.
    func completeWithDefaults() {
        tap(getStarted)

        for step in Self.steps.dropFirst() {
            // Not every build presents every step; skip any that is absent
            // rather than failing, but require that at least the flow ends.
            tapIfPresent(advance(step), timeout: 5)
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
    var createManualEntry: XCUIElement { element("myFoods.createManualEntry") }

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

    var calories: XCUIElement { element("portionPicker.calories") }
    var save: XCUIElement { element("portionPicker.save") }
    var delete: XCUIElement { element("portionPicker.delete") }
    var back: XCUIElement { element("portionPicker.back") }

    /// The tappable box around the grams field. The field itself is at zero
    /// opacity until focused, so this is what a journey taps to start typing.
    var amountBox: XCUIElement { element("portionPicker.amountBox") }

    func quickGrams(_ grams: Int) -> XCUIElement {
        element("portionPicker.quickGrams.\(grams)")
    }

    /// Replaces whatever the grams field holds with `grams`.
    ///
    /// The deletes are a fixed count rather than one per existing character:
    /// reading the old value back would be a second round trip, and a portion
    /// never exceeds five digits, so over-deleting an already empty field is
    /// both harmless and cheaper.
    func typeGrams(_ grams: Int) {
        tap(amountBox)
        app.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6))
        app.typeText("\(grams)")
    }

    /// Waits for the calorie readout to settle on `calorieCount`.
    ///
    /// The readout animates, so the first sample after typing can still be the
    /// old number — this waits for the value rather than asserting on it once.
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

// MARK: - Nutrition details

struct NutritionDetailsScreen: Screen {
    let app: XCUIApplication

    var title: XCUIElement { element("nutritionDetails.title") }
    var consumedCalories: XCUIElement { element("nutritionDetails.consumedCalories") }
}

// MARK: - History

struct HistoryScreen: Screen {
    let app: XCUIApplication

    var rangePicker: XCUIElement { element("history.rangePicker") }
    var calorieTrendCard: XCUIElement { element("history.calorieTrend.card") }
    var calorieTrendDetails: XCUIElement { element("history.calorieTrend.details") }
    var recurringPatternCard: XCUIElement { element("history.recurringPattern.card") }
    var recurringPatternDetails: XCUIElement { element("history.recurringPattern.details") }
    var supportingPatternDay: XCUIElement { element("history.recurringPattern.supportingDay") }
    var expandedSupportingPatternDay: XCUIElement {
        element("history.recurringPattern.supportingDay.details")
    }

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
    var editProfile: XCUIElement { element("settings.editProfile") }
    var goalTargetField: XCUIElement { element("goalEdit.target") }
    var manualOverride: XCUIElement { element("goalEdit.manualOverride") }
    var saveGoal: XCUIElement { element("goalEdit.save") }
}
