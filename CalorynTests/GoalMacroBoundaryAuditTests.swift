import Foundation
import Testing
@testable import Caloryn

// Boundary audit of the goal editor and the macro split: the manual-target floor and the
// calorie domain, macro ratios that must total 100% over every split the sliders can
// reach, the round trip from a saved profile back into the editor, and nutrient goals
// typed with either decimal separator.

// MARK: - Fixtures

@MainActor
private func auditProfile(dailyCalorieTarget: Int? = nil) -> UserProfile {
    UserProfile(
        age: 30,
        sex: .male,
        heightCm: 178,
        weightKg: 78,
        activityLevel: .moderatelyActive,
        dailyCalorieTarget: dailyCalorieTarget
    )
}

/// Every split the three macro sliders can be left on: each slider snapped to its own
/// 5% steps over its own range, exactly as the onboarding slider binding snaps it.
@MainActor
private func auditReachableSplits() -> [(protein: Double, carbs: Double, fat: Double, percentTotal: Int)] {
    func steps(_ macro: MacroRatioSelection.Macro) -> [(ratio: Double, percent: Int)] {
        let range = macro.sliderRange
        let count = Int(((range.upperBound - range.lowerBound) / 0.05).rounded())
        return (0 ... count).map { index in
            let raw = range.lowerBound + Double(index) * 0.05
            return (SliderStep.snap(raw, in: range, step: 0.05), Int((range.lowerBound * 100).rounded()) + index * 5)
        }
    }

    var splits: [(protein: Double, carbs: Double, fat: Double, percentTotal: Int)] = []
    for protein in steps(.protein) {
        for carbs in steps(.carbs) {
            for fat in steps(.fat) {
                splits.append((
                    protein: protein.ratio,
                    carbs: carbs.ratio,
                    fat: fat.ratio,
                    percentTotal: protein.percent + carbs.percent + fat.percent
                ))
            }
        }
    }
    return splits
}

// MARK: - Manual calorie target

@MainActor
@Suite("Goal edit manual target audit")
struct AuditGoalManualTargetTests {
    @Test(
        "The manual target parses a plain whole number, clamps it to the domain and needs 1,000",
        arguments: [
            ("999", 999, false),
            ("1000", 1_000, true),
            ("1001", 1_001, true),
            ("0", 0, false),
            ("-1500", -1_500, false),
            ("1000000000", 1_000_000_000, true),
            ("1000000001", 1_000_000_000, true),
            ("99999999999", 1_000_000_000, true),
        ]
    )
    func parsesClampsAndFloors(text: String, expectedTarget: Int, isValid: Bool) {
        var draft = GoalEditDraft(profile: auditProfile())
        draft.manualOverride = true
        draft.targetText = text

        #expect(draft.manualTarget == expectedTarget)
        #expect(draft.isManualTargetValid == isValid)
        #expect(draft.canSave == isValid)
    }

    @Test(
        "Text a number pad cannot produce, or a number past Int, is not a manual target",
        arguments: ["", " 1500", "1500 ", "1,500", "1.500", "1500.0", "1e3", "abc", "9223372036854775808"]
    )
    func unparseableTextIsNoTarget(text: String) {
        var draft = GoalEditDraft(profile: auditProfile())
        draft.manualOverride = true
        draft.targetText = text

        #expect(draft.manualTarget == nil)
        #expect(draft.isManualTargetValid == false)
        #expect(draft.disablesAppleHealthAdjustment == false)
        #expect(draft.effectiveCalorieTarget(tdee: 2_500) == draft.calculatedTarget(tdee: 2_500))
    }

    @Test(
        "Onboarding accepts and rejects exactly the typed targets the goal editor does",
        arguments: ["", "abc", "0", "999", "1000", "1001", "1850", "-1500", "1,500", "99999999999", "9223372036854775808"]
    )
    func onboardingAndEditorAgreeOnValidity(text: String) {
        var editor = GoalEditDraft(profile: auditProfile())
        editor.manualOverride = true
        editor.targetText = text
        var onboarding = OnboardingGoalSummaryDraft()
        onboarding.useManualOverride = true
        onboarding.manualTargetText = text

        #expect(onboarding.appliesManualTarget == editor.isManualTargetValid)
    }

