import Foundation
import Testing
@testable import Caloryn

private func isNear(_ lhs: Double?, _ rhs: Double, tolerance: Double = 1e-9) -> Bool {
    guard let lhs else { return false }
    return abs(lhs - rhs) <= tolerance * max(1, abs(lhs), abs(rhs))
}

@MainActor
private func manualProfile(
    target: Int,
    protein: Double = 0.30,
    carbs: Double = 0.40,
    fat: Double = 0.30
) -> UserProfile {
    UserProfile(
        age: 30,
        sex: .male,
        heightCm: 180,
        weightKg: 80,
        activityLevel: .sedentary,
        dailyCalorieTarget: target,
        manualOverride: true,
        proteinRatio: protein,
        carbRatio: carbs,
        fatRatio: fat
    )
}

@MainActor
@Suite("User profile nutrient targets")
struct UserProfileNutrientTargetCoverageTests {
    @Test("Without a calorie figure the targets are the saved macros alone")
    func savedTargetsWithoutACalorieFigure() {
        let profile = manualProfile(target: 2_000)
        let targets = profile.nutrientTargets(forCalorieTarget: nil)

        #expect(Set(targets.keys) == [.protein, .carbs, .fat])
        #expect(isNear(targets[.protein], 150))
        #expect(isNear(targets[.carbs], 200))
        #expect(isNear(targets[.fat], 66.666_666_666_666_67))
        #expect(targets == profile.nutrientTargets)
    }

    @Test("A calorie figure re-applies the default split to it")
    func defaultSplitScalesToANewFigure() {
        let targets = manualProfile(target: 2_000).nutrientTargets(forCalorieTarget: 2_400)

        #expect(isNear(targets[.protein], 180))
        #expect(isNear(targets[.carbs], 240))
        #expect(isNear(targets[.fat], 80))
    }

    @Test("A calorie figure re-applies the user's own split, not the default one")
    func customSplitScalesToANewFigure() {
        let profile = manualProfile(target: 1_800, protein: 0.35, carbs: 0.35, fat: 0.30)
        #expect(isNear(profile.proteinTargetG, 157.5))
        #expect(isNear(profile.fatTargetG, 60))

        let targets = profile.nutrientTargets(forCalorieTarget: 2_200)

        #expect(isNear(targets[.protein], 192.5))
        #expect(isNear(targets[.carbs], 192.5))
        #expect(isNear(targets[.fat], 73.333_333_333_333_33))
    }

    @Test("Grams that claim more than the saved target scale with their proportions intact")
    func staleGramsKeepTheirProportions() {
        let profile = manualProfile(target: 1_000)
        profile.setTarget(150, for: .protein)
        profile.setTarget(150, for: .carbs)
        profile.setTarget(50, for: .fat)

        let atSavedTotal = profile.nutrientTargets(forCalorieTarget: 1_650)
        #expect(isNear(atSavedTotal[.protein], 150))
        #expect(isNear(atSavedTotal[.carbs], 150))
        #expect(isNear(atSavedTotal[.fat], 50))

        let doubled = profile.nutrientTargets(forCalorieTarget: 3_300)
        #expect(isNear(doubled[.protein], 300))
        #expect(isNear(doubled[.carbs], 300))
        #expect(isNear(doubled[.fat], 100))
    }

    @Test("A profile with no saved target scales the default 30/40/30 split")
    func zeroSavedTargetFallsBackToTheDefaultSplit() {
        let profile = manualProfile(target: 0)

        #expect(profile.nutrientTargets.isEmpty)

        let targets = profile.nutrientTargets(forCalorieTarget: 2_000)
        #expect(isNear(targets[.protein], 150))
        #expect(isNear(targets[.carbs], 200))
        #expect(isNear(targets[.fat], 66.666_666_666_666_67))
    }

    @Test("Enabled optional goals pass through a calorie figure unchanged, disabled ones stay out")
    func optionalGoalsSurviveTheCalorieFigure() {
        let profile = manualProfile(target: 2_000)
        profile.setTarget(30, for: .fiber)
        profile.setTarget(2.3, for: .sodium)

        let targets = profile.nutrientTargets(forCalorieTarget: 2_400)

        #expect(Set(targets.keys) == [.protein, .carbs, .fat, .fiber, .sodium])
        #expect(targets[.fiber] == 30)
        #expect(targets[.sodium] == 2.3)
        #expect(targets[.sugars] == nil)
    }

    @Test("A zero calorie figure writes zero macro targets rather than leaving them out")
    func zeroCalorieFigureWritesZeroMacros() {
        let targets = manualProfile(target: 2_000).nutrientTargets(forCalorieTarget: 0)

        #expect(targets[.protein] == 0)
        #expect(targets[.carbs] == 0)
        #expect(targets[.fat] == 0)
    }

