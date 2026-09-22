import XCTest

final class RingInteractionTests: UITestCase {
    func testOpeningDismissingAndReopeningTheRingDetailsDoesNotDuplicateTheSheet() {
        let app = launch(fixture: .loggedDay)
        let today = TodayScreen(app: app)
        let details = NutritionDetailsScreen(app: app)

        XCTAssertTrue(today.calorieRing.awaitExistence())

        today.tap(today.calorieRing)
        XCTAssertTrue(details.title.awaitExistence(), "The first ring tap should open nutrition details")
        XCTAssertEqual(
            app.descendants(matching: .any).matching(identifier: "nutritionDetails.title").count,
            1,
            "The details sheet should have one title"
        )

        today.tap(
            app.descendants(matching: .any)
                .matching(identifier: "nutritionDetails.close")
                .firstMatch
        )
        let dismissed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: details.title
        )
        XCTAssertEqual(
            XCTWaiter().wait(for: [dismissed], timeout: UITestCase.defaultTimeout),
            .completed,
            "Dismissing the sheet should remove its content"
        )

        today.tap(today.calorieRing)
        XCTAssertTrue(details.title.awaitExistence(), "The ring should reopen nutrition details")
        XCTAssertEqual(
            app.descendants(matching: .any).matching(identifier: "nutritionDetails.title").count,
            1,
            "Reopening should not leave a duplicate details sheet"
        )
    }
}
