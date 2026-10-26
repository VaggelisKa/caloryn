import Foundation

struct SettingsProfileSummary: Equatable {
    let age: Int
    let sex: Sex
    let heightCm: Double
    let weightKg: Double
    let activityLevel: ActivityLevel

    init(age: Int, sex: Sex, heightCm: Double, weightKg: Double, activityLevel: ActivityLevel) {
        self.age = age
        self.sex = sex
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.activityLevel = activityLevel
    }

    var ageText: String { "\(age)" }

    var sexText: String { sex.displayName }

    var heightText: String { "\(heightCm.truncatedSafely) cm" }

    var weightText: String { weightText(locale: .current) }

    func weightText(locale: Locale) -> String { weightKg.kilogramsFormatted(locale: locale) }

    var activityText: String { activityLevel.displayName.sentenceCased }
}
