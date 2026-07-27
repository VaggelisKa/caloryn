import Testing
@testable import Caloryn

/// Covers the rules the goal editor applies, which until now were only
/// reachable by driving the form.
@MainActor
@Suite("Goal edit draft")
struct GoalEditDraftTests {

    // MARK: - Which target the previews use

    @Test("Without a manual override the target comes from the calculation, not the typed text")
    func calculatedTargetIgnoresTypedText() {
        var draft = makeDraft()
        draft.manualOverride = false
        draft.targetText = "9999"

        #expect(draft.effectiveCalorieTarget(tdee: tdee) == draft.calculatedTarget(tdee: tdee))
    }

    @Test("With a manual override the typed target wins")
    func manualTargetWins() {
        var draft = makeDraft()
        draft.manualOverride = true
        draft.targetText = "1800"

        #expect(draft.effectiveCalorieTarget(tdee: tdee) == 1_800)
    }

    @Test("A manual target that does not parse falls back to the calculation")
    func unparseableManualTargetFallsBack() {
        var draft = makeDraft()
        draft.manualOverride = true
        draft.targetText = ""

        #expect(draft.effectiveCalorieTarget(tdee: tdee) == draft.calculatedTarget(tdee: tdee))
    }

    @Test("A larger deficit lowers the calculated target")
    func deficitLowersTarget() {
        var lean = makeDraft()
        lean.calorieDeficit = 500
        var maintenance = makeDraft()
        maintenance.calorieDeficit = 0

        #expect(lean.calculatedTarget(tdee: tdee) < maintenance.calculatedTarget(tdee: tdee))
    }

    // MARK: - Macro previews

    @Test("Macro previews reconcile back to the effective target")
    func macroPreviewsReconcileToTarget() {
        var draft = makeDraft()
        draft.manualOverride = true
        draft.targetText = "2000"
        draft.proteinRatio = 0.30
        draft.carbRatio = 0.40
        draft.fatRatio = 0.30

        let calories = draft.proteinTargetGrams(tdee: tdee) * 4
            + draft.carbTargetGrams(tdee: tdee) * 4
            + draft.fatTargetGrams(tdee: tdee) * 9

        #expect(abs(calories - 2_000) < 1)
    }

    @Test("Editing the manual target moves the macro previews with it")
    func macroPreviewsFollowTheTarget() {
        var small = makeDraft()
        small.manualOverride = true
        small.targetText = "1500"

        var large = small
        large.targetText = "3000"

        #expect(large.proteinTargetGrams(tdee: tdee) > small.proteinTargetGrams(tdee: tdee))
    }

    // MARK: - Save gating

    @Test("Ratios that do not total 100% block saving")
    func lopsidedRatiosBlockSaving() {
        var draft = makeDraft()
        draft.proteinRatio = 0.50
        draft.carbRatio = 0.50
        draft.fatRatio = 0.50

        #expect(!draft.isMacroValid)
        #expect(!draft.canSave)
    }

    /// The sliders step in 0.05, so every total the user can actually reach is
    /// a sum of three such steps. Accumulated floating-point error across three
    /// additions stays far inside the tolerance, which is what makes the check
    /// workable at all.
    @Test(
        "Every combination the sliders can produce that sums to 100% validates",
        arguments: [
            (0.30, 0.40, 0.30),
            (0.10, 0.60, 0.30),
            (0.50, 0.10, 0.40),
            (0.35, 0.45, 0.20),
            (0.15, 0.35, 0.50)
        ]
    )
    func reachableRatioCombinationsValidate(protein: Double, carbs: Double, fat: Double) {
        var draft = makeDraft()
        draft.proteinRatio = protein
        draft.carbRatio = carbs
        draft.fatRatio = fat

        #expect(draft.isMacroValid)
    }

    /// The tolerance is `<= 0.01` against a Double, and 0.99 is stored as
    /// slightly less than 0.99 — so a total exactly one tolerance away is
    /// rejected. Recorded rather than fixed: the sliders cannot produce it, and
    /// widening the tolerance would let genuinely wrong totals through.
    @Test("A total exactly one tolerance from 100% is rejected")
    func exactToleranceBoundaryIsRejected() {
        var draft = makeDraft()
        draft.proteinRatio = 0.99
        draft.carbRatio = 0
        draft.fatRatio = 0

        #expect(!draft.isMacroValid)
    }

    @Test(
        "A manual target below the floor blocks saving",
        arguments: ["999", "0", "", "abc"]
    )
    func lowManualTargetsBlockSaving(text: String) {
        var draft = makeDraft()
        draft.manualOverride = true
        draft.targetText = text

        #expect(!draft.isManualTargetValid)
        #expect(!draft.canSave)
    }

    @Test("The same low text does not block saving when the override is off")
    func lowTextIsIrrelevantWithoutOverride() {
        var draft = makeDraft()
        draft.manualOverride = false
        draft.targetText = "12"

        #expect(draft.isManualTargetValid)
        #expect(draft.canSave)
    }

    // MARK: - Nutrient goals

    @Test("A blank nutrient field means no goal rather than an error")
    func blankNutrientFieldIsValid() {
        var draft = makeDraft()
        draft.nutrientTargetTexts[.fiber] = "   "

        #expect(!draft.isInvalidTarget(for: .fiber))
        #expect(draft.storedTarget(for: .fiber) == nil)
        #expect(draft.areNutrientGoalsValid)
    }

    @Test(
        "Nutrient goals must be positive numbers",
        arguments: ["0", "-5", "abc", "1.2.3"]
    )
    func nonPositiveNutrientGoalsAreInvalid(text: String) {
        var draft = makeDraft()
        draft.nutrientTargetTexts[.fiber] = text

        #expect(draft.isInvalidTarget(for: .fiber))
        #expect(!draft.areNutrientGoalsValid)
        #expect(!draft.canSave)
    }

