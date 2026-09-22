import XCTest

final class TodayDataFlowTests: UITestCase {
    func testYesterdayCanBeViewedAndCopiedIntoToday() {
        let app = launch(fixture: .loggedYesterday)
        let today = TodayScreen(app: app)
        let portion = PortionPickerScreen(app: app)

        XCTAssertTrue(today.isVisible)
        XCTAssertFalse(today.entry(named: "Rolled Oats").exists)
        XCTAssertTrue(today.revealTowardBottom(today.copyYesterday).isHittable)

        today.tap(today.previousDay)
        XCTAssertTrue(today.entry(named: "Rolled Oats").awaitExistence())

        today.tap(today.nextDay)
        today.tap(today.revealTowardBottom(today.copyYesterday))

        let copiedEntry = today.revealTowardTop(today.entry(named: "Rolled Oats"))
        XCTAssertTrue(
            copiedEntry.isHittable,
            "The copied entry should appear without reopening Today"
        )
        XCTAssertFalse(today.copyYesterday.exists, "Copying should no longer be offered for a non-empty day")

        today.tap(copiedEntry)
        portion.typeGrams(50)
        XCTAssertTrue(portion.awaitCalories(190))
        today.tap(portion.save)

        let editedEntry = today.entry(named: "Rolled Oats")
        XCTAssertTrue(editedEntry.awaitExistence(), "The edited copy should remain visible without reopening Today")
        today.tap(editedEntry)
        XCTAssertTrue(portion.awaitCalories(190), "The edited portion should be read back from the live query")
        today.tap(portion.delete)
        today.tap(app.buttons["Delete"].firstMatch)

        let gone = NSPredicate(format: "exists == false")
        let deletion = XCTNSPredicateExpectation(predicate: gone, object: editedEntry)
        XCTAssertEqual(
            XCTWaiter().wait(for: [deletion], timeout: Self.defaultTimeout),
            .completed,
            "The deleted copy should leave Today without reopening the screen"
        )
        XCTAssertTrue(
            today.revealTowardBottom(today.copyYesterday).isHittable,
            "Deleting the copy should make yesterday available again"
        )
    }
}
