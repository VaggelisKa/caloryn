import XCTest
@testable import Caloryn

final class CalorieRingSummaryTests: XCTestCase {
    func testAnUnderBudgetDayCountsDownWhatIsLeft() {
        let summary = makeSummary(isOver: false, remaining: 480, roundedConsumed: 1_520)

        XCTAssertEqual(summary.centerValue, 480)
        XCTAssertEqual(summary.centerCaption, "remaining")
        XCTAssertEqual(summary.eatenText, "1520 eaten")
    }

    func testAnOverBudgetDayCountsUpTheOvershoot() {
        let summary = makeSummary(isOver: true, overAmount: 130, roundedConsumed: 2_130)

        XCTAssertEqual(summary.centerValue, 130)
        XCTAssertEqual(summary.centerCaption, "over")
        XCTAssertEqual(summary.eatenText, "2130 eaten")
    }

    func testTheAccentIsTheSameDecisionTheNutritionSheetMakes() {
        XCTAssertEqual(makeSummary(isOver: false).accent, .withinBudget)
        XCTAssertEqual(makeSummary(isOver: true).accent, .overBudget)
        XCTAssertEqual(
            makeSummary(isOver: true).accent,
            NutritionDetailsSummary.calorieAccent(isOver: true)
        )
    }

    func testTheLabelReadsWhatIsLeftAgainstTheTarget() {
        let summary = makeSummary(
            isOver: false,
            remaining: 480,
            roundedConsumed: 1_520,
            target: 2_000
        )

        XCTAssertEqual(
            summary.accessibilityLabel,
            "Calorie ring, 480 remaining of 2000 calories, 1520 eaten"
        )
        XCTAssertEqual(summary.accessibilityValue, "1520 eaten, 480 remaining of 2000")
    }

    func testTheLabelReadsTheOvershootAgainstTheTarget() {
        let summary = makeSummary(
            isOver: true,
            overAmount: 130,
            roundedConsumed: 2_130,
            target: 2_000
        )

        XCTAssertEqual(
            summary.accessibilityLabel,
            "Calorie ring, 2130 eaten, 130 calories over a 2000 calorie goal"
        )
        XCTAssertEqual(summary.accessibilityValue, "2130 eaten, 130 calories over target of 2000")
    }

    func testTheHintIsSilentWhenTheRingDoesNothing() {
        XCTAssertEqual(CalorieRingSummary.accessibilityHint(isInteractive: false), "")
        XCTAssertEqual(
            CalorieRingSummary.accessibilityHint(isInteractive: true),
            "Tap or long press to show nutrition details."
        )
    }

    func testTheBudgetsFiguresAreTakenAsGiven() {
        let budget = CalorieBudget(consumed: 2_130, target: 2_000)
        let summary = CalorieRingSummary(budget: budget)

        XCTAssertEqual(summary.isOver, budget.isOver)
        XCTAssertEqual(summary.centerValue, budget.overAmount)
        XCTAssertEqual(summary.target, budget.target)
        XCTAssertEqual(summary.roundedConsumed, budget.roundedConsumed)
    }

    private func makeSummary(
        isOver: Bool = false,
        remaining: Int = 500,
        overAmount: Int = 0,
        roundedConsumed: Int = 1_500,
        target: Int = 2_000
    ) -> CalorieRingSummary {
        CalorieRingSummary(
            isOver: isOver,
            remaining: remaining,
            overAmount: overAmount,
            roundedConsumed: roundedConsumed,
            target: target
        )
    }
}
