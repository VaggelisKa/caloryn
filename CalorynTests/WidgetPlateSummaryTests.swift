import XCTest
@testable import Caloryn

final class WidgetPlateSummaryTests: XCTestCase {
    func testUnderBudgetDrawsEachMealThenTheRestOfTheBudget() {
        let calories = WidgetCalorieSummary(
            consumed: 963,
            target: 2_000,
            mealCalories: [.breakfast: 382, .lunch: 463, .snack: 118]
        )

        let plate = WidgetPlateSummary(calories: calories)

        XCTAssertFalse(plate.isOver)
        XCTAssertEqual(plate.sectors.map(\.kind), [.meal(.breakfast), .meal(.lunch), .meal(.snack), .remaining])
        XCTAssertEqual(plate.sectors.map(\.kcal), [382, 463, 118, 1_037])
    }

    func testOverBudgetScalesTheMealsIntoTheBudgetAndAddsTheOvershoot() {
        let calories = WidgetCalorieSummary(
            consumed: 2_500,
            target: 2_000,
            mealCalories: [.breakfast: 500, .lunch: 1_000, .dinner: 1_000]
        )

        let plate = WidgetPlateSummary(calories: calories)

        XCTAssertTrue(plate.isOver)
        XCTAssertEqual(plate.sectors.map(\.kind), [.meal(.breakfast), .meal(.lunch), .meal(.dinner), .over])
        XCTAssertEqual(plate.sectors.map(\.kcal), [400, 800, 800, 500])
        XCTAssertEqual(plate.sectors.reduce(0) { $0 + $1.kcal }, 2_500, accuracy: 0.001)
    }

    func testATotalWithoutMealsDrawsAsOneNeutralSector() {
        let calories = WidgetCalorieSummary(consumed: 800, target: 2_000)

        let plate = WidgetPlateSummary(calories: calories)

        XCTAssertEqual(plate.sectors.map(\.kind), [.eaten, .remaining])
        XCTAssertEqual(plate.sectors.map(\.kcal), [800, 1_200])
    }

    func testMealsThatDoNotAddUpToTheTotalKeepTheDifferenceOnThePlate() {
        let calories = WidgetCalorieSummary(
            consumed: 1_000,
            target: 2_000,
            mealCalories: [.lunch: 600]
        )

        let plate = WidgetPlateSummary(calories: calories)

        XCTAssertEqual(plate.sectors.map(\.kind), [.meal(.lunch), .eaten, .remaining])
        XCTAssertEqual(plate.sectors.map(\.kcal), [600, 400, 1_000])
    }

    func testARoundingGapBetweenMealsAndTheTotalDrawsNoExtraSector() {
        let calories = WidgetCalorieSummary(
            consumed: 1_200.8,
            target: 2_000,
            mealCalories: [.breakfast: 600.4, .lunch: 600.4]
        )

        let plate = WidgetPlateSummary(calories: calories)

        XCTAssertEqual(calories.consumed, 1_201)
        XCTAssertEqual(plate.sectors.map(\.kind), [.meal(.breakfast), .meal(.lunch), .remaining])
        XCTAssertEqual(plate.sectors.reduce(0) { $0 + $1.kcal }, 2_000, accuracy: 0.001)
        XCTAssertEqual(plate.sectors.last?.kcal ?? 0, 799, accuracy: 0.001)
    }

    func testMealsRoundedPastTheTotalDoNotExceedIt() {
        let calories = WidgetCalorieSummary(
            consumed: 601,
            target: 2_000,
            mealCalories: [.breakfast: 300.5, .lunch: 300.5]
        )

        let plate = WidgetPlateSummary(calories: calories)

        let eaten = plate.sectors.filter { $0.kind != .remaining }.reduce(0) { $0 + $1.kcal }
        XCTAssertEqual(eaten, 601, accuracy: 0.001)
        XCTAssertEqual(plate.sectors.map(\.kind), [.meal(.breakfast), .meal(.lunch), .remaining])
    }

    func testNothingEatenIsABareTrack() {
        let calories = WidgetCalorieSummary(consumed: 0, target: 2_000)

        let plate = WidgetPlateSummary(calories: calories)

        XCTAssertEqual(plate.sectors.map(\.kind), [.remaining])
        XCTAssertFalse(plate.isOver)
    }

    func testAMealLoggedAtZeroDrawsNoSector() {
        let calories = WidgetCalorieSummary(
            consumed: 300,
            target: 2_000,
            mealCalories: [.breakfast: 0, .lunch: 300]
        )

        let plate = WidgetPlateSummary(calories: calories)

        XCTAssertEqual(plate.sectors.map(\.kind), [.meal(.lunch), .remaining])
    }
}
