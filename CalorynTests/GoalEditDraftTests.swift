import Foundation
import Testing
@testable import Caloryn

@MainActor
@Suite("Goal edit draft")
struct GoalEditDraftTests {
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

    @Test("Macro previews reconcile back to the effective target")
    func macroPreviewsReconcileToTarget() {
        var draft = makeDraft()
        draft.manualOverride = false
        draft.proteinRatio = 0.30
        draft.carbRatio = 0.40
        draft.fatRatio = 0.30

        let calories = draft.proteinTargetGrams(tdee: tdee) * 4
            + draft.carbTargetGrams(tdee: tdee) * 4
            + draft.fatTargetGrams(tdee: tdee) * 9

        #expect(abs(calories - Double(draft.effectiveCalorieTarget(tdee: tdee))) < 1)
    }

    @Test("Editing the calorie target leaves a manual gram goal where it is")
    func calorieEditLeavesGramGoals() {
        var draft = makeDraft()
        draft.manualOverride = true
        draft.proteinGramsText = "160"
        draft.carbGramsText = "170"
        draft.fatGramsText = "60"
        draft.targetText = "1500"

        #expect(draft.proteinTargetGrams(tdee: tdee) == 160)
        draft.targetText = "3000"
        #expect(draft.proteinTargetGrams(tdee: tdee) == 160)
        #expect(
            draft.macroAccountSummary(tdee: tdee, locale: Locale(identifier: "en_US"))
                == "Macros account for 1,860 of 3,000 kcal"
        )
    }

    @Test("A manual override can save gram goals that do not fill the calorie target")
    func manualSaveStoresTypedGrams() {
        let profile = makeProfile()
        var draft = GoalEditDraft(profile: profile)
        draft.manualOverride = true
        draft.targetText = "1800"
        draft.proteinRatio = 0.90
        draft.proteinGramsText = "160"
        draft.carbGramsText = "170"
        draft.fatGramsText = "60"

        #expect(draft.canSave)
        draft.apply(to: profile)

        #expect(profile.dailyCalorieTarget == 1_800)
        #expect(profile.proteinTargetG == 160)
        #expect(profile.carbTargetG == 170)
        #expect(profile.fatTargetG == 60)
        #expect(profile.manualOverride)
        #expect(profile.nutrientTargets(forCalorieTarget: 2_400)[.protein] == 160)
    }

    @Test("A blank macro goal blocks saving a manual override")
    func blankMacroGoalBlocksManualSave() {
        var draft = makeDraft()
        draft.manualOverride = true
        draft.targetText = "1800"
        draft.proteinGramsText = ""

        #expect(!draft.isMacroValid)
        #expect(!draft.canSave)
    }

    @Test("Turning the override off snaps the gram goals back into a split")
    func turningOverrideOffSnapsGramsIntoASplit() {
        var draft = makeDraft()
        draft.manualOverride = true
        draft.proteinGramsText = "150"
        draft.carbGramsText = "180"
        draft.fatGramsText = "50"

        draft.manualOverrideChanged(to: false, tdee: tdee)

        #expect(!draft.manualOverride)
        #expect(abs(draft.proteinRatio - (600.0 / 1_770)) < 1e-9)
        #expect(abs(draft.carbRatio - (720.0 / 1_770)) < 1e-9)
        #expect(abs(draft.fatRatio - (450.0 / 1_770)) < 1e-9)
        #expect(draft.isMacroValid)
    }

    @Test("Turning the manual toggle on copies the current split into gram goals")
    func togglingManualSeedsGramGoals() {
        var draft = makeDraft()
        draft.proteinRatio = 0.25
        draft.carbRatio = 0.45
        draft.fatRatio = 0.30

        draft.manualOverrideChanged(to: true, tdee: tdee)

        let calories = Double(draft.calculatedTarget(tdee: tdee))
        let protein = NutritionCalculator.macroGrams(calories: calories, ratio: 0.25, caloriesPerGram: 4)
        #expect(draft.proteinGramsText == MacroGramGoals.fieldText(forGrams: protein))
        #expect(draft.canSave)
    }

    @Test("Saving a manual goal without editing the grams keeps their exact stored values")
    func untouchedManualGramsSurviveASave() {
        let profile = makeProfile()
        profile.manualOverride = true
        profile.dailyCalorieTarget = 1_800
        profile.proteinTargetG = 157.25
        profile.carbTargetG = 180.4
        profile.fatTargetG = 55

        var draft = GoalEditDraft(profile: profile)
        draft.loadNutrientGoals(from: profile)
        draft.apply(to: profile)

        #expect(profile.proteinTargetG == 157.25)
        #expect(profile.carbTargetG == 180.4)
        #expect(profile.fatTargetG == 55)
    }

    @Test("Ratios that do not total 100% block saving")
    func lopsidedRatiosBlockSaving() {
        var draft = makeDraft()
        draft.proteinRatio = 0.50
        draft.carbRatio = 0.50
        draft.fatRatio = 0.50

        #expect(!draft.isMacroValid)
        #expect(!draft.canSave)
    }

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

    @Test("Saving a manual target stores it and pins the profile to it")
    func savingAManualTargetPinsTheProfile() {
        let profile = makeProfile()

        var draft = GoalEditDraft(profile: profile)
        draft.manualOverride = true
        draft.targetText = "1750"
        draft.apply(to: profile)

        #expect(profile.dailyCalorieTarget == 1_750)
        #expect(profile.manualOverride)
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
