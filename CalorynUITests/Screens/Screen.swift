import XCTest

/// Shared plumbing for page objects.
///
/// Page objects expose the things a *user* can see and do on a screen. They
/// never reach into view structure, so they keep working when the app moves
/// logic out of views and into view models.
protocol Screen {
    var app: XCUIApplication { get }
}

extension Screen {
    /// Finds an element by accessibility identifier regardless of the element
    /// type SwiftUI happens to render it as. SwiftUI freely changes whether a
    /// control is reported as a button, a cell or a generic element, so tests
    /// must not encode that choice.
    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: identifier)
            .firstMatch
    }

    /// Finds the first element whose identifier starts with `prefix`. Used for
    /// rows whose identifier embeds a model UUID the test cannot know.
    func element(withIdentifierPrefix prefix: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
            .firstMatch
    }

    /// Waits until `element` is both present and hittable, so a tap that races
    /// a presentation animation cannot flake.
    @discardableResult
    func awaitTappable(
        _ element: XCUIElement,
        timeout: TimeInterval = UITestCase.defaultTimeout,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        element.awaitExistence(timeout: timeout, file: file, line: line)
        let hittable = NSPredicate(format: "isHittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: hittable, object: element)
        if XCTWaiter().wait(for: [expectation], timeout: timeout) != .completed {
            XCTFail("Element \(element) never became tappable", file: file, line: line)
        }
        return element
    }

    /// Taps once the control is ready to receive it.
    func tap(
        _ element: XCUIElement,
        timeout: TimeInterval = UITestCase.defaultTimeout,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        awaitTappable(element, timeout: timeout, file: file, line: line).tap()
    }

    /// Waits for a static text with exactly this label to appear anywhere on
    /// screen. Used for values a user reads, like "7/7".
    @discardableResult
    func awaitText(
        _ text: String,
        timeout: TimeInterval = UITestCase.defaultTimeout,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        let element = app.staticTexts[text]
        let found = element.waitForExistence(timeout: timeout)
        if !found {
            XCTFail("Timed out waiting for the text \"\(text)\"", file: file, line: line)
        }
        return found
    }
}

extension XCUIElement {
    /// Waits until the element's accessibility value contains `substring`.
    ///
    /// Values that animate (the calorie ring counts up) settle on a final
    /// value, so tests wait for the settled value rather than sampling once.
    @discardableResult
    func awaitValue(
        containing substring: String,
        timeout: TimeInterval = UITestCase.defaultTimeout,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        let predicate = NSPredicate(format: "value CONTAINS %@", substring)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        if result != .completed {
            XCTFail(
                "Timed out waiting for a value containing \"\(substring)\"; last value was "
                    + "\"\(String(describing: value))\"",
                file: file,
                line: line
            )
        }
        return result == .completed
    }

    /// Clears any existing text and types `text`.
    func replaceText(_ text: String) {
        tap()
        if let existing = value as? String, !existing.isEmpty {
            typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count))
        }
        typeText(text)
    }
}
