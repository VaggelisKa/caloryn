import XCTest

final class AdaptiveSummaryTests: UITestCase {
    func testXXXLKeepsTheTodayRingReadableAndInteractive() throws {
        let app = launch(fixture: .history, contentSizeCategory: "UICTContentSizeCategoryXXXL")
        let today = TodayScreen(app: app)
        let window = app.windows.firstMatch
        let calorieSummary = today.calorieRing

        XCTAssertTrue(calorieSummary.awaitExistence())
        XCTAssertTrue(calorieSummary.isHittable, "The large-text calorie ring should remain tappable")
        XCTAssertFalse(calorieSummary.label.isEmpty, "The ring should expose its calorie summary")
        let calorieValue = try XCTUnwrap(calorieSummary.value as? String)
        XCTAssertFalse(calorieValue.isEmpty, "The ring should expose its calorie values")
        assertFitsHorizontally(calorieSummary, in: window)

        today.tap(calorieSummary)
        XCTAssertTrue(
            NutritionDetailsScreen(app: app).title.awaitExistence(),
            "The large-text ring should still open nutrition details"
        )
        let closeButton = today.element("nutritionDetails.close")
        XCTAssertTrue(closeButton.awaitExistence(), "Nutrition details should provide a close button")
        today.tap(closeButton)
        XCTAssertTrue(calorieSummary.awaitExistence(), "Closing nutrition details should return to Today")
    }

    func testAccessibilityXXXLKeepsTodayAndHistorySummariesWithinTheScreen() throws {
        let app = launch(
            fixture: .history,
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )

        let window = app.windows.firstMatch
        let calorieSummary = TodayScreen(app: app).calorieRing
        XCTAssertTrue(calorieSummary.awaitExistence())
        XCTAssertTrue(calorieSummary.isHittable, "The large-text calorie summary should remain available")
        XCTAssertFalse(calorieSummary.label.isEmpty, "The summary should expose its calorie status")
        let calorieValue = try XCTUnwrap(calorieSummary.value as? String)
        XCTAssertFalse(calorieValue.isEmpty, "The summary should expose its calorie values")
        assertFitsHorizontally(calorieSummary, in: window)

        TabBar(app: app).go(to: .history)
        let goalSummary = app.descendants(matching: .any)["history.goalSummary.card"]
        XCTAssertTrue(goalSummary.awaitExistence())
        for _ in 0..<4 where goalSummary.frame.minY >= window.frame.maxY {
            app.swipeUp()
        }
        XCTAssertTrue(
            goalSummary.frame.intersects(window.frame),
            "The large-text goal summary should be reachable by scrolling"
        )
        assertFitsHorizontally(goalSummary, in: window)

        for identifier in [
            "history.goalSummary.metric.days-logged",
            "history.goalSummary.metric.kcal/day-avg",
            "history.goalSummary.metric.coverage"
        ] {
            let metric = app.descendants(matching: .any)[identifier]
            XCTAssertTrue(metric.awaitExistence(), "The large-text summary should show \(identifier)")
            XCTAssertFalse(metric.label.isEmpty, "The large-text metric should remain readable")
            assertFitsHorizontally(metric, in: window)
        }
    }

    private func launch(fixture: Fixture, contentSizeCategory: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-uitest-reset",
            "-uitest-seed", fixture.rawValue,
            "-UIPreferredContentSizeCategoryName", contentSizeCategory
        ]
        app.launch()
        self.app = app
        return app
    }

    private func assertFitsHorizontally(
        _ element: XCUIElement,
        in window: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let elementFrame = element.frame
        let windowFrame = window.frame
        XCTAssertGreaterThanOrEqual(elementFrame.minX, windowFrame.minX, file: file, line: line)
        XCTAssertLessThanOrEqual(elementFrame.maxX, windowFrame.maxX, file: file, line: line)
    }
}
