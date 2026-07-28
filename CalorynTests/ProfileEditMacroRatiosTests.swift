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

    /// Grams that claim more calories than the target are stale, not a choice:
    /// the split is scaled back to total 1 so Save stops re-applying an
    /// impossible one.
    func testAnImpossibleSplitIsScaledBackToOneHundredPercent() {
        let ratios = ProfileEditMacroRatios(
            dailyCalorieTarget: 1_000,
            proteinTargetG: 150,
            carbTargetG: 200,
            fatTargetG: 67
        )

        XCTAssertEqual(ratios.protein + ratios.carbs + ratios.fat, 1.0, accuracy: 0.0001)
    }

    /// Scaling corrects the size of the split, never its shape — the
    /// proportions between the three macros are the part the user chose.
    func testScalingPreservesTheProportionsBetweenMacros() {
        let ratios = ProfileEditMacroRatios(
            dailyCalorieTarget: 1_000,
            proteinTargetG: 150,
            carbTargetG: 200,
            fatTargetG: 67
        )

        // Raw shares were 0.6 / 0.8 / 0.603, totalling 2.003.
        XCTAssertEqual(ratios.protein, 0.6 / 2.003, accuracy: 0.0001)
        XCTAssertEqual(ratios.carbs, 0.8 / 2.003, accuracy: 0.0001)
        XCTAssertEqual(ratios.fat, 0.603 / 2.003, accuracy: 0.0001)
    }

    /// A split that leaves calories unaccounted for is a legitimate thing to
    /// save, so it is left exactly as it is rather than inflated to 100%.
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

    /// A split that already totals 100% comes back as the same 30/40/30.
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

    /// Nothing sane can be derived from a stored value that is not a number.
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

    /// The profile derives its split through the same type, so a zero target no
    /// longer divides by 1 and produces ratios in the hundreds.
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
