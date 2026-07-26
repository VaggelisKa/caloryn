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

    /// Waits until `element` is ready to be tapped, so a tap that races a
    /// presentation animation cannot flake.
    ///
    /// This is one wait, not two. `isHittable` is already false for an element
    /// that does not exist, so a separate existence check adds nothing but
    /// time — and every XCTest wait costs a full polling cycle even when the
    /// condition already holds, so the second check was charging about a
    /// second to each interaction in the suite.
    @discardableResult
    func awaitTappable(
        _ element: XCUIElement,
        timeout: TimeInterval = UITestCase.defaultTimeout,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        guard !element.isHittable else { return element }

        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isHittable == true"),
            object: element
        )
        if XCTWaiter().wait(for: [expectation], timeout: timeout) != .completed {
            // Distinguish the two failures the single wait folded together, so
            // a red test still says which one happened.
            XCTFail(
                element.exists
                    ? "Element \(element) exists but never became tappable"
                    : "Element \(element) never appeared",
                file: file,
                line: line
            )
        }
        return element
    }

    /// Scrolls until `element` can actually be tapped, then returns it.
    ///
    /// A control that exists but sits behind the keyboard reports
    /// `isHittable == false` for as long as the keyboard is up, so waiting on
    /// it can only ever time out. Where the fold falls depends on whether a
    /// field was focused first, which is why a long form can be reachable on
    /// one run and not the next.
    ///
    /// The drag is deliberate rather than `swipeUp()`: swipe starts near the
    /// bottom of the element, which on a focused form is inside the keyboard,
    /// so the keyboard swallows it and nothing scrolls.
    @discardableResult
    func revealed(
        _ element: XCUIElement,
        maximumScrolls: Int = 4,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        guard element.awaitExistence(file: file, line: line) else { return element }

        // The tallest scroll view is the content; the short one is the
        // keyboard's own accessory strip.
        guard let content = (0..<app.scrollViews.count)
            .map({ app.scrollViews.element(boundBy: $0) })
            .max(by: { $0.frame.height < $1.frame.height }) else {
            return element
        }

        var scrolls = 0
        while !element.isHittable, scrolls < maximumScrolls {
            content
                .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
                .press(
                    forDuration: 0.05,
                    thenDragTo: content.coordinate(
                        withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)
                    )
                )
            scrolls += 1
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

    /// Taps a control that a given build may not present at all, reporting
    /// whether it was there. One wait covers both the question and the
    /// readiness check.
    @discardableResult
    func tapIfPresent(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        if element.isHittable {
            element.tap()
            return true
        }

        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isHittable == true"),
            object: element
        )
        guard XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed else {
            return false
        }
        element.tap()
        return true
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

    /// Waits until the element's label contains `substring`.
    ///
    /// Used for values a user reads out of a label rather than a control's
    /// accessibility value, such as the calorie target in Settings.
    @discardableResult
    func awaitLabel(
        containing substring: String,
        timeout: TimeInterval = UITestCase.defaultTimeout,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", substring)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        if result != .completed {
            XCTFail(
                "Timed out waiting for a label containing \"\(substring)\"; last label was "
                    + "\"\(label)\"",
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
