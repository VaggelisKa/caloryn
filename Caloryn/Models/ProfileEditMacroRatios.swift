import Foundation

/// The macro split the profile screen preserves when it saves.
///
/// Editing age, sex, height, weight or activity moves the calorie target, and
/// the macro grams have to be recomputed from it. Rather than keep the grams,
/// the screen derives the *ratios* the saved grams represent and re-applies
/// them to the new target, so the user's chosen split survives the edit.
struct ProfileEditMacroRatios: Equatable {
    let protein: Double
    let carbs: Double
    let fat: Double

    /// Falls back to the app's default 30/40/30 split when there is no calorie
    /// target to divide by, since every ratio would otherwise be undefined.
    init(dailyCalorieTarget: Int, proteinTargetG: Double, carbTargetG: Double, fatTargetG: Double) {
        let calories = Double(dailyCalorieTarget)
        protein = calories > 0 ? (proteinTargetG * 4.0) / calories : 0.30
        carbs = calories > 0 ? (carbTargetG * 4.0) / calories : 0.40
        fat = calories > 0 ? (fatTargetG * 9.0) / calories : 0.30
    }
}
