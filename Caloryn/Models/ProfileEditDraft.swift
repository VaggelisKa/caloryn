import Foundation

/// The editable state of the profile screen.
///
/// Carries the personal facts while the user edits and writes them back on
/// Save. Until `apply(to:)` runs, the profile is untouched — leaving the
/// screen without saving discards the edit, the same contract every other
/// editor in the app already keeps.
struct ProfileEditDraft: Equatable {
    var age: Int
    var sex: Sex
    var heightCm: Double
    var weightKg: Double
    var activityLevel: ActivityLevel

    init(age: Int, sex: Sex, heightCm: Double, weightKg: Double, activityLevel: ActivityLevel) {
        self.age = age
        self.sex = sex
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.activityLevel = activityLevel
    }

    init(profile: UserProfile) {
        self.init(
            age: profile.age,
            sex: profile.sex,
            heightCm: profile.heightCm,
            weightKg: profile.weightKg,
            activityLevel: profile.activityLevel
        )
    }

    /// Writes the edit back and recomputes the targets it invalidates.
    ///
    /// The macro ratios are read from the profile's saved targets *before*
    /// anything is written — the split the user chose is derived from the
    /// pre-edit numbers and re-applied to the new calorie target, so the
    /// proportions survive the edit exactly as they did when the view saved
    /// directly.
    func apply(to profile: UserProfile) {
        let ratios = profile.macroRatios

        profile.age = age
        profile.sex = sex
        profile.heightCm = heightCm
        profile.weightKg = weightKg
        profile.activityLevel = activityLevel

        profile.recalculate(
            proteinRatio: ratios.protein,
            carbRatio: ratios.carbs,
            fatRatio: ratios.fat
        )
    }
}