    @Test("Onboarding clamps a typed target past the calorie domain the way the goal editor does")
    func onboardingClampsAHugeTarget() {
        let text = "99999999999"
        var editor = GoalEditDraft(profile: auditProfile())
        editor.manualOverride = true
        editor.targetText = text
        var onboarding = OnboardingGoalSummaryDraft()
        onboarding.useManualOverride = true
        onboarding.manualTargetText = text
        let basis = OnboardingGoalSummaryDraft.Basis(
            age: 30, sex: .male, heightCm: 178, weightKg: 78, activityLevel: .moderatelyActive, calorieDeficit: 500
        )

        #expect(editor.effectiveCalorieTarget(tdee: basis.tdee) == CalorieDomain.maximum)
        #expect(onboarding.displayTarget(basis: basis) == CalorieDomain.maximum)
    }

    @Test(
        "Turning the manual toggle on always leaves a target that can be saved",
        arguments: [0.0, 1_000, 2_500, 1e12, .infinity, .nan]
    )
    func togglingManualOnIsAlwaysSaveable(tdee: Double) {
        var draft = GoalEditDraft(profile: auditProfile())
        draft.targetText = ""

        draft.manualOverrideChanged(to: true, tdee: tdee)

        #expect(draft.targetText == "\(draft.calculatedTarget(tdee: tdee))")
        #expect(draft.manualTarget == draft.calculatedTarget(tdee: tdee))
        #expect(draft.isManualTargetValid)
        #expect(draft.canSave)
    }

    @Test("A manual target between the editor's floor and the calculator's flows to Today unfloored")
    func lowManualTargetReachesTodayAsTyped() {
        let profile = auditProfile()
        var draft = GoalEditDraft(profile: profile)
        draft.manualOverride = true
        draft.targetText = "1050"
        #expect(draft.canSave)

        draft.apply(to: profile)
        let budget = profile.activityBudget(
            consumed: 0,
            activeEnergyKcal: 0,
            recentActiveEnergySamples: [],
            isActivityLoading: false,
            activityMessage: nil,
            date: makeTestDate(year: 2020, month: 6, day: 15)
        )
        let hero = TodayHeroSummary(mealTotals: [:], budget: budget, locale: Locale(identifier: "en_US"))

        #expect(profile.dailyCalorieTarget == 1_050)
        #expect(budget.adjustedTarget == 1_050)
        #expect(hero.caption == "kcal left of 1,050")
        #expect(SettingsGoalSummary.dailyTargetText(profile.dailyCalorieTarget, locale: Locale(identifier: "en_US")) == "1,050 kcal a day")
    }
}

// MARK: - Macro ratios

@MainActor
@Suite("Macro ratio total audit")
struct AuditMacroRatioTotalTests {
    @Test("Over every reachable split, both macro editors accept exactly the splits that total 100%")
    func validityMatchesTheReadoutsOverEveryReachableSplit() {
        let splits = auditReachableSplits()
        #expect(splits.count == 9 * 11 * 9)

        for split in splits {
            let selection = MacroRatioSelection(
                calorieTarget: 2_000, protein: split.protein, carbs: split.carbs, fat: split.fat
            )
            var draft = GoalEditDraft(profile: auditProfile())
            draft.proteinRatio = split.protein
            draft.carbRatio = split.carbs
            draft.fatRatio = split.fat
            let context = "\(split.protein)/\(split.carbs)/\(split.fat)"

            #expect(selection.isValid == (split.percentTotal == 100), "\(context)")
            #expect(draft.isMacroValid == selection.isValid, "\(context)")
            #expect(selection.validationMessage == nil || split.percentTotal != 100, "\(context)")
        }
    }

    @Test(
        "Both macro editors share one tolerance, inclusive just inside a percent and exclusive at it",
        arguments: [
            (0.30, 0.40, 0.295, true),
            (0.30, 0.40, 0.305, true),
            (0.30, 0.40, 0.309, true),
            (0.30, 0.40, 0.311, false),
            (0.30, 0.40, 0.29, false),
            (0.30, 0.40, 0.31, false),
            (0.30, 0.40, 0.28, false),
        ]
    )
    func toleranceEdges(protein: Double, carbs: Double, fat: Double, isValid: Bool) {
        let selection = MacroRatioSelection(calorieTarget: 2_000, protein: protein, carbs: carbs, fat: fat)
        var draft = GoalEditDraft(profile: auditProfile())
        draft.proteinRatio = protein
        draft.carbRatio = carbs
        draft.fatRatio = fat

        #expect(selection.isValid == isValid)
        #expect(draft.isMacroValid == isValid)
        #expect(MacroRatioSelection.totalTolerance == GoalEditDraft.macroTotalTolerance)
    }

