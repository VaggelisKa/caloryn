import Testing
@testable import Caloryn

/// Covers the figures the onboarding goal step derives and the manual-target
/// rule it applies, which until now were only reachable by driving the step.
@MainActor
@Suite("Onboarding goal summary draft")
struct OnboardingGoalSummaryDraftTests {

    // MARK: - Derived figures

    @Test("BMR and daily burn come from the shared calculator, not a second derivation")
    func figuresComeFromTheCalculator() {
        let basis = makeBasis()

        let expectedBMR = NutritionCalculator.bmr(sex: .male, weightKg: 80, heightCm: 180, age: 30)
        #expect(basis.bmr == expectedBMR)
        #expect(basis.tdee == NutritionCalculator.tdee(bmr: expectedBMR, activity: .moderatelyActive))
        #expect(basis.calculatedTarget == NutritionCalculator.defaultTarget(tdee: basis.tdee, deficit: 500))
    }

    @Test("A larger deficit lowers the calculated target")
    func deficitLowersTarget() {
        #expect(makeBasis(calorieDeficit: 750).calculatedTarget < makeBasis(calorieDeficit: 250).calculatedTarget)
    }

    @Test("A surplus raises the calculated target above maintenance")
    func surplusRaisesTarget() {
        #expect(makeBasis(calorieDeficit: -500).calculatedTarget > makeBasis(calorieDeficit: 0).calculatedTarget)
    }

    // MARK: - Deficit label

    @Test("The deficit label names the direction rather than showing a bare sign")
    func deficitLabelNamesDirection() {
        #expect(makeBasis(calorieDeficit: 500).deficitLabel == "-500 kcal/day (lose weight)")
        #expect(makeBasis(calorieDeficit: -300).deficitLabel == "+300 kcal/day (gain weight)")
        #expect(makeBasis(calorieDeficit: 0).deficitLabel == "Maintenance (no change)")
    }

    // MARK: - Manual target

    @Test("Without the manual toggle the typed text is ignored")
    func manualTextIgnoredWhileToggleIsOff() {
        var draft = OnboardingGoalSummaryDraft()
        draft.useManualOverride = false
        draft.manualTargetText = "9999"

        #expect(!draft.appliesManualTarget)
        #expect(draft.displayTarget(basis: makeBasis()) == makeBasis().calculatedTarget)
    }

    @Test("With the manual toggle on a plausible typed target wins")
    func manualTargetWins() {
        var draft = OnboardingGoalSummaryDraft()
        draft.useManualOverride = true
        draft.manualTargetText = "1800"

        #expect(draft.appliesManualTarget)
        #expect(draft.displayTarget(basis: makeBasis()) == 1_800)
    }

    @Test("A target below the minimum is treated as a typo and the calculation stands")
    func tooLowManualTargetIsRejected() {
        var draft = OnboardingGoalSummaryDraft()
        draft.useManualOverride = true
        draft.manualTargetText = "\(OnboardingGoalSummaryDraft.minimumManualTarget - 1)"

        #expect(!draft.appliesManualTarget)
        #expect(draft.displayTarget(basis: makeBasis()) == makeBasis().calculatedTarget)
    }

    @Test("The minimum itself is accepted")
    func minimumManualTargetIsAccepted() {
        var draft = OnboardingGoalSummaryDraft()
        draft.useManualOverride = true
        draft.manualTargetText = "\(OnboardingGoalSummaryDraft.minimumManualTarget)"

        #expect(draft.appliesManualTarget)
    }

    @Test("Onboarding rejects the same low targets the goal editor rejects")
    func minimumMatchesTheGoalEditor() {
        #expect(OnboardingGoalSummaryDraft.minimumManualTarget == GoalEditDraft.minimumManualTarget)
    }

    @Test("Text the field cannot turn into a usable target keeps the calculation on screen", arguments: [
        "", " ", "abc", "18 00", "1800.5", "1,800", "1e3", "inf", "nan", "-2000"
    ])
    func unparseableManualTargetFallsBack(text: String) {
        var draft = OnboardingGoalSummaryDraft()
        draft.useManualOverride = true
        draft.manualTargetText = text

        #expect(!draft.appliesManualTarget)
        #expect(draft.displayTarget(basis: makeBasis()) == makeBasis().calculatedTarget)
    }

