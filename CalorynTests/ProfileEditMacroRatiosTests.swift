import XCTest
@testable import Caloryn

@MainActor
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

    func testAMacroWithNoGramsBecomesAZeroRatio() {
        let ratios = ProfileEditMacroRatios(
            dailyCalorieTarget: 2_000,
            proteinTargetG: 0,
            carbTargetG: 200,
            fatTargetG: 66.7
        )

        XCTAssertEqual(ratios.protein, 0)
    }

    func testAnImpossibleSplitIsScaledBackToOneHundredPercent() {
        let ratios = ProfileEditMacroRatios(
            dailyCalorieTarget: 1_000,
            proteinTargetG: 150,
            carbTargetG: 200,
            fatTargetG: 67
        )

        XCTAssertEqual(ratios.protein + ratios.carbs + ratios.fat, 1.0, accuracy: 0.0001)
    }

    func testScalingPreservesTheProportionsBetweenMacros() {
        let ratios = ProfileEditMacroRatios(
            dailyCalorieTarget: 1_000,
            proteinTargetG: 150,
            carbTargetG: 200,
            fatTargetG: 67
        )

        XCTAssertEqual(ratios.protein, 0.6 / 2.003, accuracy: 0.0001)
        XCTAssertEqual(ratios.carbs, 0.8 / 2.003, accuracy: 0.0001)
        XCTAssertEqual(ratios.fat, 0.603 / 2.003, accuracy: 0.0001)
    }

    func testAnUnderAllocatedSplitIsLeftAlone() {
        let ratios = ProfileEditMacroRatios(
            dailyCalorieTarget: 2_000,
            proteinTargetG: 150,
            carbTargetG: 100,
            fatTargetG: 30
        )

        XCTAssertEqual(ratios.protein, 0.30, accuracy: 0.0001)
        XCTAssertEqual(ratios.carbs, 0.20, accuracy: 0.0001)
        XCTAssertEqual(ratios.fat, 0.135, accuracy: 0.0001)
    }

    func testASplitThatAlreadyTotalsOneKeepsItsValues() {
        let ratios = ProfileEditMacroRatios(
            dailyCalorieTarget: 2_000,
            proteinTargetG: 150,
            carbTargetG: 200,
            fatTargetG: 66.666_666_7
        )

        XCTAssertEqual(ratios.protein, 0.30, accuracy: 0.000_001)
        XCTAssertEqual(ratios.carbs, 0.40, accuracy: 0.000_001)
        XCTAssertEqual(ratios.fat, 0.30, accuracy: 0.000_001)
    }

    func testANonFiniteGramValueFallsBackToTheDefaultSplit() {
        let ratios = ProfileEditMacroRatios(
            dailyCalorieTarget: 2_000,
            proteinTargetG: .nan,
            carbTargetG: 200,
            fatTargetG: 67
        )

        XCTAssertEqual(ratios, .defaultSplit)
    }

    func testAnInfiniteGramValueFallsBackToTheDefaultSplit() {
        let ratios = ProfileEditMacroRatios(
            dailyCalorieTarget: 2_000,
            proteinTargetG: .infinity,
            carbTargetG: 200,
            fatTargetG: 67
        )

        XCTAssertEqual(ratios, .defaultSplit)
    }

    func testTheProfileDerivesTheSameSplit() {
        let profile = UserProfile(
            age: 30,
            sex: .male,
            heightCm: 180,
            weightKg: 80,
            activityLevel: .sedentary,
            dailyCalorieTarget: 0
        )

        XCTAssertEqual(profile.macroRatios, .defaultSplit)
    }
}
