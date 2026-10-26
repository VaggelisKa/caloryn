import XCTest
@testable import Caloryn

final class MealTemplateLibraryRowSummaryTests: XCTestCase {
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

    func testAMealWithNoReadableItemsReadsAsUnavailable() {
        let summary = makeSummary(items: [])

        XCTAssertFalse(summary.isAvailable)
        XCTAssertEqual(summary.detail, "Unavailable meal")
    }

    func testTheTotalIsEveryItemAddedUpAndRoundedToWholeCalories() {
        let summary = makeSummary(items: [
            .init(name: "Skyr", calories: 95.4),
            .init(name: "Granola", calories: 180.3)
        ])

        XCTAssertEqual(summary.calories, 275.7, accuracy: 0.0001)
        XCTAssertEqual(summary.caloriesText, "276")
    }

    func testAnUnavailableMealPrintsNoTotal() {
        XCTAssertNil(makeSummary(items: []).caloriesText)
    }

    func testANonFiniteItemCountsAsNothing() {
        let summary = makeSummary(items: [
            .init(name: "Skyr", calories: 95),
            .init(name: "Broken", calories: .nan),
            .init(name: "Also broken", calories: .infinity)
        ])

        XCTAssertEqual(summary.caloriesText, "95")
    }

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

    private func makeSummary(
        name: String = "Meal",
        items: [MealTemplateLibraryRowSummary.Item]
    ) -> MealTemplateLibraryRowSummary {
        MealTemplateLibraryRowSummary(name: name, items: items)
    }
}
