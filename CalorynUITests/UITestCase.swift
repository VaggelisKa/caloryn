import XCTest

/// Base class for Caloryn UI tests.
///
/// Every test launches the app with a named fixture so it never depends on
/// state left behind by an earlier test. Assertions in subclasses must describe
/// user-visible behavior, never view structure, so they survive refactoring.
class UITestCase: XCTestCase {
    var app: XCUIApplication!

    /// Default time to wait for a UI element before failing.
    static let defaultTimeout: TimeInterval = 10

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    /// Launches the app with a fresh in-memory store seeded with `fixture`.
    @discardableResult
    func launch(fixture: Fixture) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest-reset", "-uitest-seed", fixture.rawValue]
        app.launch()
        self.app = app
        return app
    }

    /// Mirrors `UITestConfiguration.Fixture` in the app target.
    enum Fixture: String {
        case empty
        case profileOnly
        case loggedDay
        case customFoods
        case history
    }
}

// MARK: - Given/When/Then

/// Lightweight structure so tests read as behavior specifications. These are
/// labels rather than machinery: no parser, no step registry, no dependency.
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

// MARK: - Waiting

extension XCUIElement {
    /// Waits for the element to exist, failing the test with a clear message.
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
