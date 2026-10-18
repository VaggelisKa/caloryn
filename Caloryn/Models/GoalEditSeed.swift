import Foundation

/// The initial editor state for the goal screen, derived from a saved profile.
///
/// Seeding happens at view construction rather than in `onAppear` so that
/// loading a manual profile is not mistaken for the user switching the manual
/// toggle on, which would replace the saved target with a fresh calculation.
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

        // The one derivation of a profile's split, so a stale split opens scaled back
        // to 100% and a non-finite gram value opens on the default.
        let ratios = profile.macroRatios
        proteinRatio = ratios.protein
        carbRatio = ratios.carbs
        fatRatio = ratios.fat
    }
}
