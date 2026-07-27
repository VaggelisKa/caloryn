import XCTest
@testable import Caloryn

final class ProfileEditMacroRatiosTests: XCTestCase {
    func testRatiosAreDerivedFromTheSavedGramsAndTarget() {
        let ratios = ProfileEditMacroRatios(
            dailyCalorieTarget: 2_000,
            proteinTargetG: 150,
            carbTargetG: 200,
            fatTargetG: 66.7
        )

        XCTAssertEqual(ratios.protein, 0.30, accuracy: 0.0001)
        XCTAssertEqual(ratios.carbs, 0.40, accuracy: 0.0001)
        XCTAssertEqual(ratios.fat, 0.30, accuracy: 0.001)
    }

    func testAnUnevenSplitSurvivesTheRoundTrip() {
        let ratios = ProfileEditMacroRatios(
            dailyCalorieTarget: 2_400,
            proteinTargetG: 210,
            carbTargetG: 210,
            fatTargetG: 80
        )

        XCTAssertEqual(ratios.protein, 0.35, accuracy: 0.0001)
        XCTAssertEqual(ratios.carbs, 0.35, accuracy: 0.0001)
        XCTAssertEqual(ratios.fat, 0.30, accuracy: 0.0001)
    }

    func testAZeroTargetFallsBackToTheDefaultSplit() {
        let ratios = ProfileEditMacroRatios(
            dailyCalorieTarget: 0,
            proteinTargetG: 150,
            carbTargetG: 200,
            fatTargetG: 67
        )

        XCTAssertEqual(ratios.protein, 0.30)
        XCTAssertEqual(ratios.carbs, 0.40)
        XCTAssertEqual(ratios.fat, 0.30)
    }

    /// A stored zero for one macro is preserved rather than replaced by its
    /// default share.
    func testAMacroWithNoGramsBecomesAZeroRatio() {
        let ratios = ProfileEditMacroRatios(
            dailyCalorieTarget: 2_000,
            proteinTargetG: 0,
            carbTargetG: 200,
            fatTargetG: 66.7
        )

        XCTAssertEqual(ratios.protein, 0)
    }

    /// Nothing keeps the saved grams consistent with the target, so a stale
    /// profile can produce ratios that do not add up to 1 — and the screen
    /// re-applies them as they are.
    func testRatiosAreNotNormalizedToOneHundredPercent() {
        let ratios = ProfileEditMacroRatios(
            dailyCalorieTarget: 1_000,
            proteinTargetG: 150,
            carbTargetG: 200,
            fatTargetG: 67
        )

        XCTAssertEqual(ratios.protein + ratios.carbs + ratios.fat, 2.003, accuracy: 0.0001)
    }
}
