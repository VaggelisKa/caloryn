import XCTest
@testable import Caloryn

final class NutrientGoalPickerVisibilityTests: XCTestCase {
    func testPickerIsHiddenWhileTheFieldIsEmpty() {
        XCTAssertFalse(NutrientGoalPickerVisibility.isVisible(targetText: ""))
    }

    func testPickerAppearsOnceTheFieldHasAValue() {
        XCTAssertTrue(NutrientGoalPickerVisibility.isVisible(targetText: "30"))
    }

    func testWhitespaceAloneDoesNotCountAsAValue() {
        XCTAssertFalse(NutrientGoalPickerVisibility.isVisible(targetText: "   "))
        XCTAssertFalse(NutrientGoalPickerVisibility.isVisible(targetText: "\n"))
    }

    /// Visibility tracks the presence of text, not whether it parses — the
    /// invalid-value warning is a separate rule.
    func testUnparseableTextStillShowsThePicker() {
        XCTAssertTrue(NutrientGoalPickerVisibility.isVisible(targetText: "abc"))
    }
}
