import XCTest
import SwiftData
@testable import Caloryn

@MainActor
final class OnboardingProfileSaveTests: XCTestCase {
    func testManualSelectionCanStoreGramGoalsThatDoNotFillTheCalorieTarget() {
        let profile = OnboardingProfileSave.makeProfile(
            from: makeSelections(
                calorieTarget: 1_800,
                isManualTarget: true,
                proteinGrams: 150,
                carbGrams: 180,
                fatGrams: 50
            )
        )

        XCTAssertEqual(profile.dailyCalorieTarget, 1_800)
        XCTAssertEqual(profile.proteinTargetG, 150, accuracy: 0.001)
        XCTAssertEqual(profile.carbTargetG, 180, accuracy: 0.001)
        XCTAssertEqual(profile.fatTargetG, 50, accuracy: 0.001)
        XCTAssertEqual(profile.nutrientTargets(forCalorieTarget: 2_200)[.protein] ?? 0, 150, accuracy: 0.001)
        XCTAssertEqual(profile.nutrientTargets(forCalorieTarget: 2_200)[.carbs] ?? 0, 180, accuracy: 0.001)
        XCTAssertEqual(profile.nutrientTargets(forCalorieTarget: 2_200)[.fat] ?? 0, 50, accuracy: 0.001)
    }

    func testManualSelectionPersistsTargetAndManualMode() {
        let profile = OnboardingProfileSave.makeProfile(
            from: makeSelections(calorieTarget: 1_800, isManualTarget: true)
        )

        XCTAssertEqual(profile.dailyCalorieTarget, 1_800)
        XCTAssertTrue(profile.manualOverride)
    }

    func testCalculatedSelectionPersistsCalculatedMode() {
        let profile = OnboardingProfileSave.makeProfile(
            from: makeSelections(calorieTarget: 2_100, isManualTarget: false)
        )

        XCTAssertEqual(profile.dailyCalorieTarget, 2_100)
        XCTAssertFalse(profile.manualOverride)
    }

    func testApplyingSelectionsToExistingProfileMatchesNewProfileSave() {
        let existing = UserProfile(
            age: 50,
            sex: .female,
            heightCm: 160,
            weightKg: 60,
            activityLevel: .sedentary
        )
        let selections = makeSelections(calorieTarget: 1_750, isManualTarget: true)

        OnboardingProfileSave.apply(selections, to: existing)
        let fresh = OnboardingProfileSave.makeProfile(from: selections)

        XCTAssertEqual(existing.age, fresh.age)
        XCTAssertEqual(existing.sex, fresh.sex)
        XCTAssertEqual(existing.heightCm, fresh.heightCm)
        XCTAssertEqual(existing.weightKg, fresh.weightKg)
        XCTAssertEqual(existing.activityLevel, fresh.activityLevel)
        XCTAssertEqual(existing.manualOverride, fresh.manualOverride)
        XCTAssertEqual(existing.calorieDeficit, fresh.calorieDeficit)
        XCTAssertEqual(existing.bmr, fresh.bmr, accuracy: 0.001)
        XCTAssertEqual(existing.tdee, fresh.tdee, accuracy: 0.001)
        XCTAssertEqual(existing.dailyCalorieTarget, fresh.dailyCalorieTarget)
        XCTAssertEqual(existing.proteinTargetG, fresh.proteinTargetG, accuracy: 0.001)
        XCTAssertEqual(existing.carbTargetG, fresh.carbTargetG, accuracy: 0.001)
        XCTAssertEqual(existing.fatTargetG, fresh.fatTargetG, accuracy: 0.001)
    }

    func testRecalculatePreservesManualOnboardingTarget() {
        let profile = OnboardingProfileSave.makeProfile(
            from: makeSelections(calorieTarget: 1_800, isManualTarget: true)
        )

        profile.weightKg = 95
        profile.recalculate()

        XCTAssertEqual(profile.dailyCalorieTarget, 1_800)
    }

    func testRecalculateReplacesCalculatedOnboardingTarget() {
        let profile = OnboardingProfileSave.makeProfile(
            from: makeSelections(calorieTarget: 2_100, isManualTarget: false)
        )

        profile.weightKg = 95
        profile.recalculate()

        XCTAssertEqual(
            profile.dailyCalorieTarget,
            NutritionCalculator.defaultTarget(tdee: profile.tdee, deficit: profile.calorieDeficit)
        )
    }

    func testReturningToCalculatedModeRestoresCalculatedTarget() {
        let profile = OnboardingProfileSave.makeProfile(
            from: makeSelections(calorieTarget: 1_800, isManualTarget: true)
        )

        profile.manualOverride = false
        profile.recalculate()

        XCTAssertEqual(
            profile.dailyCalorieTarget,
            NutritionCalculator.defaultTarget(tdee: profile.tdee, deficit: profile.calorieDeficit)
        )
    }

    func testManualOnboardingTargetSurvivesRelaunch() throws {
        let storeURL = URL.temporaryDirectory.appending(path: "onboarding-save-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: storeURL) }
        let configuration = ModelConfiguration(url: storeURL)

        do {
            let container = try ModelContainer(for: UserProfile.self, configurations: configuration)
            let context = ModelContext(container)
            context.insert(
                OnboardingProfileSave.makeProfile(
                    from: makeSelections(calorieTarget: 1_800, isManualTarget: true)
                )
            )
            try context.save()
        }

        let reopenedContainer = try ModelContainer(for: UserProfile.self, configurations: configuration)
        let reopenedContext = ModelContext(reopenedContainer)
        let profiles = try reopenedContext.fetch(FetchDescriptor<UserProfile>())

        XCTAssertEqual(profiles.count, 1)
        XCTAssertEqual(profiles.first?.dailyCalorieTarget, 1_800)
        XCTAssertEqual(profiles.first?.manualOverride, true)
    }

    private func makeSelections(
        calorieTarget: Int,
        isManualTarget: Bool,
        proteinGrams: Double? = nil,
        carbGrams: Double? = nil,
        fatGrams: Double? = nil
    ) -> OnboardingProfileSave.Selections {
        OnboardingProfileSave.Selections(
            age: 30,
            sex: .male,
            heightCm: 178,
            weightKg: 78,
            activityLevel: .moderatelyActive,
            calorieDeficit: 500,
            calorieTarget: calorieTarget,
            isManualTarget: isManualTarget,
            proteinRatio: 0.30,
            carbRatio: 0.40,
            fatRatio: 0.30,
            proteinGrams: proteinGrams,
            carbGrams: carbGrams,
            fatGrams: fatGrams
        )
    }
}