    @Test("Setting one nutrient's target touches no other nutrient", arguments: TrackedNutrient.allCases)
    func setTargetIsIndependent(nutrient: TrackedNutrient) {
        let profile = manualProfile(target: 2_000)
        let before = profile.nutrientTargets

        profile.setTarget(42, for: nutrient)

        #expect(profile.target(for: nutrient) == 42)
        #expect(profile.isGoalEnabled(for: nutrient))
        for other in TrackedNutrient.allCases where other != nutrient {
            #expect(profile.target(for: other) == before[other], "\(other) moved when \(nutrient) was set")
        }
    }

    @Test(
        "A macro target cleared or set negative is stored as zero and stops being a target",
        arguments: [TrackedNutrient.protein, .carbs, .fat]
    )
    func macroTargetClears(nutrient: TrackedNutrient) {
        let profile = manualProfile(target: 2_000)

        profile.setTarget(-20, for: nutrient)
        #expect(profile.target(for: nutrient) == nil)
        #expect(profile.nutrientTargets[nutrient] == nil)
        #expect(profile.isGoalEnabled(for: nutrient))
        #expect(profile.nutrientTargets(forCalorieTarget: 2_000)[nutrient] == 0)

        profile.setTarget(90, for: nutrient)
        #expect(profile.target(for: nutrient) == 90)

        profile.setTarget(nil, for: nutrient)
        #expect(profile.target(for: nutrient) == nil)
    }

    @Test(
        "An optional goal is enabled by a positive target and disabled by zero",
        arguments: TrackedNutrient.editableGoalNutrients
    )
    func optionalGoalEnablement(nutrient: TrackedNutrient) {
        let profile = manualProfile(target: 2_000)
        #expect(profile.isGoalEnabled(for: nutrient) == false)
        #expect(profile.target(for: nutrient) == nil)

        profile.setTarget(12.5, for: nutrient)
        #expect(profile.isGoalEnabled(for: nutrient))
        #expect(profile.nutrientTargets[nutrient] == 12.5)

        profile.setTarget(0, for: nutrient)
        #expect(profile.isGoalEnabled(for: nutrient) == false)
        #expect(profile.nutrientTargets[nutrient] == nil)
    }

