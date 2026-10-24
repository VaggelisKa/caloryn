import UIKit
import XCTest

final class PasteFromChatbotJourneyTests: UITestCase {
    private static let chatbotReply = """
        Here’s your entry:

        ```
        caloryn://log?v=1&name=Greek%20yogurt&kcal=150&grams=170&protein=15&fat=4
        ```
        """

    override func tearDown() {
        UIPasteboard.general.string = ""
        super.tearDown()
    }

    func testGivenAChatbotLinkWhenItIsPastedAndAddedThenTheFoodJoinsThatMeal() {
        let app = launch(fixture: .profileOnly)
        let today = TodayScreen(app: app)
        let pasted = PastedFoodScreen(app: app)

        given("a chatbot reply on the pasteboard and nothing logged") {
            UIPasteboard.general.string = Self.chatbotReply
            XCTAssertTrue(today.isVisible)
        }

        when("the user pastes it into lunch") {
            today.tap(today.mealHeader("lunch"))
            pasted.tap(pasted.paste)
        }

        then("the confirmation shows exactly what will be saved") {
            XCTAssertTrue(pasted.name.awaitLabel(containing: "Greek yogurt"))
            XCTAssertTrue(pasted.calories.label.contains("150 kcal"), pasted.calories.label)
            XCTAssertTrue(pasted.protein.label.contains("15 g"), pasted.protein.label)
            XCTAssertTrue(pasted.carbs.label.contains("Not provided"), pasted.carbs.label)
            XCTAssertTrue(pasted.fat.label.contains("4 g"), pasted.fat.label)
            XCTAssertTrue(pasted.meal.label.contains("Lunch"), pasted.meal.label)
            XCTAssertEqual(pasted.grams.value as? String, "170")
        }

        when("the user adds it") {
            pasted.tap(pasted.add)
        }

        then("the sheet closes and the food is logged under lunch") {
            let entry = today.entry(named: "Greek yogurt")
            today.awaitTappable(entry)
            let lunch = today.mealHeader("lunch").frame
            let snack = today.mealHeader("snack").frame
            XCTAssertGreaterThan(entry.frame.midY, lunch.maxY, "The entry should sit below the lunch header")
            XCTAssertLessThan(entry.frame.midY, snack.minY, "The entry should sit above the snack header")
        }
    }

    func testGivenAPastedLinkWhenTheUserCancelsThenNothingIsLogged() {
        let app = launch(fixture: .profileOnly)
        let today = TodayScreen(app: app)
        let search = FoodSearchScreen(app: app)
        let pasted = PastedFoodScreen(app: app)

        given("the confirmation for a pasted link") {
            UIPasteboard.general.string = Self.chatbotReply
            today.tap(today.mealHeader("lunch"))
            pasted.tap(pasted.paste)
            XCTAssertTrue(pasted.name.awaitLabel(containing: "Greek yogurt"))
        }

        when("the user cancels and closes the add-food sheet") {
            pasted.tap(pasted.cancel)
            search.tap(search.close)
        }

        then("Today has nothing logged") {
            XCTAssertTrue(today.mealHeader("lunch").awaitExistence())
            XCTAssertFalse(today.entry(named: "Greek yogurt").exists, "Cancel must not log the food")
        }
    }

    func testGivenALinkOnThePasteboardWhenTheSheetOpensThenPasteIsOfferedWithoutAPastePrompt() {
        let app = launch(fixture: .profileOnly)
        let today = TodayScreen(app: app)
        let pasted = PastedFoodScreen(app: app)

        given("a chatbot reply copied in another app") {
            UIPasteboard.general.string = Self.chatbotReply
            XCTAssertTrue(today.isVisible)
        }

        when("the user opens lunch's add-food sheet") {
            today.tap(today.mealHeader("lunch"))
        }

        then("Paste is offered and iOS never asks to paste") {
            pasted.awaitTappable(pasted.paste)
            XCTAssertTrue(
                staysAbsent(pastePrompt(in: app), pastePrompt(in: Self.springboard)),
                "Deciding whether to offer Paste must not read the pasteboard"
            )
            XCTAssertTrue(pasted.paste.isHittable, "The sheet should stay usable, with nothing over it")
        }
    }

