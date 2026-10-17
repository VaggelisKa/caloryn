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

    /// "At least 150 g", "66.7 g", "At most 2.300 mg", in the reader's locale. `locale`
    /// exists for tests.
    func text(for nutrient: TrackedNutrient, locale: Locale = .current) -> String {
        summary(for: nutrient) { nutrient.unit.formatted($0, locale: locale) }
    }

    /// VoiceOver reads the bare "g" in "66.7 g" as an unpronounceable glyph, so the
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

    /// The goal group's headline: "2.000 kcal a day". Grouped for the reader's locale, the
    /// way Today's caption ("kcal left of 2.000") and History's average group theirs, so the
    /// target reads the same here as there. `locale` exists for tests.
    static func dailyTargetText(_ dailyCalorieTarget: Int, locale: Locale = .current) -> String {
        "\(dailyCalorieTarget.formatted(.number.locale(locale))) kcal a day"
    }

    /// The line under the headline, which says where the number comes from.
    ///
    /// A manual target is not derived from a deficit, so it names no adjustment. Otherwise
    /// the stored deficit is said against the estimated burn: positive is under it, negative
    /// over it. "About", because the burn is itself an estimate. Truncated toward zero, not
    /// rounded: the slider steps in whole 50s, so a fraction can only come from stored data.
    /// Grouped for the reader's locale like the target above it ("About 1.000 under" in
    /// Danish). `locale` exists for tests.
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
