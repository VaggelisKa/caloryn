import Foundation

struct GoalEditSeed: Equatable {
    var targetText: String
    var manualOverride: Bool
    var calorieDeficit: Double
    var proteinRatio: Double
    var carbRatio: Double
    var fatRatio: Double

    init(profile: UserProfile) {
        targetText = "\(profile.dailyCalorieTarget)"
        manualOverride = profile.manualOverride
        calorieDeficit = profile.calorieDeficit

        let ratios = profile.macroRatios
        proteinRatio = ratios.protein
        carbRatio = ratios.carbs
        fatRatio = ratios.fat
    }
}