    @Test("A fresh profile carries each nutrient's default goal kind")
    func defaultGoalKinds() {
        let kinds = manualProfile(target: 2_000).nutrientGoalKinds

        #expect(kinds == [
            .protein: .minimum,
            .carbs: .target,
            .fat: .target,
            .fiber: .minimum,
            .sugars: .maximum,
            .addedSugars: .maximum,
            .saturatedFat: .maximum,
            .sodium: .maximum,
            .cholesterol: .maximum,
            .alcohol: .maximum,
        ])
    }

    @Test(
        "Every goal kind can be stored and read back for every nutrient",
        arguments: TrackedNutrient.allCases, NutrientGoalKind.allCases
    )
    func goalKindRoundTrips(nutrient: TrackedNutrient, kind: NutrientGoalKind) {
        let profile = manualProfile(target: 2_000)

        profile.setGoalKind(kind, for: nutrient)

        #expect(profile.goalKind(for: nutrient) == kind)
        #expect(profile.nutrientGoalKinds[nutrient] == kind)
    }

    @Test("Changing one nutrient's goal kind leaves every other at its default", arguments: TrackedNutrient.allCases)
    func goalKindIsIndependent(nutrient: TrackedNutrient) {
        let profile = manualProfile(target: 2_000)
        let changed: NutrientGoalKind = nutrient.defaultGoalKind == .maximum ? .minimum : .maximum

        profile.setGoalKind(changed, for: nutrient)

        for other in TrackedNutrient.allCases where other != nutrient {
            #expect(profile.goalKind(for: other) == other.defaultGoalKind, "\(other) moved when \(nutrient) was set")
        }
    }

    @Test("An unreadable stored goal kind falls back to that nutrient's own default")
    func unreadableGoalKindFallsBack() {
        let profile = manualProfile(target: 2_000)
        profile.proteinGoalKindRaw = ""
        profile.carbGoalKindRaw = "legacy"
        // Close to a real kind, but not one: a lenient parse would read it as `.minimum`.
        profile.alcoholGoalKindRaw = "minimum "

        #expect(profile.goalKind(for: .protein) == .minimum)
        #expect(profile.goalKind(for: .carbs) == .target)
        #expect(profile.goalKind(for: .alcohol) == .maximum)
    }

    @Test("An empty body recalculates onto the 1200 kcal floor and its macros")
    func emptyBodyRecalculatesOntoTheFloor() {
        let profile = UserProfile(age: 0, sex: .female, heightCm: 0, weightKg: 0, activityLevel: .extraActive)

        #expect(isNear(profile.bmr, -161))
        #expect(isNear(profile.tdee, -305.9))
        #expect(profile.dailyCalorieTarget == 1_200)
        #expect(isNear(profile.proteinTargetG, 90))
        #expect(isNear(profile.carbTargetG, 120))
        #expect(isNear(profile.fatTargetG, 40))
        #expect(profile.calorieBaseTarget(usesActiveEnergy: true) == 1_200)
    }

    @Test("An absurd body clamps the target to the calorie ceiling and derives macros from that")
    func absurdBodyClampsToTheCeiling() {
        let profile = UserProfile(age: 0, sex: .male, heightCm: 0, weightKg: 1e12, activityLevel: .sedentary)

        #expect(profile.dailyCalorieTarget == CalorieDomain.maximum)
        #expect(isNear(profile.proteinTargetG, 75_000_000))
        #expect(isNear(profile.carbTargetG, 100_000_000))
        #expect(isNear(profile.fatTargetG, 33_333_333.333_333_33))
    }

    @Test("Recalculating after the body changes applies the new deficit to the new TDEE")
    func recalculateWithANewBody() {
        let profile = UserProfile(age: 30, sex: .female, heightCm: 165, weightKg: 70, activityLevel: .sedentary)
        profile.age = 29
        profile.weightKg = 72.5
        profile.heightCm = 178.5
        profile.activityLevel = .veryActive
        profile.calorieDeficit = 250
        profile.recalculate(proteinRatio: 0.25, carbRatio: 0.45, fatRatio: 0.30)

        #expect(isNear(profile.bmr, 1_534.625))
        #expect(isNear(profile.tdee, 2_647.228125))
        #expect(profile.dailyCalorieTarget == 2_397)
        #expect(isNear(profile.proteinTargetG, 149.8125))
        #expect(isNear(profile.carbTargetG, 269.6625))
        #expect(isNear(profile.fatTargetG, 79.9))
        #expect(profile.calorieBaseTarget(usesActiveEnergy: true) == 1_284)
        #expect(profile.calorieBaseTarget(usesActiveEnergy: false) == 2_397)
    }

    @Test("A manual target forces the activity-level estimate even when auto-adjust is chosen")
    func manualTargetForcesTheEstimate() {
        let profile = UserProfile(
            age: 30, sex: .male, heightCm: 180, weightKg: 80, activityLevel: .sedentary,
            dailyCalorieTarget: 2_000, manualOverride: true, energyCalculationMode: .dynamicHealth
        )
        #expect(profile.energyCalculationMode == .dynamicHealth)
        #expect(profile.effectiveEnergyCalculationMode == .lifestyleEstimate)

        profile.manualOverride = false
        #expect(profile.effectiveEnergyCalculationMode == .dynamicHealth)
    }

    @Test("An unreadable stored mode reads as the activity-level estimate, and setting it stores the raw value")
    func unreadableModeFallsBack() {
        let profile = manualProfile(target: 2_000)
        profile.energyCalculationModeRaw = "legacy"
        #expect(profile.energyCalculationMode == .lifestyleEstimate)

        profile.energyCalculationMode = .dynamicHealth
        #expect(profile.energyCalculationModeRaw == "dynamicHealth")
    }

    @Test("The budget a manual profile hands Today is the static target, whatever mode was chosen")
    func manualProfileBudgetIsStatic() {
        let profile = UserProfile(
            age: 30, sex: .male, heightCm: 180, weightKg: 80, activityLevel: .sedentary,
            dailyCalorieTarget: 2_150, manualOverride: true, energyCalculationMode: .dynamicHealth
        )

        let budget = profile.activityBudget(
            consumed: 1_000.4,
            activeEnergyKcal: 600,
            recentActiveEnergySamples: [],
            isActivityLoading: false,
            activityMessage: nil,
            date: Date(timeIntervalSince1970: 1_760_000_000)
        )

        #expect(budget.dynamicStatus == .staticEstimate)
        #expect(budget.adjustedTarget == 2_150)
        #expect(budget.remaining == 1_150)
    }

    @Test("An auto-adjust profile without activity history hands Today a learning budget on its own target")
    func autoAdjustProfileWithoutHistoryIsLearning() {
        let profile = UserProfile(
            age: 30, sex: .male, heightCm: 180, weightKg: 80, activityLevel: .sedentary,
            energyCalculationMode: .dynamicHealth
        )
        #expect(profile.dailyCalorieTarget == 1_636)

        let budget = profile.activityBudget(
            consumed: 0,
            activeEnergyKcal: 0,
            recentActiveEnergySamples: [],
            isActivityLoading: false,
            activityMessage: nil,
            date: Date(timeIntervalSince1970: 1_760_000_000)
        )

        #expect(budget.dynamicStatus == .learning(validDays: 0, requiredDays: 7))
        #expect(budget.adjustedTarget == 1_636)
    }
}
