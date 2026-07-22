import Foundation

enum OnboardingProfileSave {
    struct Selections {
        var age: Int
        var sex: Sex
        var heightCm: Double
        var weightKg: Double
        var activityLevel: ActivityLevel
        var energyCalculationMode: EnergyCalculationMode
        var calorieDeficit: Double
        var calorieTarget: Int
        var isManualTarget: Bool
        var proteinRatio: Double
        var carbRatio: Double
        var fatRatio: Double
    }

    static func makeProfile(from selections: Selections) -> UserProfile {
        let profile = UserProfile(
            age: selections.age,
            sex: selections.sex,
            heightCm: selections.heightCm,
            weightKg: selections.weightKg,
            activityLevel: selections.activityLevel
        )
        apply(selections, to: profile)
        return profile
    }

    static func apply(_ selections: Selections, to profile: UserProfile) {
        profile.age = selections.age
        profile.sex = selections.sex
        profile.heightCm = selections.heightCm
        profile.weightKg = selections.weightKg
        profile.activityLevel = selections.activityLevel
        profile.energyCalculationMode = selections.isManualTarget ? .lifestyleEstimate : selections.energyCalculationMode
        profile.manualOverride = selections.isManualTarget
        profile.calorieDeficit = selections.calorieDeficit
        profile.bmr = NutritionCalculator.bmr(
            sex: selections.sex,
            weightKg: selections.weightKg,
            heightCm: selections.heightCm,
            age: selections.age
        )
        profile.tdee = NutritionCalculator.tdee(bmr: profile.bmr, activity: selections.activityLevel)
        profile.dailyCalorieTarget = selections.calorieTarget
        profile.proteinTargetG = NutritionCalculator.macroGrams(calories: Double(selections.calorieTarget), ratio: selections.proteinRatio, caloriesPerGram: 4)
        profile.carbTargetG = NutritionCalculator.macroGrams(calories: Double(selections.calorieTarget), ratio: selections.carbRatio, caloriesPerGram: 4)
        profile.fatTargetG = NutritionCalculator.macroGrams(calories: Double(selections.calorieTarget), ratio: selections.fatRatio, caloriesPerGram: 9)
        profile.updatedAt = Date()
    }
}
