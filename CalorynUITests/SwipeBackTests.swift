import XCTest

final class SwipeBackTests: UITestCase {
    func testGivenAHistoryDetailWhenSwipedFromTheLeftEdgeThenHistoryReturns() {
        let app = launch(fixture: .history)
        let tabs = TabBar(app: app)
        let history = HistoryScreen(app: app)

        given("the calorie trend detail is open") {
            XCTAssertTrue(tabs.isVisible)
            tabs.go(to: .history)
            history.tap(history.calorieTrendCard)
            XCTAssertTrue(history.calorieTrendDetails.awaitExistence())
        }

        when("the user swipes back from the left edge") {
            app.swipeBackFromLeftEdge()
        }

        then("History is showing again") {
            XCTAssertTrue(
                history.calorieTrendCard.awaitExistence(),
                "Swiping back should return to History"
            )
            XCTAssertFalse(
                history.calorieTrendDetails.exists,
                "The detail screen should have been popped"
            )
        }
    }

    func testGivenAPatternDetailWhenSwipedFromTheLeftEdgeThenHistoryReturns() {
        let app = launch(fixture: .historyPattern)
        let tabs = TabBar(app: app)
        let history = HistoryScreen(app: app)

        given("the recurring pattern detail is open") {
            XCTAssertTrue(tabs.isVisible)
            tabs.go(to: .history)
            history.tap(history.recurringPatternCard)
            XCTAssertTrue(history.recurringPatternDetails.awaitExistence())
        }

        when("the user swipes back from the left edge") {
            app.swipeBackFromLeftEdge()
        }

        then("History is showing again") {
            XCTAssertTrue(
                history.recurringPatternCard.awaitExistence(),
                "Swiping back should return to History"
            )
            XCTAssertFalse(
                history.recurringPatternDetails.exists,
                "The detail screen should have been popped"
            )
        }
    }

    func testGivenAPortionPickerInASheetWhenSwipedFromTheLeftEdgeThenItStaysPut() {
        let app = launch(fixture: .customFoods)
        let today = TodayScreen(app: app)
        let search = FoodSearchScreen(app: app)
        let portion = PortionPickerScreen(app: app)

        given("a food has been picked from the search sheet") {
            XCTAssertTrue(today.isVisible)
            today.tap(today.mealHeader("breakfast"))
            search.awaitTappable(search.searchField)
            search.searchField.typeText("Smoothie")
            search.tap(search.result(named: "Morning Smoothie"))
            XCTAssertTrue(portion.save.awaitExistence())
        }

        when("the user swipes back from the left edge") {
            app.swipeBackFromLeftEdge()
        }

        then("the portion picker is still showing") {
            XCTAssertTrue(
                portion.save.exists,
                "A sheet's push should ignore the edge swipe rather than pop"
            )
        }

        then("the back button still pops it") {
            portion.tap(portion.back)
            XCTAssertTrue(
                search.searchField.awaitExistence(),
                "The tinted back button is what pops a screen pushed inside a sheet"
            )
        }
    }
}

extension XCUIApplication {
    func swipeBackFromLeftEdge() {
        let edge = coordinate(withNormalizedOffset: CGVector(dx: 0.0, dy: 0.5))
        let farSide = coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5))
        edge.press(
            forDuration: 0.05,
            thenDragTo: farSide,
            withVelocity: .slow,
            thenHoldForDuration: 0.1
        )
    }
}
