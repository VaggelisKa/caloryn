import XCTest
@testable import Caloryn

@MainActor
final class UserProfileTests: XCTestCase {
    func testInitialProfileComputesEnergyAndMacroTargets() {
        let profile = UserProfile(
            age: 30,
            sex: .female,
            heightCm: 165,
            weightKg: 70,
            activityLevel: .lightlyActive,
            calorieDeficit: 300,
            proteinRatio: 0.25,
            carbRatio: 0.45,
            fatRatio: 0.30
        )

        XCTAssertEqual(profile.bmr, 1_420.25, accuracy: 0.001)
        XCTAssertEqual(profile.tdee, 1_952.84375, accuracy: 0.001)
        XCTAssertEqual(profile.dailyCalorieTarget, 1_652)
        XCTAssertEqual(profile.proteinTargetG, 103.25, accuracy: 0.001)
        XCTAssertEqual(profile.carbTargetG, 185.85, accuracy: 0.001)
        XCTAssertEqual(profile.fatTargetG, 55.066, accuracy: 0.001)
    }

    func testRecalculatePreservesManualCalorieTargetButUpdatesMacros() {
        let profile = UserProfile(
            age: 40,
            sex: .male,
            heightCm: 180,
            weightKg: 80,
            activityLevel: .sedentary,
            dailyCalorieTarget: 1_800,
            manualOverride: true
        )
        let originalUpdatedAt = profile.updatedAt

        profile.weightKg = 90
        profile.activityLevel = .veryActive
        profile.calorieDeficit = 1_000
        profile.recalculate(proteinRatio: 0.20, carbRatio: 0.50, fatRatio: 0.30)

        XCTAssertEqual(profile.bmr, 1_830, accuracy: 0.001)
        XCTAssertEqual(profile.tdee, 3_156.75, accuracy: 0.001)
        XCTAssertEqual(profile.dailyCalorieTarget, 1_800)
        XCTAssertEqual(profile.proteinTargetG, 90, accuracy: 0.001)
        XCTAssertEqual(profile.carbTargetG, 225, accuracy: 0.001)
        XCTAssertEqual(profile.fatTargetG, 60, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(profile.updatedAt, originalUpdatedAt)
    }

    func testRecalculateUpdatesDefaultCalorieTargetWhenNotManual() {
        let profile = UserProfile(
            age: 35,
            sex: .male,
            heightCm: 175,
            weightKg: 75,
            activityLevel: .sedentary,
            calorieDeficit: 500
        )

        profile.weightKg = 95
        profile.activityLevel = .extraActive
        profile.calorieDeficit = 250
        profile.recalculate()

        XCTAssertEqual(profile.dailyCalorieTarget, 3_310)
    }

    func testActiveEnergyBaseTargetUsesRestingTargetForCalculatedProfiles() {
        let profile = UserProfile(
            age: 32,
            sex: .male,
            heightCm: 180,
            weightKg: 82,
            activityLevel: .veryActive,
            calorieDeficit: 400
        )

        XCTAssertEqual(profile.dailyCalorieTarget, 2_687)
        XCTAssertEqual(profile.calorieBaseTarget(usesActiveEnergy: false), 2_687)
        XCTAssertEqual(profile.calorieBaseTarget(usesActiveEnergy: true), 1_390)
    }

    func testActiveEnergyBaseTargetRespectsManualCalorieTargets() {
        let profile = UserProfile(
            age: 32,
            sex: .male,
            heightCm: 180,
            weightKg: 82,
            activityLevel: .veryActive,
            dailyCalorieTarget: 2_200,
            manualOverride: true,
            calorieDeficit: 400
        )

        XCTAssertEqual(profile.calorieBaseTarget(usesActiveEnergy: true), 2_200)
    }

    func testOptionalNutrientTargetsAreEnabledClampedAndRemovedThroughPublicAPI() {
        let profile = UserProfile(
            age: 35,
            sex: .male,
            heightCm: 175,
            weightKg: 75,
            activityLevel: .sedentary
        )

        XCTAssertNil(profile.target(for: .fiber))

        profile.setTarget(28, for: .fiber)
        XCTAssertEqual(profile.target(for: .fiber), 28)
        XCTAssertTrue(profile.isGoalEnabled(for: .fiber))
        XCTAssertEqual(profile.nutrientTargets[.fiber], 28)

        profile.setTarget(-10, for: .fiber)
        XCTAssertNil(profile.target(for: .fiber))
        XCTAssertFalse(profile.isGoalEnabled(for: .fiber))

        profile.setTarget(nil, for: .sugars)
        XCTAssertNil(profile.target(for: .sugars))
        XCTAssertFalse(profile.isGoalEnabled(for: .sugars))
    }

    func testGoalKindsFallbackToTheNutrientDefaultWhenStoredRawValueIsInvalid() {
        let profile = UserProfile(
            age: 35,
            sex: .male,
            heightCm: 175,
            weightKg: 75,
            activityLevel: .sedentary
        )

        profile.sodiumGoalKindRaw = "legacy"
        XCTAssertEqual(profile.goalKind(for: .sodium), .maximum)

        profile.setGoalKind(.minimum, for: .sodium)
        XCTAssertEqual(profile.goalKind(for: .sodium), .minimum)
    }
}
