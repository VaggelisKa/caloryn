import Foundation

struct SettingsGoalSummary: Equatable {
    static let notSetText = "Not set"

    let targets: [TrackedNutrient: Double]
    let goalKinds: [TrackedNutrient: NutrientGoalKind]

    init(targets: [TrackedNutrient: Double], goalKinds: [TrackedNutrient: NutrientGoalKind]) {
        self.targets = targets
        self.goalKinds = goalKinds
    }

    var nutrients: [TrackedNutrient] {
        TrackedNutrient.allCases.filter { targets[$0] != nil }
    }

    func text(for nutrient: TrackedNutrient, locale: Locale = .current) -> String {
        summary(for: nutrient) { nutrient.unit.formatted($0, locale: locale) }
    }

    func spokenText(for nutrient: TrackedNutrient) -> String {
        summary(for: nutrient, formatter: nutrient.unit.spokenFormatted)
    }

    private func summary(for nutrient: TrackedNutrient, formatter: (Double) -> String) -> String {
        guard let target = targets[nutrient] else { return Self.notSetText }
        let formattedTarget = formatter(target)

        switch goalKinds[nutrient, default: nutrient.defaultGoalKind] {
        case .minimum:
            return "At least \(formattedTarget)"
        case .target:
            return formattedTarget
        case .maximum:
            return "At most \(formattedTarget)"
        }
    }

    static func dailyTargetText(_ dailyCalorieTarget: Int, locale: Locale = .current) -> String {
        "\(dailyCalorieTarget.formatted(.number.locale(locale))) kcal a day"
    }

    static func goalSubtitle(
        calorieDeficit: Double,
        isManualOverride: Bool,
        locale: Locale = .current
    ) -> String {
        guard !isManualOverride else { return "A number you set yourself" }

        let amount = abs(calorieDeficit).truncatedSafely
        let amountText = amount.formatted(.number.locale(locale))
        if calorieDeficit > 0, amount > 0 {
            return "About \(amountText) under what you burn"
        } else if calorieDeficit < 0, amount > 0 {
            return "About \(amountText) over what you burn"
        }

        return "About what you burn"
    }
}
