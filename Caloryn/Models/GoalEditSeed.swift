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

        let calories = Double(profile.dailyCalorieTarget)
        guard calories > 0 else {
            proteinRatio = 0.30
            carbRatio = 0.40
            fatRatio = 0.30
            return
        }
        proteinRatio = (profile.proteinTargetG * 4.0) / calories
        carbRatio = (profile.carbTargetG * 4.0) / calories
        fatRatio = (profile.fatTargetG * 9.0) / calories
    }
}
