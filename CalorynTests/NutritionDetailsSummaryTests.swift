import XCTest
@testable import Caloryn

final class NutritionDetailsSummaryTests: XCTestCase {
    func testTotalsAddUpAcrossEntries() {
        let summary = NutritionDetailsSummary(entries: [
            makeEntry(calories: 310, proteinG: 12, portionGrams: 80),
            makeEntry(calories: 62, proteinG: 0.4, portionGrams: 120)
        ])

        XCTAssertEqual(summary.totalCalories, 372, accuracy: 0.0001)
        XCTAssertEqual(summary.totalNutrition.proteinG, 12.4, accuracy: 0.0001)
        XCTAssertEqual(summary.totalPortionGrams, 200, accuracy: 0.0001)
        XCTAssertEqual(summary.loggedItemCount, 2)
    }

    func testAnEmptyDayTotalsToZero() {
        let summary = NutritionDetailsSummary(entries: [])

        XCTAssertEqual(summary.totalCalories, 0)
        XCTAssertEqual(summary.totalPortionGrams, 0)
        XCTAssertEqual(summary.loggedItemCount, 0)
        XCTAssertEqual(summary.totalNutrition, .zero)
    }

    func testOptionalSubNutrientsSurviveBeingSummedWithEntriesThatLackThem() {
        let summary = NutritionDetailsSummary(entries: [
            makeEntry(nutrition: NutritionValues(calories: 100, starchG: 12)),
            makeEntry(nutrition: NutritionValues(calories: 50))
        ])

        XCTAssertEqual(summary.totalNutrition.starchG, 12)
    }

    func testASingleLoggedItemIsCountedInTheSingular() {
        XCTAssertEqual(NutritionDetailsSummary(entries: [makeEntry()]).loggedItemsUnitText, "item")
    }

    func testNoOrManyLoggedItemsAreCountedInThePlural() {
        XCTAssertEqual(NutritionDetailsSummary(entries: []).loggedItemsUnitText, "items")
        XCTAssertEqual(
            NutritionDetailsSummary(entries: [makeEntry(), makeEntry()]).loggedItemsUnitText,
            "items"
        )
    }

    func testStayingInsideTheBudgetReadsAsRemaining() {
        XCTAssertEqual(NutritionDetailsSummary.calorieAccent(isOver: false), .withinBudget)
        XCTAssertEqual(NutritionDetailsSummary.calorieSummaryLabel(isOver: false), "Remaining")
    }

    func testGoingOverTheBudgetReadsAsOver() {
        XCTAssertEqual(NutritionDetailsSummary.calorieAccent(isOver: true), .overBudget)
        XCTAssertEqual(NutritionDetailsSummary.calorieSummaryLabel(isOver: true), "Over")
    }

    func testTheAccentFollowsTheBudgetsOwnRoundedDecision() {
        let budget = CalorieBudget(consumed: 2_000.4, target: 2_000)

        XCTAssertFalse(budget.isOver)
        XCTAssertEqual(NutritionDetailsSummary.calorieAccent(isOver: budget.isOver), .withinBudget)
        XCTAssertEqual(budget.overAmount, 0)
    }

    func testProgressRunsProportionallyBetweenNothingAndTheTarget() {
        XCTAssertEqual(NutritionDetailsSummary.progressFraction(current: 500, target: 2_000), 0.25)
        XCTAssertEqual(NutritionDetailsSummary.progressFraction(current: 0, target: 2_000), 0)
    }

    func testProgressIsCappedAtAFullBar() {
        XCTAssertEqual(NutritionDetailsSummary.progressFraction(current: 4_000, target: 2_000), 1)
    }

    func testProgressNeverRunsBackwardsOrDividesByAMissingTarget() {
        XCTAssertEqual(NutritionDetailsSummary.progressFraction(current: -100, target: 2_000), 0)
        XCTAssertEqual(NutritionDetailsSummary.progressFraction(current: 500, target: 0), 0)
        XCTAssertEqual(NutritionDetailsSummary.progressFraction(current: 500, target: -2_000), 0)
    }

    private func makeEntry(
        calories: Double = 0,
        proteinG: Double = 0,
        portionGrams: Double = 0
    ) -> NutritionDetailsSummary.Entry {
        NutritionDetailsSummary.Entry(
            nutrition: NutritionValues(calories: calories, proteinG: proteinG),
            portionGrams: portionGrams
        )
    }

    private func makeEntry(
        nutrition: NutritionValues,
        portionGrams: Double = 100
    ) -> NutritionDetailsSummary.Entry {
        NutritionDetailsSummary.Entry(nutrition: nutrition, portionGrams: portionGrams)
    }
}