    func testGivenTextWithoutALinkWhenTheSheetOpensThenPasteIsNotOffered() {
        let app = launch(fixture: .profileOnly)
        let today = TodayScreen(app: app)
        let search = FoodSearchScreen(app: app)
        let pasted = PastedFoodScreen(app: app)

        given("a chatbot reply without any link on the pasteboard") {
            UIPasteboard.general.string = "Greek yogurt, about 150 kcal and 15 g protein."
            XCTAssertTrue(today.isVisible)
        }

        when("the user opens lunch's add-food sheet") {
            today.tap(today.mealHeader("lunch"))
            search.awaitTappable(search.searchField)
        }

        then("Paste is not offered") {
            XCTAssertTrue(staysAbsent(pasted.paste), "Prose on the pasteboard should not offer Paste")
        }
    }

    func testGivenAWebLinkWhenItIsPastedThenItIsNotOfferedAgainUntilTheUserCopiesElsewhere() {
        let app = launch(fixture: .profileOnly)
        let today = TodayScreen(app: app)
        let search = FoodSearchScreen(app: app)
        let pasted = PastedFoodScreen(app: app)

        given("a web link on the pasteboard, which looks like any other link") {
            UIPasteboard.general.string = "https://example.com"
            today.tap(today.mealHeader("lunch"))
            pasted.awaitTappable(pasted.paste)
        }

        when("the user pastes it") {
            pasted.tap(pasted.paste)
        }

        then("the parser's reason is shown and Paste is withdrawn") {
            XCTAssertTrue(pasted.text(containing: "No Caloryn link found").awaitExistence())
            search.tap(pasted.dismissRejection)
            XCTAssertTrue(awaitAbsence(of: pasted.paste), "A refused pasteboard should stop offering Paste")
            XCTAssertFalse(pasted.add.exists, "A rejected paste must not open the confirmation")
        }

        then("reopening the sheet with the same pasteboard does not offer it again") {
            search.tap(search.close)
            today.tap(today.mealHeader("breakfast"))
            search.awaitTappable(search.searchField)
            XCTAssertTrue(staysAbsent(pasted.paste), "The refused link should not come back on the next sheet")
        }

        when("the user copies a chatbot reply in another app and comes back") {
            XCUIDevice.shared.press(.home)
            UIPasteboard.general.string = Self.chatbotReply
            app.activate()
        }

        then("Paste is offered again") {
            pasted.awaitTappable(pasted.paste)
        }
    }

    func testGivenInstructionsCopiedInSettingsWhenTheyArePastedBackThenTheyAreRefusedUntilCopiedAgain() {
        let app = launch(fixture: .profileOnly)
        let tabs = TabBar(app: app)
        let settings = SettingsScreen(app: app)
        let today = TodayScreen(app: app)
        let search = FoodSearchScreen(app: app)
        let pasted = PastedFoodScreen(app: app)

        given("an empty pasteboard") {
            UIPasteboard.general.string = ""
            XCTAssertTrue(tabs.isVisible)
        }

        when("the user copies the chatbot instructions in Settings") {
            tabs.go(to: .settings)
            settings.revealClearOfTabBar(settings.copyChatbotInstructions).tap()
            XCTAssertTrue(settings.copyChatbotInstructions.awaitLabel(containing: "Instructions copied"))
        }

        then("the add-food sheet offers to paste them, because they hold links") {
            tabs.go(to: .today)
            today.tap(today.mealHeader("breakfast"))
            pasted.awaitTappable(pasted.paste)
        }

        when("the user pastes them straight back") {
            pasted.tap(pasted.paste)
        }

        then("they are refused as more than one food and Paste is withdrawn") {
            XCTAssertTrue(pasted.text(containing: "more than one Caloryn link").awaitExistence())
            search.tap(pasted.dismissRejection)
            XCTAssertTrue(awaitAbsence(of: pasted.paste))
            XCTAssertFalse(pasted.add.exists, "The example in the instructions must not be loggable by accident")
        }

        when("the user copies them again in Settings") {
            search.tap(search.close)
            tabs.go(to: .settings)
            settings.revealClearOfTabBar(settings.copyChatbotInstructions).tap()
        }

        then("a copy made inside Caloryn is offered again") {
            tabs.go(to: .today)
            today.tap(today.mealHeader("breakfast"))
            pasted.awaitTappable(pasted.paste)
        }
    }