    @Test("Every reachable slider position reads back as its own whole percentage")
    func sliderReadoutsAreExact() {
        for macro in MacroRatioSelection.Macro.allCases {
            let range = macro.sliderRange
            let count = Int(((range.upperBound - range.lowerBound) / 0.05).rounded())
            for index in 0 ... count {
                let ratio = SliderStep.snap(range.lowerBound + Double(index) * 0.05, in: range, step: 0.05)
                let selection = MacroRatioSelection(
                    calorieTarget: 2_000,
                    protein: macro == .protein ? ratio : 0.30,
                    carbs: macro == .carbs ? ratio : 0.40,
                    fat: macro == .fat ? ratio : 0.30
                )
                let expectedPercent = Int((range.lowerBound * 100).rounded()) + index * 5

                #expect(selection.percentText(for: macro) == "\(expectedPercent)%", "\(macro) step \(index)")
            }
        }
    }

    @Test("The macros are named the way their sliders and cards are labelled")
    func macroDisplayNames() {
        #expect(MacroRatioSelection.Macro.allCases.map(\.displayName) == ["Protein", "Carbs", "Fat"])
    }

    @Test("A short split's message names the total the three readouts add up to")
    func validationMessageAddsTheReadouts() {
        let selection = MacroRatioSelection(calorieTarget: 2_000, protein: 0.10, carbs: 0.50, fat: 0.30)

        #expect(selection.percentText(for: .protein) == "10%")
        #expect(selection.percentText(for: .carbs) == "50%")
        #expect(selection.percentText(for: .fat) == "30%")
        #expect(selection.isValid == false)
        #expect(selection.validationMessage == "Ratios should total 100% (currently 90%)")
    }

    @Test("At every reachable valid split and target, the grams spend the whole target")
    func gramsSpendTheTarget() {
        let validSplits = auditReachableSplits().filter { $0.percentTotal == 100 }
        #expect(!validSplits.isEmpty)

        for target in [1_000, 1_200, 2_000, 2_537, 4_000] {
            for split in validSplits {
                let selection = MacroRatioSelection(
                    calorieTarget: target, protein: split.protein, carbs: split.carbs, fat: split.fat
                )
                let kcal = selection.grams(for: .protein) * 4 + selection.grams(for: .carbs) * 4 + selection.grams(for: .fat) * 9

                #expect(abs(kcal - Double(target)) < 1e-6, "target \(target), \(split)")
            }
        }
    }

    @Test(
        "The derived split never claims more than the target, and keeps the proportions when scaled",
        arguments: [
            (2_000, 150.0, 200.0, 66.7),
            (1_000, 150.0, 200.0, 67.0),
            (1, 150.0, 200.0, 67.0),
            (2_000, 0.0, 0.0, 0.0),
            (2_000, 500.0, 0.0, 0.0),
            (1_000_000_000, 150.0, 200.0, 67.0),
        ]
    )
    func derivedSplitNeverOverspends(target: Int, protein: Double, carbs: Double, fat: Double) {
        let ratios = ProfileEditMacroRatios(
            dailyCalorieTarget: target, proteinTargetG: protein, carbTargetG: carbs, fatTargetG: fat
        )
        let raw = (protein * 4 / Double(target), carbs * 4 / Double(target), fat * 9 / Double(target))
        let rawTotal = raw.0 + raw.1 + raw.2
        let total = ratios.protein + ratios.carbs + ratios.fat

        #expect(total <= 1 + 1e-12)
        if rawTotal > 1 {
            #expect(abs(total - 1) < 1e-12)
            #expect(abs(ratios.protein - raw.0 / rawTotal) < 1e-12)
            #expect(abs(ratios.carbs - raw.1 / rawTotal) < 1e-12)
            #expect(abs(ratios.fat - raw.2 / rawTotal) < 1e-12)
        } else {
            #expect(ratios.protein == raw.0)
            #expect(ratios.carbs == raw.1)
            #expect(ratios.fat == raw.2)
        }
    }

    @Test("A target at or below zero has no split to derive, so the default is used", arguments: [0, -1, -2_000])
    func nonPositiveTargetUsesTheDefaultSplit(target: Int) {
        let ratios = ProfileEditMacroRatios(dailyCalorieTarget: target, proteinTargetG: 150, carbTargetG: 200, fatTargetG: 67)

        #expect(ratios == .defaultSplit)
    }
}

// MARK: - Profile round trip

