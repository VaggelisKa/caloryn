import Foundation

struct GoalEditSeed: Equatable {
    var targetText: String
    var manualOverride: Bool
    var calorieDeficit: Double
    var proteinRatio: Double
    var carbRatio: Double
    var fatRatio: Double
    var proteinGramsText: String
    var carbGramsText: String
    var fatGramsText: String

    init(profile: UserProfile) {
        targetText = "\(profile.dailyCalorieTarget)"
        manualOverride = profile.manualOverride
        calorieDeficit = profile.calorieDeficit

        let ratios = profile.macroRatios
        proteinRatio = ratios.protein
        carbRatio = ratios.carbs
        fatRatio = ratios.fat
        proteinGramsText = MacroGramGoals.fieldText(forGrams: profile.proteinTargetG)
        carbGramsText = MacroGramGoals.fieldText(forGrams: profile.carbTargetG)
        fatGramsText = MacroGramGoals.fieldText(forGrams: profile.fatTargetG)
    }
}
