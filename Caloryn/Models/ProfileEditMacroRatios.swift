import Foundation

/// The macro split a profile's saved grams represent.
///
/// Editing age, sex, height, weight or activity moves the calorie target, and
/// the macro grams have to be recomputed from it. Rather than keep the grams,
/// the app derives the *ratios* the saved grams represent and re-applies them
/// to the new target, so the user's chosen split survives the edit.
///
/// This is the only derivation of that quantity: `UserProfile.macroRatios`
/// delegates here, so the profile screen's Save and the dynamic nutrient
/// targets on Today can never disagree about what a profile's split is.
struct ProfileEditMacroRatios: Equatable {
    static let defaultSplit = ProfileEditMacroRatios(protein: 0.30, carbs: 0.40, fat: 0.30)

    let protein: Double
    let carbs: Double
    let fat: Double

    private init(protein: Double, carbs: Double, fat: Double) {
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
    }

    /// Falls back to the app's default 30/40/30 split when there is no calorie
    /// target to divide by, since every ratio would otherwise be undefined, and
    /// when a stored gram value is not a finite number.
    ///
    /// A split that claims *more* calories than the target is arithmetically
    /// impossible — it only happens when the grams went stale against a target
    /// that moved without them. Those ratios are scaled back down to total 1,
    /// which keeps the proportions the user chose exactly and corrects only the
    /// scale. A split totalling 1 or less is left alone: under-allocating is a
    /// legitimate thing to save, and rewriting it would change macro targets the
    /// user set deliberately.
    init(dailyCalorieTarget: Int, proteinTargetG: Double, carbTargetG: Double, fatTargetG: Double) {
        let calories = Double(dailyCalorieTarget)
        guard calories > 0 else {
            self = .defaultSplit
            return
        }

        let rawProtein = (proteinTargetG * 4.0) / calories
        let rawCarbs = (carbTargetG * 4.0) / calories
        let rawFat = (fatTargetG * 9.0) / calories
        let total = rawProtein + rawCarbs + rawFat

        guard total.isFinite else {
            self = .defaultSplit
            return
        }

        guard total > 1 else {
            self.init(protein: rawProtein, carbs: rawCarbs, fat: rawFat)
            return
        }

        self.init(protein: rawProtein / total, carbs: rawCarbs / total, fat: rawFat / total)
    }
}
