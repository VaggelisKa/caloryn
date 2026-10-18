import XCTest
@testable import Caloryn

final class MealTemplateLibraryRowSummaryTests: XCTestCase {
    // MARK: - Detail line

    func testTheDetailLineNamesTheItemsInTheMealsOwnOrder() {
        let summary = makeSummary(items: [
            .init(name: "Skyr", calories: 95),
            .init(name: "Granola", calories: 180),
            .init(name: "Banana", calories: 107)
        ])

        XCTAssertEqual(summary.detail, "Skyr, Granola, Banana")
    }

    func testAOneItemMealIsNamedByThatItemAlone() {
        XCTAssertEqual(makeSummary(items: [.init(name: "Rugbrød", calories: 94)]).detail, "Rugbrød")
    }

    /// A meal whose items could not be read is still listed, so it says why it is empty.
    func testAMealWithNoReadableItemsReadsAsUnavailable() {
        let summary = makeSummary(items: [])

        XCTAssertFalse(summary.isAvailable)
        XCTAssertEqual(summary.detail, "Unavailable meal")
    }

    // MARK: - Trailing total

    func testTheTotalIsEveryItemAddedUpAndRoundedToWholeCalories() {
        let summary = makeSummary(items: [
            .init(name: "Skyr", calories: 95.4),
            .init(name: "Granola", calories: 180.3)
        ])

        XCTAssertEqual(summary.calories, 275.7, accuracy: 0.0001)
        XCTAssertEqual(summary.caloriesText, "276")
    }

    /// "0 kcal" would claim the meal is free; an unreadable meal has no total at all.
    func testAnUnavailableMealPrintsNoTotal() {
        XCTAssertNil(makeSummary(items: []).caloriesText)
    }

    /// A figure that never became a number must not turn the whole meal into NaN.
    func testANonFiniteItemCountsAsNothing() {
        let summary = makeSummary(items: [
            .init(name: "Skyr", calories: 95),
            .init(name: "Broken", calories: .nan),
            .init(name: "Also broken", calories: .infinity)
        ])

        XCTAssertEqual(summary.caloriesText, "95")
    }

    // MARK: - Accessibility

    func testTheSpokenLabelNamesTheMealItsItemsAndTheTotal() {
        let summary = makeSummary(
            name: "Weekday breakfast",
            items: [.init(name: "Skyr", calories: 95), .init(name: "Banana", calories: 107)]
        )

        XCTAssertEqual(summary.accessibilityLabel, "Weekday breakfast, Skyr, Banana, 202 kilocalories")
    }

    func testTheSpokenLabelOfAnUnavailableMealSaysSo() {
        XCTAssertEqual(
            makeSummary(name: "Office lunch", items: []).accessibilityLabel,
            "Office lunch, Unavailable meal"
        )
    }

    // MARK: - Helpers

    private func makeSummary(
        name: String = "Meal",
        items: [MealTemplateLibraryRowSummary.Item]
    ) -> MealTemplateLibraryRowSummary {
        MealTemplateLibraryRowSummary(name: name, items: items)
    }
}
