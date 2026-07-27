import Foundation

/// The read-only goal rows on the Settings screen: which nutrients appear, and
/// what each row reads as.
///
/// Takes the saved targets and goal kinds as plain dictionaries rather than the
/// profile, so a row's wording can be checked without a store.
struct SettingsGoalSummary: Equatable {
    /// Shown when a nutrient has no saved goal. Unreachable from `nutrients`,
    /// which drops those, but kept so the lookup is total.
    static let notSetText = "Not set"

    let targets: [TrackedNutrient: Double]
    let goalKinds: [TrackedNutrient: NutrientGoalKind]

    init(targets: [TrackedNutrient: Double], goalKinds: [TrackedNutrient: NutrientGoalKind]) {
        self.targets = targets
        self.goalKinds = goalKinds
    }

    /// Only nutrients with a saved goal get a row, in the canonical order.
    var nutrients: [TrackedNutrient] {
        TrackedNutrient.allCases.filter { targets[$0] != nil }
    }

    func text(for nutrient: TrackedNutrient) -> String {
        summary(for: nutrient, formatter: nutrient.unit.formatted)
    }

    /// VoiceOver reads the bare "66.7g" as an unpronounceable glyph, so the
    /// spoken label spells the unit out.
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

    /// A manual target is not derived from a deficit, so there is no adjustment
    /// to show against it.
    static func showsAdjustmentRow(isManualOverride: Bool) -> Bool {
        !isManualOverride
    }

    /// A deficit is stored positive and displayed as a subtraction from the
    /// estimated burn; a surplus is the same number the other way round.
    static func adjustmentLabel(calorieDeficit: Double) -> String {
        if calorieDeficit > 0 {
            return "-\(Int(calorieDeficit)) kcal"
        } else if calorieDeficit < 0 {
            return "+\(Int(abs(calorieDeficit))) kcal"
        }

        return "Maintenance"
    }
}
