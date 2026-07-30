import Foundation

/// The editable state of the goal screen, and every rule that acts on it.
///
/// `GoalEditSeed` produces the starting values; this carries them while the
/// user edits, answers what the screen needs to render, decides whether the
/// edit may be saved, and writes the result back to the profile. Keeping all of
/// that here rather than in `GoalEditView` means the rules are reachable
/// without driving a form.
struct GoalEditDraft: Equatable {
    /// Below this the manual target is rejected, since a target this low is
    /// far more likely to be a typo than an intent.
    static let minimumManualTarget = 1_000

    /// Ratios are stepped in 0.05 increments, so exact equality with 1.0 is
    /// not reachable through floating-point accumulation.
    static let macroTotalTolerance = 0.01

    var targetText: String
    var manualOverride: Bool
    var calorieDeficit: Double
    var proteinRatio: Double
    var carbRatio: Double
    var fatRatio: Double
    var nutrientTargetTexts: [TrackedNutrient: String] = [:]
    var nutrientGoalKinds: [TrackedNutrient: NutrientGoalKind] = [:]

    init(seed: GoalEditSeed) {
        targetText = seed.targetText
        manualOverride = seed.manualOverride
        calorieDeficit = seed.calorieDeficit
        proteinRatio = seed.proteinRatio
        carbRatio = seed.carbRatio
        fatRatio = seed.fatRatio
    }

    init(profile: UserProfile) {
        self.init(seed: GoalEditSeed(profile: profile))
    }

    // MARK: - Calorie target

    /// Clamped into `CalorieDomain`: this is a free-text field, and the typed
    /// number is saved onto the profile, then subtracted from and summed across
    /// a period by History.
    var manualTarget: Int? { Int(targetText).map(CalorieDomain.clamped) }

    func calculatedTarget(tdee: Double) -> Int {
        NutritionCalculator.defaultTarget(tdee: tdee, deficit: calorieDeficit)
    }

    /// The target the macro previews are computed from: the typed value while
    /// the manual toggle is on, otherwise the calculation. A manual target that
    /// does not parse falls back to the calculation so the previews stay
    /// populated while the field is being typed into.
    func effectiveCalorieTarget(tdee: Double) -> Int {
        let calculated = calculatedTarget(tdee: tdee)
        return manualOverride ? (manualTarget ?? calculated) : calculated
    }

    // MARK: - Macro previews

    var macroTotal: Double { proteinRatio + carbRatio + fatRatio }

    func proteinTargetGrams(tdee: Double) -> Double {
        macroGrams(ratio: proteinRatio, caloriesPerGram: 4, tdee: tdee)
    }

    func carbTargetGrams(tdee: Double) -> Double {
        macroGrams(ratio: carbRatio, caloriesPerGram: 4, tdee: tdee)
    }

    func fatTargetGrams(tdee: Double) -> Double {
        macroGrams(ratio: fatRatio, caloriesPerGram: 9, tdee: tdee)
    }

    private func macroGrams(ratio: Double, caloriesPerGram: Double, tdee: Double) -> Double {
        NutritionCalculator.macroGrams(
            calories: Double(effectiveCalorieTarget(tdee: tdee)),
            ratio: ratio,
            caloriesPerGram: caloriesPerGram
        )
    }

    // MARK: - Validation

    var isMacroValid: Bool {
        abs(macroTotal - 1.0) <= Self.macroTotalTolerance
    }

    var isManualTargetValid: Bool {
        !manualOverride || (manualTarget ?? 0) >= Self.minimumManualTarget
    }

    var areNutrientGoalsValid: Bool {
        TrackedNutrient.editableGoalNutrients.allSatisfy { !isInvalidTarget(for: $0) }
    }

    var canSave: Bool {
        isMacroValid && isManualTargetValid && areNutrientGoalsValid
    }

    /// A blank field is valid — it means "no goal for this nutrient" — so only
    /// text that is present but unparseable is flagged.
    func isInvalidTarget(for nutrient: TrackedNutrient) -> Bool {
        let text = trimmedText(for: nutrient)
        return !text.isEmpty && storedTarget(for: nutrient) == nil
    }

    /// The typed value converted to the unit the profile stores, or nil when
    /// the field is blank, unparseable, or not a positive number.
    func storedTarget(for nutrient: TrackedNutrient) -> Double? {
        // decimalInputValue accepts a decimal comma so the field behaves the
        // same for users whose keyboard produces one, and rejects the spellings
        // a keypad cannot produce — "1e3" was a saveable goal, and an infinity
        // reaches an Int(_:) conversion, which traps rather than throws. The
        // `> 0` guard below already excluded NaN, but not those.
        guard let input = trimmedText(for: nutrient).decimalInputValue, input > 0 else {
            return nil
        }

        return nutrient.unit.storedValue(fromInput: input)
    }

    func goalKind(for nutrient: TrackedNutrient) -> NutrientGoalKind {
        nutrientGoalKinds[nutrient, default: nutrient.defaultGoalKind]
    }

    func targetText(for nutrient: TrackedNutrient) -> String {
        nutrientTargetTexts[nutrient, default: ""]
    }

    private func trimmedText(for nutrient: TrackedNutrient) -> String {
        targetText(for: nutrient).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Labels

    var deficitLabel: String {
        if calorieDeficit > 0 {
            return "-\(calorieDeficit.truncatedSafely) kcal/day (lose weight)"
        } else if calorieDeficit < 0 {
            return "+\(abs(calorieDeficit).truncatedSafely) kcal/day (gain weight)"
        }
        return "Maintenance (no change)"
    }

    // MARK: - Profile round trip

    /// Reads the profile's saved nutrient goals into the editable fields.
    mutating func loadNutrientGoals(from profile: UserProfile) {
        for nutrient in TrackedNutrient.editableGoalNutrients {
            if let target = profile.target(for: nutrient) {
                nutrientTargetTexts[nutrient] = nutrient.unit.inputFormatted(target)
            } else {
                nutrientTargetTexts[nutrient] = ""
            }
            nutrientGoalKinds[nutrient] = profile.goalKind(for: nutrient)
        }
    }

    /// Turning the manual toggle on pre-fills the field with the current
    /// calculation, so the user adjusts a real number instead of whatever was
    /// last typed.
    mutating func manualOverrideChanged(to isManual: Bool, tdee: Double) {
        manualOverride = isManual
        guard isManual else { return }
        targetText = "\(calculatedTarget(tdee: tdee))"
    }

    /// Writes the edit back. Saving a manual target also drops the profile out
    /// of any dynamic energy mode, because a hand-picked number should not then
    /// be moved by Apple Health.
    func apply(to profile: UserProfile) {
        profile.manualOverride = manualOverride
        profile.calorieDeficit = calorieDeficit

        if manualOverride, let manualTarget {
            profile.dailyCalorieTarget = manualTarget
            profile.energyCalculationMode = .lifestyleEstimate
        }

        profile.recalculate(proteinRatio: proteinRatio, carbRatio: carbRatio, fatRatio: fatRatio)

        for nutrient in TrackedNutrient.editableGoalNutrients {
            profile.setGoalKind(goalKind(for: nutrient), for: nutrient)
            profile.setTarget(storedTarget(for: nutrient), for: nutrient)
        }
    }

    /// Whether saving this draft should also switch Apple Health adjustment
    /// off. Separated from `apply(to:)` so the write to the profile stays free
    /// of the global settings side effect.
    var disablesAppleHealthAdjustment: Bool {
        manualOverride && manualTarget != nil
    }
}
