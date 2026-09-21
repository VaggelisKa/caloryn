import XCTest

final class AdaptiveSummaryTests: UITestCase {
    func testAccessibilityXXXLKeepsTodayAndHistorySummariesWithinTheScreen() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-uitest-reset",
            "-uitest-seed", Fixture.history.rawValue,
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        app.launch()
        self.app = app

        let window = app.windows.firstMatch
        let calorieSummary = TodayScreen(app: app).calorieRing
        XCTAssertTrue(calorieSummary.awaitExistence())
        XCTAssertTrue(calorieSummary.isHittable, "The large-text calorie summary should remain available")
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