    @Test("A huge typed target is carried through rather than clipped")
    func hugeManualTargetIsCarried() {
        var draft = OnboardingGoalSummaryDraft()
        draft.useManualOverride = true
        draft.manualTargetText = "99999"

        #expect(draft.displayTarget(basis: makeBasis()) == 99_999)
    }

    // MARK: - Seeding and tracking

    @Test("The field opens showing the calculation, not an empty box")
    func fieldSeedsWithTheCalculation() {
        var draft = OnboardingGoalSummaryDraft()
        let basis = makeBasis()

        draft.seedManualTarget(basis: basis)

        #expect(draft.manualTargetText == "\(basis.calculatedTarget)")
    }

    @Test("While the slider drives the target the field follows it")
    func fieldTracksTheSlider() {
        var draft = OnboardingGoalSummaryDraft()
        draft.seedManualTarget(basis: makeBasis(calorieDeficit: 500))

        let moved = makeBasis(calorieDeficit: 750)
        draft.calculatedTargetChanged(basis: moved)

        #expect(draft.manualTargetText == "\(moved.calculatedTarget)")
    }

    @Test("Once the manual toggle is on the slider cannot overwrite what was typed")
    func manualTextSurvivesSliderMoves() {
        var draft = OnboardingGoalSummaryDraft()
        draft.useManualOverride = true
        draft.manualTargetText = "1800"

        draft.calculatedTargetChanged(basis: makeBasis(calorieDeficit: 750))

        #expect(draft.manualTargetText == "1800")
    }

    @Test("Seeding still overwrites, because it runs when the step appears")
    func seedingOverwritesEvenWhenManual() {
        var draft = OnboardingGoalSummaryDraft()
        draft.useManualOverride = true
        draft.manualTargetText = "1800"
        let basis = makeBasis()

        draft.seedManualTarget(basis: basis)

        #expect(draft.manualTargetText == "\(basis.calculatedTarget)")
    }

    // MARK: - What the step hands on

    @Test("A manual target is handed on flagged as manual, so the profile stops recalculating it")
    func manualTargetIsFlagged() {
        var draft = OnboardingGoalSummaryDraft()
        draft.useManualOverride = true
        draft.manualTargetText = "1800"

        let saved = OnboardingProfileSave.makeProfile(
            from: makeSelections(
                calorieTarget: draft.displayTarget(basis: makeBasis()),
                isManualTarget: draft.appliesManualTarget
            )
        )

        #expect(saved.dailyCalorieTarget == 1_800)
        #expect(saved.manualOverride)
    }

    @Test("A toggle left on with an unusable entry saves the calculation, not a manual flag")
    func rejectedManualTargetSavesTheCalculation() {
        var draft = OnboardingGoalSummaryDraft()
        draft.useManualOverride = true
        draft.manualTargetText = "12"
        let basis = makeBasis()

        let saved = OnboardingProfileSave.makeProfile(
            from: makeSelections(
                calorieTarget: draft.displayTarget(basis: basis),
                isManualTarget: draft.appliesManualTarget
            )
        )

        #expect(saved.dailyCalorieTarget == basis.calculatedTarget)
        #expect(!saved.manualOverride)
    }

    // MARK: - Helpers

    private func makeBasis(calorieDeficit: Double = 500) -> OnboardingGoalSummaryDraft.Basis {
        OnboardingGoalSummaryDraft.Basis(
            age: 30,
            sex: .male,
            heightCm: 180,
            weightKg: 80,
            activityLevel: .moderatelyActive,
            calorieDeficit: calorieDeficit
        )
    }

    private func makeSelections(calorieTarget: Int, isManualTarget: Bool) -> OnboardingProfileSave.Selections {
        OnboardingProfileSave.Selections(
            age: 30,
            sex: .male,
            heightCm: 180,
            weightKg: 80,
            activityLevel: .moderatelyActive,
            energyCalculationMode: .lifestyleEstimate,
            calorieDeficit: 500,
            calorieTarget: calorieTarget,
            isManualTarget: isManualTarget,
            proteinRatio: 0.30,
            carbRatio: 0.40,
            fatRatio: 0.30
        )
    }
}
