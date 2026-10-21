import XCTest

final class BarcodeLookupUITests: UITestCase {
    func testGivenAKnownBarcodeWhenItIsScannedThenThePortionOpens() {
        let app = launchLookup(barcode: "3017620422003", fixture: "barcode-lookup-found")
        let today = TodayScreen(app: app)
        let search = FoodSearchScreen(app: app)
        let portion = PortionPickerScreen(app: app)

        given("breakfast's add-food sheet") {
            today.tap(today.mealHeader("breakfast"))
            search.awaitTappable(search.searchField)
        }

        when("the barcode is scanned") {
            search.tap(search.scan)
        }

        then("the portion for the fixture food is ready") {
            XCTAssertTrue(portion.save.awaitExistence())
            XCTAssertTrue(fixtureFood(in: app).awaitExistence())
        }
    }

    func testGivenASlowLookupWhenTheScannerIsCancelledThenSearchReturnsWithoutAFailure() {
        let app = launchLookup(barcode: "3017620422003", fixture: "barcode-lookup-unavailable")
        let today = TodayScreen(app: app)
        let search = FoodSearchScreen(app: app)

        given("a lookup holding the scanner") {
            today.tap(today.mealHeader("breakfast"))
            search.tap(search.scan)
            XCTAssertTrue(lookupProgress(in: app).awaitExistence())
        }

        when("the scanner lookup is cancelled") {
            search.tap(app.buttons["Cancel lookup"])
        }

        then("search is back and the failure never appears") {
            search.awaitTappable(search.searchField)
            XCTAssertFalse(lookupProgress(in: app).exists)
            assertFailureStaysHidden(in: app)
        }
    }

    func testGivenAFailedLookupWhenTheRetryIsCancelledThenSearchReturns() {
        let app = launchLookup(barcode: "3017620422003", fixture: "barcode-lookup-unavailable")
        let today = TodayScreen(app: app)
        let search = FoodSearchScreen(app: app)
        let failure = app.staticTexts["Food search unavailable"]

        given("a barcode lookup that could not reach the catalog") {
            today.tap(today.mealHeader("breakfast"))
            search.tap(search.scan)
            XCTAssertTrue(failure.awaitExistence(timeout: 10))
        }

        when("retry is cancelled from the search sheet") {
            search.tap(app.buttons["Try again"])
            search.tap(search.element("barcodeLookup.cancel"))
        }

        then("the failure is gone and search is usable") {
            search.awaitTappable(search.searchField)
            XCTAssertFalse(lookupProgress(in: app).exists)
            XCTAssertFalse(failure.exists)
            assertFailureStaysHidden(in: app)
        }
    }

    private func launchLookup(barcode: String, fixture: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest-reset", "-uitest-seed", Fixture.profileOnly.rawValue]
        app.launchEnvironment["CALORYN_UITEST_BARCODE"] = barcode
        app.launchEnvironment["CALORYN_LOOKUP_FIXTURE"] = fixture
        app.launch()
        self.app = app
        return app
    }

    private func lookupProgress(in app: XCUIApplication) -> XCUIElement {
        FoodSearchScreen(app: app).element("barcodeLookup.progress")
    }

    private func fixtureFood(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Fixture Bar"))
            .firstMatch
    }

    private func assertFailureStaysHidden(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let failure = app.staticTexts["Food search unavailable"]
        let appeared = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true"),
            object: failure
        )
        let result = XCTWaiter().wait(for: [appeared], timeout: 3)
        XCTAssertNotEqual(
            result,
            .completed,
            "Cancelling the lookup should not leave a failure on the search sheet",
            file: file,
            line: line
        )
    }
}
