import XCTest

protocol Screen {
    var app: XCUIApplication { get }
}

extension Screen {
    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: identifier)
            .firstMatch
    }

    func element(withIdentifierPrefix prefix: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
            .firstMatch
    }

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

    @discardableResult
    func revealed(
        _ element: XCUIElement,
        maximumScrolls: Int = 4,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        guard element.awaitExistence(file: file, line: line) else { return element }

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

    func tap(
        _ element: XCUIElement,
        timeout: TimeInterval = UITestCase.defaultTimeout,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        awaitTappable(element, timeout: timeout, file: file, line: line).tap()
    }

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
}

extension XCUIElement {
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

    func replaceText(_ text: String) {
        tap()
        if let existing = value as? String, !existing.isEmpty {
            typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count))
        }
        typeText(text)
    }
}
