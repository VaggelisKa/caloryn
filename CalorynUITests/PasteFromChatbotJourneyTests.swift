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

    func testGivenTextWithoutALinkWhenItIsPastedThenTheReasonIsShownAndNothingIsLogged() {
        let app = launch(fixture: .profileOnly)
        let today = TodayScreen(app: app)
        let search = FoodSearchScreen(app: app)
        let pasted = PastedFoodScreen(app: app)

        given("a chatbot reply without a Caloryn link on the pasteboard") {
            UIPasteboard.general.string = "Greek yogurt, about 150 kcal and 15 g protein."
            today.tap(today.mealHeader("lunch"))
        }

        when("the user pastes it") {
            pasted.tap(pasted.paste)
        }

        then("the rejection explains itself and no confirmation opens") {
            XCTAssertTrue(pasted.text(containing: "No Caloryn link found").awaitExistence())
            search.tap(pasted.dismissRejection)
            XCTAssertFalse(pasted.add.exists, "A rejected paste must not open the confirmation")
        }

        then("nothing is logged") {
            search.tap(search.close)
            XCTAssertTrue(today.mealHeader("lunch").awaitExistence())
            XCTAssertFalse(today.entry(named: "Greek yogurt").exists)
        }
    }

    func testGivenCopiedChatbotInstructionsWhenTheyArePastedBackThenNothingIsLogged() {
        let app = launch(fixture: .profileOnly)
        let today = TodayScreen(app: app)
        let search = FoodSearchScreen(app: app)
        let pasted = PastedFoodScreen(app: app)

        given("an empty pasteboard and the add-food sheet") {
            UIPasteboard.general.string = ""
            today.tap(today.mealHeader("breakfast"))
        }

        when("the user copies the chatbot instructions and pastes them straight back") {
            pasted.tap(pasted.copyInstructions)
            XCTAssertTrue(pasted.copyInstructions.awaitLabel(containing: "Instructions copied"))
            pasted.tap(pasted.paste)
        }

        then("the instructions reached the pasteboard and are refused as more than one food") {
            XCTAssertTrue(pasted.text(containing: "more than one Caloryn link").awaitExistence())
            search.tap(pasted.dismissRejection)
            XCTAssertFalse(pasted.add.exists, "The example in the instructions must not be loggable by accident")
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
}
