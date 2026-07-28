import XCTest
@testable import Caloryn

final class NutrientDetailGroupTests: XCTestCase {
    // MARK: - Absent values

    /// A sub-nutrient nothing was recorded for is left out. Printing it as zero
    /// would claim the food genuinely contains none of it.
    func testANutrientWithNothingRecordedIsOmittedRatherThanShownAsZero() {
        let items = NutrientDetailGroup.carbs.items(in: NutritionValues(calories: 100))

        XCTAssertTrue(items.isEmpty)
    }

    func testARecordedZeroIsStillShown() {
        let items = NutrientDetailGroup.carbs.items(in: NutritionValues(calories: 100, starchG: 0))

        XCTAssertEqual(items.map(\.id), ["starch"])
        XCTAssertEqual(items.first?.value, 0)
    }

    func testAGroupWithNoRecordedNutrientsDisappearsEntirely() {
        let groups = NutrientDetailGroup.populatedGroups(in: NutritionValues(calories: 100))

        XCTAssertTrue(groups.isEmpty)
    }

    // MARK: - Grouping

    func testEachNutrientIsListedUnderItsOwnGroup() {
        let nutrition = NutritionValues(
            calories: 400,
            sucroseG: 2,
            starchG: 55,
            transFatG: 0.3,
            omega3FatG: 0.1,
            saltG: 0.02,
            caseinG: 8
        )

        let groups = NutrientDetailGroup.populatedGroups(in: nutrition)

        XCTAssertEqual(groups.map(\.group), [.protein, .carbs, .fat, .salt])
        XCTAssertEqual(groups[0].items.map(\.id), ["casein"])
        XCTAssertEqual(groups[1].items.map(\.id), ["sucrose", "starch"])
        XCTAssertEqual(groups[2].items.map(\.id), ["trans-fat", "omega-3-fat"])
        XCTAssertEqual(groups[3].items.map(\.id), ["salt"])
    }

    /// Sugars stay in the order they are declared in, not the order of whatever
    /// the day happened to contain, so the breakdown does not reshuffle between
    /// days.
    func testCarbLinesKeepAFixedOrderRegardlessOfWhichAreRecorded() {
        let nutrition = NutritionValues(
            calories: 400,
            sucroseG: 1,
            fructoseG: 2,
            starchG: 3,
            polyolsG: 4
        )

        XCTAssertEqual(
            NutrientDetailGroup.carbs.items(in: nutrition).map(\.id),
            ["sucrose", "fructose", "starch", "polyols"]
        )
    }

    func testOnlyPopulatedGroupsAreReturned() {
        let nutrition = NutritionValues(calories: 400, saltG: 1.2)
        let groups = NutrientDetailGroup.populatedGroups(in: nutrition)

        XCTAssertEqual(groups.map(\.group), [.salt])
        XCTAssertEqual(groups.first?.title, "Salt")
    }

    // MARK: - Identity

    func testEveryGroupAndLineHasAStableIdentity() {
        let ids = NutrientDetailGroup.allCases.flatMap { group in
            NutrientDetailGroup.definitionIDsForTesting(group)
        }

        XCTAssertEqual(Set(ids).count, ids.count, "Detail nutrient identifiers must be unique across groups")
        XCTAssertEqual(Set(NutrientDetailGroup.allCases.map(\.id)).count, NutrientDetailGroup.allCases.count)
    }

    // MARK: - Formatting

    func testGramLinesAreFormattedAsGrams() {
        let nutrient = DetailNutrient(id: "starch", label: "Starch", value: 55.28, unit: .grams)

        XCTAssertEqual(nutrient.formattedValue, "55.3g")
    }

    func testAWholeNumberOfGramsDropsItsDecimal() {
        let nutrient = DetailNutrient(id: "starch", label: "Starch", value: 55, unit: .grams)

        XCTAssertEqual(nutrient.formattedValue, "55g")
    }

    func testMilligramLinesAreScaledUpFromGrams() {
        let nutrient = DetailNutrient(id: "salt", label: "Salt", value: 0.0204, unit: .milligramsFromGrams)

        XCTAssertEqual(nutrient.formattedValue, "20mg")
    }

    /// Nothing bounds a nutrient value on the way in, and the milligram branch
    /// multiplies it by a thousand before rounding — which `Int(_:)` answers by
    /// terminating the process.
    func testAnUnboundedNutrientValueIsRenderedRatherThanCrashing() {
        let huge = DetailNutrient(id: "salt", label: "Salt", value: 1e30, unit: .milligramsFromGrams)

        XCTAssertEqual(huge.formattedValue, "\(Int.max)mg")
    }
}

private extension NutrientDetailGroup {
    /// The line identifiers this group can produce, reached through a value that
    /// records every one of them.
    static func definitionIDsForTesting(_ group: NutrientDetailGroup) -> [String] {
        group.items(in: everyNutrientRecorded).map(\.id)
    }

    static let everyNutrientRecorded = NutritionValues(
        calories: 500,
        sucroseG: 1,
        glucoseG: 1,
        fructoseG: 1,
        lactoseG: 1,
        maltoseG: 1,
        maltodextrinsG: 1,
        starchG: 1,
        polyolsG: 1,
        transFatG: 1,
        monounsaturatedFatG: 1,
        polyunsaturatedFatG: 1,
        omega3FatG: 1,
        omega6FatG: 1,
        omega9FatG: 1,
        saltG: 1,
        caseinG: 1,
        serumProteinsG: 1
    )
}
