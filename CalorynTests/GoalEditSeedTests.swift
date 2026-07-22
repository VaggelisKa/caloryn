import XCTest
@testable import Caloryn

@MainActor
final class GoalEditSeedTests: XCTestCase {

    func testManualProfileSeedsTheStoredTargetNotARecalculation() {
        let profile = makeProfile()
        OnboardingProfileSave.apply(
            makeSelections(calorieTarget: 1_800, isManualTarget: true),
            to: profile
        )
        // The calculation for this profile lands well away from 1,800, so a
        // recalculated seed would be obvious.
        XCTAssertNotEqual(
            NutritionCalculator.defaultTarget(tdee: profile.tdee, deficit: profile.calorieDeficit),
            1_800
        )

        let seed = GoalEditSeed(profile: profile)

        XCTAssertEqual(seed.targetText, "1800")
        XCTAssertTrue(seed.manualOverride)
    }

    func testCalculatedProfileSeedsItsSavedTargetAndCalculatedMode() {
        let profile = makeProfile()
        OnboardingProfileSave.apply(
            makeSelections(calorieTarget: 2_133, isManualTarget: false),
            to: profile
        )

        let seed = GoalEditSeed(profile: profile)

        XCTAssertEqual(seed.targetText, "2133")
        XCTAssertFalse(seed.manualOverride)
    }

    func testSeedRecoversTheSavedMacroRatios() {
        let profile = makeProfile()
        OnboardingProfileSave.apply(
            makeSelections(calorieTarget: 1_800, isManualTarget: true),
            to: profile
        )

        let seed = GoalEditSeed(profile: profile)

        XCTAssertEqual(seed.proteinRatio, 0.30, accuracy: 0.001)
        XCTAssertEqual(seed.carbRatio, 0.40, accuracy: 0.001)
        XCTAssertEqual(seed.fatRatio, 0.30, accuracy: 0.001)
        XCTAssertEqual(seed.calorieDeficit, 500, accuracy: 0.001)
    }

    func testZeroTargetFallsBackToDefaultRatiosWithoutDividingByZero() {
        let profile = makeProfile()
        profile.dailyCalorieTarget = 0

        let seed = GoalEditSeed(profile: profile)

        XCTAssertEqual(seed.proteinRatio, 0.30, accuracy: 0.001)
        XCTAssertEqual(seed.carbRatio, 0.40, accuracy: 0.001)
        XCTAssertEqual(seed.fatRatio, 0.30, accuracy: 0.001)
    }

    // MARK: Helpers

    private func makeProfile() -> UserProfile {
        UserProfile(
            age: 30,
            sex: .male,
            heightCm: 178,
            weightKg: 78,
            activityLevel: .moderatelyActive
        )
    }

    private func makeSelections(
        calorieTarget: Int,
        isManualTarget: Bool
    ) -> OnboardingProfileSave.Selections {
        OnboardingProfileSave.Selections(
            age: 30,
            sex: .male,
            heightCm: 178,
            weightKg: 78,
            activityLevel: .moderatelyActive,
            energyCalculationMode: .lifestyleEstimate,
            calorieDeficit: 500,
            calorieTarget: calorieTarget,
            isManualTarget: isManualTarget,
            proteinRatio: 0.30,
            carbRatio: 0.40,
            fatRatio: 0.30
        )
    }
}
