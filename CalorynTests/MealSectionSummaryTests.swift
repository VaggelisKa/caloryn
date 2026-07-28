import XCTest
@testable import Caloryn

final class MealSectionSummaryTests: XCTestCase {
    // MARK: - Title

    func testAMealIsNamedAfterItself() {
        XCTAssertEqual(makeSummary(mealType: .breakfast).title, "Breakfast")
        XCTAssertEqual(makeSummary(mealType: .dinner).title, "Dinner")
    }

    /// Snacks are the one meal that repeats in a day, so a snack section names
    /// its slot.
    func testASnackIsNamedAfterItsSlot() {
        XCTAssertEqual(makeSummary(mealType: .snack, snackIndex: 2).title, "Snack 2")
    }

    func testAnExplicitTitleWinsOverTheMealsOwnName() {
        XCTAssertEqual(
            makeSummary(mealType: .snack, snackIndex: 1, titleOverride: "Snacks").title,
            "Snacks"
        )
        XCTAssertEqual(
            makeSummary(mealType: .lunch, titleOverride: "Midday").title,
            "Midday"
        )
    }

    func testTheAddButtonIsSpokenWithTheSectionsOwnTitle() {
        XCTAssertEqual(
            makeSummary(mealType: .snack, snackIndex: 1, titleOverride: "Snacks").addAccessibilityLabel,
            "Add food or meal to Snacks"
        )
    }

    // MARK: - Totals

    func testHeaderTotalsAddUpAcrossTheSectionsEntries() {
        let summary = makeSummary(entries: [
            makeEntry(calories: 310, proteinG: 13.5, carbsG: 53, fatG: 5.5),
            makeEntry(calories: 62, proteinG: 0.4, carbsG: 16.8, fatG: 0.2)
        ])

        XCTAssertEqual(summary.totalCalories, 372, accuracy: 0.0001)
        XCTAssertEqual(summary.totalProtein, 13.9, accuracy: 0.0001)
        XCTAssertEqual(summary.totalCarbs, 69.8, accuracy: 0.0001)
        XCTAssertEqual(summary.totalFat, 5.7, accuracy: 0.0001)
        XCTAssertEqual(summary.entryCount, 2)
    }

    func testHeaderTotalsAreFormattedWithTheirMacroLetter() {
        let summary = makeSummary(entries: [
            makeEntry(calories: 372.4, proteinG: 13.9, carbsG: 69.8, fatG: 5.7)
        ])

        XCTAssertEqual(summary.caloriesText, "372 kcal")
        XCTAssertEqual(summary.proteinText, "13.9g P")
        XCTAssertEqual(summary.carbsText, "69.8g C")
        XCTAssertEqual(summary.fatText, "5.7g F")
    }

    // MARK: - What the header shows

    /// An empty meal's header stays quiet rather than printing a row of zeroes.
    func testAnEmptyMealShowsNoTotalsAtAll() {
        let summary = makeSummary(entries: [])

        XCTAssertFalse(summary.showsCalories)
        XCTAssertFalse(summary.showsMacroBreakdown)
        XCTAssertFalse(summary.showsProtein)
        XCTAssertFalse(summary.showsCarbs)
        XCTAssertFalse(summary.showsFat)
    }

    /// A macro nothing contributed to is omitted, so a plain sugar snack does
    /// not claim "0.0g P".
    func testAMacroNothingContributedToIsOmitted() {
        let summary = makeSummary(entries: [
            makeEntry(calories: 96, proteinG: 0, carbsG: 25, fatG: 0)
        ])

        XCTAssertTrue(summary.showsCalories)
        XCTAssertTrue(summary.showsMacroBreakdown)
        XCTAssertFalse(summary.showsProtein)
        XCTAssertTrue(summary.showsCarbs)
        XCTAssertFalse(summary.showsFat)
    }

    /// A zero-calorie food is still logged food, so the macro line appears even
    /// with no calorie figure above it.
    func testAZeroCalorieEntryStillShowsItsMacroBreakdown() {
        let summary = makeSummary(entries: [
            makeEntry(calories: 0, proteinG: 2, carbsG: 0, fatG: 0)
        ])

        XCTAssertFalse(summary.showsCalories)
        XCTAssertTrue(summary.showsMacroBreakdown)
        XCTAssertTrue(summary.showsProtein)
    }

    // MARK: - Rows

    /// Zero and one entry both go through the cross-fading slot, so deleting the
    /// last item can fade into the empty state instead of the row vanishing.
    func testAtMostOneEntryIsDrawnThroughTheFadingSlot() {
        XCTAssertTrue(makeSummary(entries: []).usesSingleRowTransition)
        XCTAssertTrue(makeSummary(entries: [makeEntry()]).usesSingleRowTransition)
    }

    func testSeveralEntriesAreDrawnAsPlainRows() {
        XCTAssertFalse(makeSummary(entries: [makeEntry(), makeEntry()]).usesSingleRowTransition)
    }

    // MARK: - Helpers

    private func makeSummary(
        mealType: MealType = .breakfast,
        snackIndex: Int = 0,
        titleOverride: String? = nil,
        entries: [MealSectionSummary.Entry] = []
    ) -> MealSectionSummary {
        MealSectionSummary(
            mealType: mealType,
            snackIndex: snackIndex,
            titleOverride: titleOverride,
            entries: entries
        )
    }

    private func makeEntry(
        calories: Double = 100,
        proteinG: Double = 1,
        carbsG: Double = 1,
        fatG: Double = 1
    ) -> MealSectionSummary.Entry {
        MealSectionSummary.Entry(
            calories: calories,
            proteinG: proteinG,
            carbsG: carbsG,
            fatG: fatG
        )
    }
}