    func testGivenALinkWithoutGramsWhenThePortionIsTypedThenAddBecomesAvailable() {
        let app = launch(fixture: .profileOnly)
        let today = TodayScreen(app: app)
        let pasted = PastedFoodScreen(app: app)

        given("the confirmation for a link that carries no grams") {
            UIPasteboard.general.string = "caloryn://log?v=1&name=Banana&kcal=105&carbs=27"
            today.tap(today.mealHeader("snack"))
            pasted.tap(pasted.paste)
            XCTAssertTrue(pasted.addBlockedReason.awaitLabel(containing: "Enter the portion weight"))
        }

        then("Add is unavailable") {
            XCTAssertTrue(pasted.disabledAdd.exists, "Add must stay disabled without a portion")
        }

        when("the user types a portion lighter than the carbs it holds") {
            pasted.tap(pasted.grams)
            pasted.grams.typeText("20")
        }

        then("Add stays unavailable and says why") {
            XCTAssertTrue(pasted.addBlockedReason.awaitLabel(containing: "27 g of carbs"))
            XCTAssertTrue(pasted.disabledAdd.exists)
        }

        when("the user types a real portion and adds it") {
            pasted.grams.typeText("0")
            pasted.tap(pasted.add)
        }

        then("the food is logged") {
            XCTAssertTrue(today.entry(named: "Banana").awaitExistence())
        }
    }

    func testGivenTheSameFoodAlreadyLoggedWhenItIsAddedThenTheUserIsAskedFirst() {
        let app = launch(fixture: .loggedDay)
        let today = TodayScreen(app: app)
        let pasted = PastedFoodScreen(app: app)
        let alreadyLogged = pasted.text(containing: "already in your log")

        given("a day with Rolled Oats logged and the same food on the pasteboard") {
            XCTAssertTrue(today.entry(named: "Rolled Oats").awaitExistence())
            UIPasteboard.general.string = "caloryn://log?v=1&name=rolled%20oats&kcal=380&grams=100"
            today.tap(today.mealHeader("lunch"))
            pasted.tap(pasted.paste)
            XCTAssertTrue(pasted.name.awaitLabel(containing: "rolled oats"))
        }

        when("the user adds it and then declines the prompt") {
            pasted.tap(pasted.add)
            XCTAssertTrue(alreadyLogged.awaitExistence(), "Adding a duplicate should ask first")
            pasted.tap(pasted.keepSingle)
        }

        then("nothing is added and the confirmation stays open") {
            pasted.awaitTappable(pasted.add)
            XCTAssertFalse(alreadyLogged.exists)
        }

        when("the user adds it again and confirms") {
            pasted.tap(pasted.add)
            XCTAssertTrue(alreadyLogged.awaitExistence())
            pasted.tap(pasted.addAgain)
        }

        then("the food is logged a second time") {
            XCTAssertTrue(today.entry(named: "rolled oats").awaitExistence())
            XCTAssertTrue(today.entry(named: "Rolled Oats").exists, "The original entry should remain")
        }
    }

    private static let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    private static let quietPeriod: TimeInterval = 3

    private func pastePrompt(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Allow Paste"))
            .firstMatch
    }

    private func staysAbsent(_ elements: XCUIElement...) -> Bool {
        let appeared = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in elements.contains { $0.exists } },
            object: nil
        )
        return XCTWaiter().wait(for: [appeared], timeout: Self.quietPeriod) == .timedOut
    }

    private func awaitAbsence(of element: XCUIElement) -> Bool {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        return XCTWaiter().wait(for: [gone], timeout: UITestCase.defaultTimeout) == .completed
    }
}