@MainActor
@Suite("Goal profile round trip audit")
struct AuditGoalProfileRoundTripTests {
    @Test("Every reachable split saved at onboarding is read back the same by the profile, the seed and the editor")
    func savedSplitsReadBackTheSame() {
        let validSplits = auditReachableSplits().filter { $0.percentTotal == 100 }

        for target in [1_200, 2_000, 2_537] {
            for split in validSplits {
                let profile = OnboardingProfileSave.makeProfile(from: .init(
                    age: 30, sex: .female, heightCm: 165, weightKg: 62, activityLevel: .lightlyActive,
                    energyCalculationMode: .lifestyleEstimate, calorieDeficit: 500,
                    calorieTarget: target, isManualTarget: true,
                    proteinRatio: split.protein, carbRatio: split.carbs, fatRatio: split.fat
                ))
                let selection = MacroRatioSelection(
                    calorieTarget: target, protein: split.protein, carbs: split.carbs, fat: split.fat
                )
                let seed = GoalEditSeed(profile: profile)
                let draft = GoalEditDraft(seed: seed)
                let context = "target \(target), \(split)"

                // The onboarding preview is what was saved.
                #expect(profile.proteinTargetG == selection.grams(for: .protein), "\(context)")
                #expect(profile.carbTargetG == selection.grams(for: .carbs), "\(context)")
                #expect(profile.fatTargetG == selection.grams(for: .fat), "\(context)")

                // The profile, the goal editor's seed and the editor agree on the split.
                for (derived, expected) in [
                    (profile.macroRatios.protein, split.protein),
                    (profile.macroRatios.carbs, split.carbs),
                    (profile.macroRatios.fat, split.fat),
                    (seed.proteinRatio, split.protein),
                    (seed.carbRatio, split.carbs),
                    (seed.fatRatio, split.fat),
                ] {
                    #expect(abs(derived - expected) < 1e-9, "\(context)")
                }
                #expect(draft.isMacroValid, "\(context)")
                #expect(draft.canSave, "\(context)")
            }
        }
    }

    @Test("Opening and saving the goal editor without an edit leaves the targets where they were")
    func unchangedSaveIsIdempotent() {
        for split in auditReachableSplits().filter({ $0.percentTotal == 100 }) {
            let profile = OnboardingProfileSave.makeProfile(from: .init(
                age: 41, sex: .male, heightCm: 182, weightKg: 88, activityLevel: .veryActive,
                energyCalculationMode: .lifestyleEstimate, calorieDeficit: 250,
                calorieTarget: 2_537, isManualTarget: true,
                proteinRatio: split.protein, carbRatio: split.carbs, fatRatio: split.fat
            ))
            let before = (profile.dailyCalorieTarget, profile.proteinTargetG, profile.carbTargetG, profile.fatTargetG)

            var draft = GoalEditDraft(profile: profile)
            draft.loadNutrientGoals(from: profile)
            draft.apply(to: profile)

            #expect(profile.dailyCalorieTarget == before.0)
            #expect(abs(profile.proteinTargetG - before.1) < 1e-9)
            #expect(abs(profile.carbTargetG - before.2) < 1e-9)
            #expect(abs(profile.fatTargetG - before.3) < 1e-9)
        }
    }

    @Test("A stale split the profile scales back opens in the goal editor unscaled and unsaveable")
    func staleSplitDivergesBetweenProfileAndSeed() {
        let profile = auditProfile(dailyCalorieTarget: 1_000)
        profile.proteinTargetG = 150
        profile.carbTargetG = 200
        profile.fatTargetG = 67

        let seed = GoalEditSeed(profile: profile)
        let draft = GoalEditDraft(seed: seed)
        let profileTotal = profile.macroRatios.protein + profile.macroRatios.carbs + profile.macroRatios.fat

        #expect(abs(profileTotal - 1) < 1e-12)
        // Current behaviour, suspected bug: the seed divides the grams itself instead of
        // going through ProfileEditMacroRatios, so it keeps the impossible 60/80/60 split
        // the profile has already scaled to 100% — and the editor opens with Save disabled.
        #expect(abs(seed.proteinRatio - 0.6) < 1e-12)
        #expect(abs(seed.carbRatio - 0.8) < 1e-12)
        #expect(abs(seed.fatRatio - 0.603) < 1e-12)
        #expect(draft.isMacroValid == false)
        #expect(draft.canSave == false)
    }

