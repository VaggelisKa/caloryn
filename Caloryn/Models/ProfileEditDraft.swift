import Foundation

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
