import XCTest
@testable import Caloryn

@MainActor
final class ProfileEditActivityLevelPolicyTests: XCTestCase {
    func testActivityLevelIsLockedWhenAutoAdjustIsEffective() {
        let profile = makeProfile(energyCalculationMode: .dynamicHealth)

        XCTAssertTrue(ProfileEditActivityLevelPolicy.isLocked(for: profile))
    }

    func testActivityLevelRemainsEditableForLifestyleEstimate() {
        let profile = makeProfile(energyCalculationMode: .lifestyleEstimate)

        XCTAssertFalse(ProfileEditActivityLevelPolicy.isLocked(for: profile))
    }

    func testManualOverrideDoesNotUseAppleHealthActivityLock() {
        let profile = makeProfile(
            dailyCalorieTarget: 2_100,
            manualOverride: true,
            energyCalculationMode: .dynamicHealth
        )

        XCTAssertFalse(ProfileEditActivityLevelPolicy.isLocked(for: profile))
    }

    private func makeProfile(
        dailyCalorieTarget: Int? = nil,
        manualOverride: Bool = false,
        energyCalculationMode: EnergyCalculationMode
    ) -> UserProfile {
        UserProfile(
            age: 35,
            sex: .male,
            heightCm: 180,
            weightKg: 80,
            activityLevel: .moderatelyActive,
            dailyCalorieTarget: dailyCalorieTarget,
            manualOverride: manualOverride,
            energyCalculationMode: energyCalculationMode
        )
    }
}
