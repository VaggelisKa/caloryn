import XCTest

class UITestCase: XCTestCase {
    var app: XCUIApplication!

    static let defaultTimeout: TimeInterval = 10

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    @discardableResult
    func launch(fixture: Fixture) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest-reset", "-uitest-seed", fixture.rawValue]
        app.launch()
        self.app = app
        return app
    }

    enum Fixture: String {
        case empty
        case profileOnly
        case loggedDay
        case loggedYesterday
        case customFoods
        case history
        case historyPattern
        case historyNoPattern
        case overBudgetDay
    }
}

extension XCTestCase {
    func given(_ description: String, _ body: () throws -> Void) rethrows {
        try XCTContext.runActivity(named: "Given \(description)") { _ in try body() }
    }

    func when(_ description: String, _ body: () throws -> Void) rethrows {
        try XCTContext.runActivity(named: "When \(description)") { _ in try body() }
    }

    func then(_ description: String, _ body: () throws -> Void) rethrows {
        try XCTContext.runActivity(named: "Then \(description)") { _ in try body() }
    }
}

extension XCUIElement {
    @discardableResult
    func awaitExistence(
        timeout: TimeInterval = UITestCase.defaultTimeout,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        let found = waitForExistence(timeout: timeout)
        if !found {
            XCTFail("Timed out after \(timeout)s waiting for \(self)", file: file, line: line)
        }
        return found
    }
}
