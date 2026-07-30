import Foundation

/// How the read-only Profile rows on the Settings screen render the stored
/// measurements: height whole, weight to one decimal, both in metric.
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

    /// Truncated, not rounded — the height slider only ever produces whole
    /// centimetres.
    var heightText: String { "\(heightCm.truncatedSafely) cm" }

    var weightText: String { String(format: "%.1f kg", weightKg) }

    var activityText: String { activityLevel.displayName }
}
