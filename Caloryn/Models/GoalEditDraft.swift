import Foundation

struct GoalEditDraft: Equatable {
    static let minimumManualTarget = 1_000

    static let macroTotalTolerance = 0.01

    var targetText: String
    var manualOverride: Bool
    var calorieDeficit: Double
    var proteinRatio: Double
    var carbRatio: Double
    var fatRatio: Double
    var proteinGramsText: String
    var carbGramsText: String
    var fatGramsText: String
    var nutrientTargetTexts: [TrackedNutrient: String] = [:]
    var nutrientGoalKinds: [TrackedNutrient: NutrientGoalKind] = [:]

    init(seed: GoalEditSeed) {
        targetText = seed.targetText
        manualOverride = seed.manualOverride
        calorieDeficit = seed.calorieDeficit
        proteinRatio = seed.proteinRatio
        carbRatio = seed.carbRatio
        fatRatio = seed.fatRatio
        proteinGramsText = seed.proteinGramsText
        carbGramsText = seed.carbGramsText
        fatGramsText = seed.fatGramsText
    }

    init(profile: UserProfile) {
        self.init(seed: GoalEditSeed(profile: profile))
    }

    var manualTarget: Int? { Int(targetText).map(CalorieDomain.clamped) }

    func calculatedTarget(tdee: Double) -> Int {
        NutritionCalculator.defaultTarget(tdee: tdee, deficit: calorieDeficit)
    }

    func effectiveCalorieTarget(tdee: Double) -> Int {
        let calculated = calculatedTarget(tdee: tdee)
        return manualOverride ? (manualTarget ?? calculated) : calculated
    }

    var macroTotal: Double { proteinRatio + carbRatio + fatRatio }

    var macroGramGoals: MacroGramGoals {
        MacroGramGoals(proteinText: proteinGramsText, carbText: carbGramsText, fatText: fatGramsText)
    }

    func proteinTargetGrams(tdee: Double) -> Double {
        directOrDerivedGrams(for: .protein, ratio: proteinRatio, caloriesPerGram: 4, tdee: tdee)
    }

    func carbTargetGrams(tdee: Double) -> Double {
        directOrDerivedGrams(for: .carbs, ratio: carbRatio, caloriesPerGram: 4, tdee: tdee)
    }

    func fatTargetGrams(tdee: Double) -> Double {
        directOrDerivedGrams(for: .fat, ratio: fatRatio, caloriesPerGram: 9, tdee: tdee)
    }

    func macroAccountSummary(tdee: Double, locale: Locale = .current) -> String? {
        macroGramGoals.accountSummary(calorieTarget: effectiveCalorieTarget(tdee: tdee), locale: locale)
    }

    private func directOrDerivedGrams(
        for macro: MacroRatioSelection.Macro,
        ratio: Double,
        caloriesPerGram: Double,
        tdee: Double
    ) -> Double {
        if manualOverride {
            return macroGramGoals.grams(for: macro) ?? 0
        }
        return macroGrams(ratio: ratio, caloriesPerGram: caloriesPerGram, tdee: tdee)
    }

    private func macroGrams(ratio: Double, caloriesPerGram: Double, tdee: Double) -> Double {
        NutritionCalculator.macroGrams(
            calories: Double(effectiveCalorieTarget(tdee: tdee)),
            ratio: ratio,
            caloriesPerGram: caloriesPerGram
        )
    }

    var isMacroValid: Bool {
        manualOverride ? macroGramGoals.isValid : abs(macroTotal - 1.0) <= Self.macroTotalTolerance
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

    func isInvalidTarget(for nutrient: TrackedNutrient) -> Bool {
        let text = trimmedText(for: nutrient)
        return !text.isEmpty && storedTarget(for: nutrient) == nil
    }

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

    var deficitLabel: String {
        let wholeDeficit = calorieDeficit.truncatedSafely
        if wholeDeficit > 0 {
            return "-\(wholeDeficit) kcal/day (lose weight)"
        } else if wholeDeficit < 0 {
            return "+\(abs(wholeDeficit)) kcal/day (gain weight)"
        }
        return "Maintenance (no change)"
    }

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

    mutating func manualOverrideChanged(to isManual: Bool, tdee: Double) {
        if isManual {
            let calories = Double(calculatedTarget(tdee: tdee))
            proteinGramsText = MacroGramGoals.fieldText(
                forGrams: NutritionCalculator.macroGrams(calories: calories, ratio: proteinRatio, caloriesPerGram: 4)
            )
            carbGramsText = MacroGramGoals.fieldText(
                forGrams: NutritionCalculator.macroGrams(calories: calories, ratio: carbRatio, caloriesPerGram: 4)
            )
            fatGramsText = MacroGramGoals.fieldText(
                forGrams: NutritionCalculator.macroGrams(calories: calories, ratio: fatRatio, caloriesPerGram: 9)
            )
            manualOverride = true
            targetText = "\(calculatedTarget(tdee: tdee))"
            return
        }

        if let snapped = macroGramGoals.snappedRatios() {
            proteinRatio = snapped.protein
            carbRatio = snapped.carbs
            fatRatio = snapped.fat
        }
        manualOverride = false
    }

    func apply(to profile: UserProfile) {
        profile.manualOverride = manualOverride
        profile.calorieDeficit = calorieDeficit

        if manualOverride {
            if let manualTarget {
                profile.dailyCalorieTarget = manualTarget
            }
            if let protein = resolvedMacroGrams(proteinGramsText, saved: profile.proteinTargetG),
               let carbs = resolvedMacroGrams(carbGramsText, saved: profile.carbTargetG),
               let fat = resolvedMacroGrams(fatGramsText, saved: profile.fatTargetG) {
                profile.proteinTargetG = protein
                profile.carbTargetG = carbs
                profile.fatTargetG = fat
            }
        }

        profile.recalculate(proteinRatio: proteinRatio, carbRatio: carbRatio, fatRatio: fatRatio)

        for nutrient in TrackedNutrient.editableGoalNutrients {
            profile.setGoalKind(goalKind(for: nutrient), for: nutrient)
            guard !isUnchangedGoal(for: nutrient, in: profile) else { continue }
            profile.setTarget(storedTarget(for: nutrient), for: nutrient)
        }
    }

    private func resolvedMacroGrams(_ text: String, saved: Double) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == MacroGramGoals.fieldText(forGrams: saved), MacroGramGoals.accepts(saved) {
            return saved
        }
        guard let value = trimmed.decimalInputValue, MacroGramGoals.accepts(value) else { return nil }
        return value
    }

    private func isUnchangedGoal(for nutrient: TrackedNutrient, in profile: UserProfile) -> Bool {
        guard let saved = profile.target(for: nutrient) else { return false }
        return trimmedText(for: nutrient) == nutrient.unit.inputFormatted(saved)
    }
}
