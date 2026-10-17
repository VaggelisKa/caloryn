import XCTest
@testable import Caloryn

final class SettingsGoalPlateTests: XCTestCase {
    func testEachMealIsTheSumOfItsEntries() {
        let totals = SettingsGoalPlate.mealTotals([
            .init(meal: .breakfast, calories: 95),
            .init(meal: .lunch, calories: 352),
            .init(meal: .breakfast, calories: 180)
        ])

        XCTAssertEqual(totals, [.breakfast: 275, .lunch: 352])
    }

    /// Two snack slots are one snack on the plate.
    func testSnacksFromDifferentSlotsShareOneTotal() {
        let totals = SettingsGoalPlate.mealTotals([
            .init(meal: .snack, calories: 118),
            .init(meal: .snack, calories: 107)
        ])

        XCTAssertEqual(totals, [.snack: 225])
    }

    func testANothingLoggedDayHasNoMeals() {
        XCTAssertTrue(SettingsGoalPlate.mealTotals([]).isEmpty)
        XCTAssertEqual(SettingsGoalPlate.eaten([]), 0)
    }

    func testEatenIsEveryEntryAddedUp() {
        XCTAssertEqual(
            SettingsGoalPlate.eaten([
                .init(meal: .breakfast, calories: 95),
                .init(meal: .dinner, calories: 600)
            ]),
            695,
            accuracy: 0.0001
        )
    }
}