    @Test("A stale split is spent exactly once the profile screen saves new facts")
    func profileEditRespendsAStaleSplit() {
        let profile = auditProfile(dailyCalorieTarget: 1_000)
        profile.proteinTargetG = 150
        profile.carbTargetG = 200
        profile.fatTargetG = 67
        let shares = (0.6 / 2.003, 0.8 / 2.003, 0.603 / 2.003)

        var draft = ProfileEditDraft(profile: profile)
        draft.weightKg = 80
        draft.apply(to: profile)

        let target = Double(profile.dailyCalorieTarget)
        let kcal = profile.proteinTargetG * 4 + profile.carbTargetG * 4 + profile.fatTargetG * 9
        #expect(profile.dailyCalorieTarget == NutritionCalculator.defaultTarget(tdee: profile.tdee, deficit: profile.calorieDeficit))
        #expect(abs(kcal - target) < 1e-6)
        #expect(abs(profile.proteinTargetG * 4 / target - shares.0) < 1e-9)
        #expect(abs(profile.carbTargetG * 4 / target - shares.1) < 1e-9)
        #expect(abs(profile.fatTargetG * 9 / target - shares.2) < 1e-9)
    }

    @Test("A profile with no target reads as the default split on both the profile and the seed")
    func zeroTargetReadsAsTheDefaultEverywhere() {
        let profile = auditProfile(dailyCalorieTarget: 0)
        let seed = GoalEditSeed(profile: profile)

        #expect(profile.macroRatios == .defaultSplit)
        #expect(seed.proteinRatio == ProfileEditMacroRatios.defaultSplit.protein)
        #expect(seed.carbRatio == ProfileEditMacroRatios.defaultSplit.carbs)
        #expect(seed.fatRatio == ProfileEditMacroRatios.defaultSplit.fat)
    }
}

// MARK: - Nutrient goals and decimal separators

@MainActor
@Suite("Nutrient goal input audit")
struct AuditNutrientGoalInputTests {
    @Test(
        "Either decimal separator is the decimal point, and one is the most a goal may hold",
        arguments: [
            ("27,5", 27.5),
            ("27.5", 27.5),
            (",5", 0.5),
            (".5", 0.5),
            ("5,", 5),
            ("5.", 5),
            ("1,000", 1),
            ("1.000", 1),
            ("00012", 12),
            ("0.001", 0.001),
            (" 30\n", 30),
            ("+5", 5),
        ]
    )
    func gramGoalsParse(text: String, expected: Double) {
        var draft = GoalEditDraft(profile: auditProfile())
        draft.nutrientTargetTexts[.fiber] = text

        #expect(draft.storedTarget(for: .fiber) == expected)
        #expect(draft.isInvalidTarget(for: .fiber) == false)
        #expect(NutrientGoalPickerVisibility.isVisible(targetText: text))
    }

    @Test(
        "A goal that is not one positive decimal number is flagged, never stored",
        arguments: ["1,5,0", "1.5,0", ",", ".", "-5", "-0", "0", "0,0", "3 0", "٣٠", "１２", "12g"]
    )
    func malformedGoalsAreRejected(text: String) {
        var draft = GoalEditDraft(profile: auditProfile())
        draft.nutrientTargetTexts[.fiber] = text

        #expect(draft.storedTarget(for: .fiber) == nil)
        #expect(draft.isInvalidTarget(for: .fiber))
        #expect(draft.areNutrientGoalsValid == false)
        #expect(draft.canSave == false)
    }

    @Test(
        "Milligram goals are typed in milligrams and stored in grams, with either separator",
        arguments: [
            ("2300", 2.3),
            ("2300,5", 2.300_5),
            ("2300.5", 2.300_5),
            ("2.300", 0.002_3),
            ("0,1", 0.000_1),
        ]
    )
    func milligramGoalsAreStoredInGrams(text: String, expectedGrams: Double) {
        for nutrient in [TrackedNutrient.sodium, .cholesterol] {
            var draft = GoalEditDraft(profile: auditProfile())
            draft.nutrientTargetTexts[nutrient] = text

            let stored = draft.storedTarget(for: nutrient)
            #expect(stored.map { abs($0 - expectedGrams) < 1e-12 } == true, "\(nutrient)")
        }
    }

