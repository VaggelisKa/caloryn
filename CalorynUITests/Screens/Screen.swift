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

    func capture(_ name: String) {
        let directory = URL(fileURLWithPath: "/tmp/caloryn-evidence", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let screenshot = XCUIScreen.main.screenshot()
        try? screenshot.pngRepresentation.write(to: directory.appendingPathComponent("\(name).png"))
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
    var hasKeyboardFocus: Bool {
        (value(forKey: "hasKeyboardFocus") as? Bool) ?? false
    }

    var lastSeenLabel: String {
        exists ? "\"\(label)\"" : "gone from the screen"
    }

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
                "Timed out waiting for a label containing \"\(substring)\"; the element was "
                    + lastSeenLabel,
                file: file,
                line: line
            )
        }
        return result == .completed
    }

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
                "Timed out waiting for a value containing \"\(substring)\"; the element was "
                    + (exists ? "\"\(value ?? "")\"" : "gone from the screen"),
                file: file,
                line: line
            )
        }
        return result == .completed
    }

    @discardableResult
    func awaitKeyboardFocus(
        timeout: TimeInterval = UITestCase.defaultTimeout,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        let focused = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "hasKeyboardFocus == true"),
            object: self
        )
        if XCTWaiter().wait(for: [focused], timeout: timeout) != .completed {
            XCTFail("\(self) never took keyboard focus", file: file, line: line)
        }
        return self
    }

    @discardableResult
    func focusForTyping(
        tappingInsetFromTrailingEdge inset: CGFloat = 16,
        timeout: TimeInterval = UITestCase.defaultTimeout,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        if exists, hasKeyboardFocus { return self }

        let hittable = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isHittable == true"),
            object: self
        )
        guard XCTWaiter().wait(for: [hittable], timeout: timeout) == .completed else {
            XCTFail("\(self) never became tappable to type into", file: file, line: line)
            return self
        }
        coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5))
            .withOffset(CGVector(dx: -inset, dy: 0))
            .tap()
        return awaitKeyboardFocus(timeout: timeout, file: file, line: line)
    }

    func replaceText(
        _ text: String,
        tappingInsetFromTrailingEdge inset: CGFloat = 16,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        focusForTyping(tappingInsetFromTrailingEdge: inset, file: file, line: line)
        let existing = (value as? String)?.count ?? 0
        typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing + 2) + text)

        guard value as? String != text else { return }
        let replaced = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", text),
            object: self
        )
        if XCTWaiter().wait(for: [replaced], timeout: UITestCase.defaultTimeout) != .completed {
            XCTFail(
                "\(self) holds \"\(value as? String ?? "")\" instead of \"\(text)\"",
                file: file,
                line: line
            )
        }
    }
}