    @Test("A decimal comma is accepted, so the field works on comma keyboards")
    func decimalCommaIsAccepted() {
        var draft = makeDraft()
        draft.nutrientTargetTexts[.fiber] = "27,5"

        let comma = draft.storedTarget(for: .fiber)
        draft.nutrientTargetTexts[.fiber] = "27.5"
        let period = draft.storedTarget(for: .fiber)

        #expect(comma != nil)
        #expect(comma == period)
    }

    @Test(
        "Text a decimal keypad cannot produce is not a goal",
        arguments: ["1e3", "1E3", "0x1p4", "inf", "-inf", "nan", "NaN", "1_000", String(repeating: "9", count: 400)]
    )
    func spellingsTheKeypadCannotProduceAreRejected(text: String) {
        var draft = makeDraft()
        draft.nutrientTargetTexts[.fiber] = text

        #expect(draft.storedTarget(for: .fiber) == nil)
        #expect(draft.isInvalidTarget(for: .fiber))
    }

    @Test("Surrounding whitespace does not invalidate a goal")
    func whitespaceIsTrimmed() {
        var draft = makeDraft()
        draft.nutrientTargetTexts[.fiber] = "  30  "

        #expect(!draft.isInvalidTarget(for: .fiber))
        #expect(draft.storedTarget(for: .fiber) == 30)
    }

    @Test("A nutrient with no explicit kind reports its default")
    func goalKindFallsBackToTheDefault() {
        let draft = makeDraft()

        for nutrient in TrackedNutrient.editableGoalNutrients {
            #expect(draft.goalKind(for: nutrient) == nutrient.defaultGoalKind)
        }
    }

    // MARK: - Profile round trip

    @Test("Loading then saving leaves a profile's nutrient goals unchanged")
    func nutrientGoalsSurviveARoundTrip() {
        let profile = makeProfile()
        profile.setTarget(30, for: .fiber)
        // Deliberately not fiber's default kind, so a round trip that silently
        // reset to the default would be visible.
        profile.setGoalKind(.maximum, for: .fiber)

        var draft = GoalEditDraft(profile: profile)
        draft.loadNutrientGoals(from: profile)
        draft.apply(to: profile)

        #expect(profile.target(for: .fiber) == 30)
        #expect(profile.goalKind(for: .fiber) == .maximum)
    }

    @Test("Clearing a nutrient field removes that goal from the profile")
    func clearingAFieldRemovesTheGoal() {
        let profile = makeProfile()
        profile.setTarget(30, for: .fiber)

        var draft = GoalEditDraft(profile: profile)
        draft.loadNutrientGoals(from: profile)
        draft.nutrientTargetTexts[.fiber] = ""
        draft.apply(to: profile)

        #expect(profile.target(for: .fiber) == nil)
    }

    @Test("Saving a manual target stores it and drops the profile out of dynamic energy")
    func savingAManualTargetPinsTheProfile() {
        let profile = makeProfile()
        profile.energyCalculationMode = .dynamicHealth

        var draft = GoalEditDraft(profile: profile)
        draft.manualOverride = true
        draft.targetText = "1750"
        draft.apply(to: profile)

        #expect(profile.dailyCalorieTarget == 1_750)
        #expect(profile.manualOverride)
        #expect(profile.energyCalculationMode == .lifestyleEstimate)
        #expect(draft.disablesAppleHealthAdjustment)
    }

    @Test("Saving without a manual override leaves the energy mode alone")
    func savingCalculatedLeavesTheModeAlone() {
        let profile = makeProfile()
        profile.energyCalculationMode = .dynamicHealth

        var draft = GoalEditDraft(profile: profile)
        draft.manualOverride = false
        draft.apply(to: profile)

        #expect(profile.energyCalculationMode == .dynamicHealth)
        #expect(!draft.disablesAppleHealthAdjustment)
    }

    @Test("Turning the manual toggle on pre-fills the field with the current calculation")
    func togglingManualSeedsTheField() {
        var draft = makeDraft()
        draft.targetText = "stale"

        draft.manualOverrideChanged(to: true, tdee: tdee)

        #expect(draft.targetText == "\(draft.calculatedTarget(tdee: tdee))")
        #expect(draft.isManualTargetValid)
    }

    @Test("Turning the manual toggle off leaves the typed text untouched")
    func togglingOffKeepsTheText() {
        var draft = makeDraft()
        draft.targetText = "1800"

        draft.manualOverrideChanged(to: false, tdee: tdee)

        #expect(draft.targetText == "1800")
    }

    // MARK: - Labels

    @Test(
        "The adjustment label names the direction the deficit moves weight",
        arguments: [
            (500.0, "-500 kcal/day (lose weight)"),
            (-300.0, "+300 kcal/day (gain weight)"),
            (0.0, "Maintenance (no change)")
        ]
    )
    func deficitLabelDescribesTheDirection(deficit: Double, expected: String) {
        var draft = makeDraft()
        draft.calorieDeficit = deficit

        #expect(draft.deficitLabel == expected)
    }

    // MARK: - Helpers

    private var tdee: Double { 2_500 }

    private func makeProfile() -> UserProfile {
        UserProfile(
            age: 30,
            sex: .male,
            heightCm: 178,
            weightKg: 78,
            activityLevel: .moderatelyActive
        )
    }

    private func makeDraft() -> GoalEditDraft {
        GoalEditDraft(profile: makeProfile())
    }
}