    @Test("Whether a goal is flagged is exactly 'the picker shows, but nothing could be stored'")
    func invalidityMatchesPickerVisibility() {
        let texts = ["", " ", "\n", "30", " 30 ", "27,5", "abc", "0", "-5", "1,5,0", ".", "1e3", "inf"]

        for nutrient in TrackedNutrient.editableGoalNutrients {
            for text in texts {
                var draft = GoalEditDraft(profile: auditProfile())
                draft.nutrientTargetTexts[nutrient] = text
                let isVisible = NutrientGoalPickerVisibility.isVisible(targetText: text)

                #expect(draft.isInvalidTarget(for: nutrient) == (isVisible && draft.storedTarget(for: nutrient) == nil), "\(nutrient) '\(text)'")
                if draft.storedTarget(for: nutrient) != nil {
                    #expect(isVisible, "\(nutrient) '\(text)'")
                }
            }
        }
    }

    @Test(
        "A goal saved to a tenth of its input unit survives being opened and saved again",
        arguments: [0.1, 2.5, 27.5, 30, 125.3, 1_000]
    )
    func tenthPrecisionGoalsRoundTrip(input: Double) {
        for nutrient in TrackedNutrient.editableGoalNutrients {
            let stored = nutrient.unit.storedValue(fromInput: input)
            let profile = auditProfile()
            profile.setTarget(stored, for: nutrient)

            var draft = GoalEditDraft(profile: profile)
            draft.loadNutrientGoals(from: profile)
            draft.apply(to: profile)

            let roundTripped = profile.target(for: nutrient) ?? -1
            #expect(abs(roundTripped - stored) < 1e-12, "\(nutrient) \(input)")
        }
    }

    @Test("A goal typed to the hundredth is rounded to a tenth the next time the editor saves")
    func hundredthPrecisionGoalIsRoundedOnTheNextSave() {
        let profile = auditProfile()
        var first = GoalEditDraft(profile: profile)
        first.nutrientTargetTexts[.fiber] = "27.25"
        first.apply(to: profile)
        #expect(profile.target(for: .fiber) == 27.25)

        var second = GoalEditDraft(profile: profile)
        second.loadNutrientGoals(from: profile)
        #expect(second.targetText(for: .fiber) == "27.3")
        second.apply(to: profile)

        // Current behaviour, suspected bug: the field reloads the goal to one decimal, so
        // saving without touching it moves a 27.25 g goal to 27.3 g.
        #expect(profile.target(for: .fiber) == 27.3)
    }
}

// MARK: - Deficit wording

@MainActor
@Suite("Goal deficit wording audit")
struct AuditGoalDeficitWordingTests {
    @Test("On every slider step the editor, Settings and onboarding describe the deficit the same way")
    func everySliderStepIsWordedConsistently() {
        for step in stride(from: -500.0, through: 1_000.0, by: 50.0) {
            var draft = GoalEditDraft(profile: auditProfile())
            draft.calorieDeficit = step
            let settings = SettingsGoalSummary.goalSubtitle(calorieDeficit: step, isManualOverride: false, locale: .current)
            let pace = OnboardingGoalPlate(bmr: 1_700, tdee: 2_500, target: 2_000, calorieDeficit: step).paceCaption
            let amount = Int(abs(step))

            if step > 0 {
                #expect(draft.deficitLabel == "-\(amount) kcal/day (lose weight)")
                #expect(settings == "About \(amount.formatted()) under what you burn")
                #expect(pace == "\(amount.formatted()) under what you burn")
            } else if step < 0 {
                #expect(draft.deficitLabel == "+\(amount) kcal/day (gain weight)")
                #expect(settings == "About \(amount.formatted()) over what you burn")
                #expect(pace == "\(amount.formatted()) over what you burn")
            } else {
                #expect(draft.deficitLabel == "Maintenance (no change)")
                #expect(settings == "About what you burn")
                #expect(pace == "What you burn")
            }
        }
    }

    @Test(
        "A sub-calorie deficit reads as no adjustment in Settings but as a direction in the editor",
        arguments: [(0.5, "-0 kcal/day (lose weight)"), (-0.5, "+0 kcal/day (gain weight)")]
    )
    func subCalorieDeficitWording(deficit: Double, editorLabel: String) {
        var draft = GoalEditDraft(profile: auditProfile())
        draft.calorieDeficit = deficit

        #expect(SettingsGoalSummary.goalSubtitle(calorieDeficit: deficit, isManualOverride: false) == "About what you burn")
        #expect(OnboardingGoalPlate(bmr: 1_700, tdee: 2_500, target: 2_500, calorieDeficit: deficit).paceCaption == "What you burn")
        // Current behaviour, suspected bug: the editor tests the raw deficit's sign but prints
        // its truncation, so a stored fraction under one calorie reads "-0 kcal/day".
        #expect(draft.deficitLabel == editorLabel)
    }
}
