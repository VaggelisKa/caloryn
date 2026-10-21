import Foundation
import Testing
@testable import Caloryn

nonisolated private let auditUS = Locale(identifier: "en_US")
nonisolated private let auditDanish = Locale(identifier: "da_DK")

nonisolated private let auditSliderSteps: [Double] = Array(stride(from: -500.0, through: 1_000.0, by: 50.0))

@MainActor
private func auditPeople(calorieDeficit: Double) -> [OnboardingGoalSummaryDraft.Basis] {
    [
        .init(age: 30, sex: .male, heightCm: 180, weightKg: 80, activityLevel: .moderatelyActive, calorieDeficit: calorieDeficit),
        .init(age: 45, sex: .female, heightCm: 165, weightKg: 62, activityLevel: .lightlyActive, calorieDeficit: calorieDeficit),
        .init(age: 100, sex: .female, heightCm: 120, weightKg: 40, activityLevel: .sedentary, calorieDeficit: calorieDeficit),
        .init(age: 16, sex: .male, heightCm: 220, weightKg: 200, activityLevel: .extraActive, calorieDeficit: calorieDeficit),
    ]
}

private func auditLowercasingFirst(_ text: String) -> String {
    text.prefix(1).lowercased() + text.dropFirst()
}

@MainActor
@Suite("Onboarding goal plate audit")
struct AuditOnboardingGoalPlateTests {
    @Test("On every slider step the plate's rows describe the target actually shown")
    func everySliderStepDescribesTheShownTarget() {
        for deficit in auditSliderSteps {
            for basis in auditPeople(calorieDeficit: deficit) {
                let target = basis.calculatedTarget
                let plate = OnboardingGoalPlate(basis: basis, target: target)
                let context = "deficit \(deficit), \(basis)"

                #expect(plate.restKcal == basis.bmr.truncatedSafely, "\(context)")
                #expect(plate.burnKcal == basis.tdee.truncatedSafely, "\(context)")
                #expect(plate.targetKcal == target, "\(context)")
                #expect(plate.difference == plate.burnKcal - target, "\(context)")

                if target > NutritionCalculator.defaultTarget(energyExpenditure: 0) {
                    #expect(plate.difference == Int(deficit), "\(context)")
                } else {
                    #expect(plate.difference <= Int(deficit), "\(context)")
                }

                switch plate.difference {
                case 0:
                    #expect(plate.adjustmentText == "None", "\(context)")
                    #expect(plate.explanation.hasSuffix("the plate is the same size, so your weight stays put."), "\(context)")
                case 1...:
                    #expect(plate.adjustmentText == "\(plate.difference.formatted()) less", "\(context)")
                    #expect(plate.explanation.hasSuffix("\(plate.difference.formatted()) smaller, so you lose weight."), "\(context)")
                default:
                    #expect(plate.adjustmentText == "\(abs(plate.difference).formatted()) more", "\(context)")
                    #expect(plate.explanation.hasSuffix("\(abs(plate.difference).formatted()) bigger, so you gain weight."), "\(context)")
                }

                #expect(max(plate.plateDiameterRatio, plate.burnDiameterRatio) == 1, "\(context)")
                #expect(plate.plateDiameterRatio >= OnboardingGoalPlate.minimumDiameterRatio, "\(context)")
                #expect(plate.burnDiameterRatio >= OnboardingGoalPlate.minimumDiameterRatio, "\(context)")
            }
        }
    }

    @Test(
        "One calorie either side of the burn is one calorie less or more",
        arguments: [
            (2_499, "1 less", "the plate is 1 smaller, so you lose weight."),
            (2_500, "None", "the plate is the same size, so your weight stays put."),
            (2_501, "1 more", "the plate is 1 bigger, so you gain weight."),
        ]
    )
    func oneCalorieFromTheBurn(target: Int, adjustment: String, explanationTail: String) {
        let plate = OnboardingGoalPlate(bmr: 1_700, tdee: 2_500.9, target: target, calorieDeficit: 0)

        #expect(plate.adjustmentText == adjustment)
        #expect(plate.explanation.hasSuffix(explanationTail))
    }

    @Test("A gap too large for Int reads as no gap rather than trapping")
    func overflowingGapReadsAsNone() {
        let huge = OnboardingGoalPlate(bmr: 0, tdee: 1e300, target: -1, calorieDeficit: 0)
        let tiny = OnboardingGoalPlate(bmr: 0, tdee: 0, target: .min, calorieDeficit: 0)

        #expect(huge.burnKcal == .max)
        #expect(huge.difference == 0)
        #expect(huge.adjustmentText == "None")
        #expect(tiny.difference == 0)
        #expect(tiny.explanation.hasSuffix("the plate is the same size, so your weight stays put."))
    }

    @Test(
        "The drawing is proportional to area, the larger disc fills it, and the plate never shrinks past half",
        arguments: [
            (2_500, 2_000, (0.8).squareRoot(), 1.0),
            (2_000, 2_500, 1.0, (0.8).squareRoot()),
            (2_500, 2_500, 1.0, 1.0),
            (2_500, 640, (0.256).squareRoot(), 1.0),
            (2_500, 625, 0.5, 1.0),
            (4_000, 800, 0.5, 1.0),
            (2_500, 0, 0.5, 1.0),
            (2_500, -100, 0.5, 1.0),
            (0, 0, 1.0, 1.0),
        ]
    )
    func diametersFollowArea(burn: Int, target: Int, plateRatio: Double, burnRatio: Double) {
        let plate = OnboardingGoalPlate(bmr: 1_000, tdee: Double(burn), target: target, calorieDeficit: 0)

        #expect(abs(plate.plateDiameterRatio - plateRatio) < 1e-12)
        #expect(abs(plate.burnDiameterRatio - burnRatio) < 1e-12)
        if plate.plateDiameterRatio > OnboardingGoalPlate.minimumDiameterRatio, burn > 0 {
            let areaRatio = pow(plate.plateDiameterRatio / plate.burnDiameterRatio, 2)
            #expect(abs(areaRatio - Double(target) / Double(burn)) < 1e-12)
        }
    }

    @Test("Keep sits a third of the way along a slider whose zero is one of its steps")
    func keepSitsOnAStep() {
        let range = OnboardingGoalPlate.adjustmentRange
        let stepsToZero = (0 - range.lowerBound) / OnboardingGoalPlate.adjustmentStep

        #expect(OnboardingGoalPlate.maintenanceFraction == 1.0 / 3.0)
        #expect(stepsToZero == stepsToZero.rounded())
        #expect(auditSliderSteps.contains(0))
        #expect(auditSliderSteps.first == range.lowerBound)
        #expect(auditSliderSteps.last == range.upperBound)
        #expect(zip(auditSliderSteps, auditSliderSteps.dropFirst()).allSatisfy { $1 - $0 == OnboardingGoalPlate.adjustmentStep })
    }

    @Test(
        "The pace caption and the Settings subtitle say the same thing about any stored deficit",
        arguments: auditSliderSteps + [0.4, -0.4, 0.999, -0.999, 49.9, -49.9, 1_000.7, -500.7, .nan, .infinity, -.infinity]
    )
    func paceCaptionMatchesTheSettingsSubtitle(deficit: Double) {
        let pace = OnboardingGoalPlate(bmr: 1_700, tdee: 2_500, target: 2_000, calorieDeficit: deficit).paceCaption
        let settings = SettingsGoalSummary.goalSubtitle(calorieDeficit: deficit, isManualOverride: false, locale: .current)

        #expect(settings == "About " + auditLowercasingFirst(pace))
    }
}

@MainActor
@Suite("Onboarding goal calculation audit")
struct AuditOnboardingGoalCalculationTests {
    @Test("Across the About You ranges, every activity level and every slider step, the target respects the floor")
    func calculatedTargetHoldsTheFloorAndMovesTheRightWay() {
        let ages = [OnboardingPersonalInfo.ageRange.lowerBound, 40, OnboardingPersonalInfo.ageRange.upperBound]
        let heights = [OnboardingPersonalInfo.heightRange.lowerBound, 170, OnboardingPersonalInfo.heightRange.upperBound]
        let weights = [OnboardingPersonalInfo.weightRange.lowerBound, 75, OnboardingPersonalInfo.weightRange.upperBound]

        for sex in Sex.allCases {
            for age in ages {
                for height in heights {
                    for weight in weights {
                        var previousActivityTargets: [Int]?
                        for activity in ActivityLevel.allCases.sorted(by: { $0.multiplier < $1.multiplier }) {
                            let targets = auditSliderSteps.map { deficit in
                                OnboardingGoalSummaryDraft.Basis(
                                    age: age, sex: sex, heightCm: height, weightKg: weight,
                                    activityLevel: activity, calorieDeficit: deficit
                                ).calculatedTarget
                            }
                            let context = "\(sex) \(age)y \(height)cm \(weight)kg \(activity)"

                            #expect(targets.allSatisfy { $0 >= ActivityCalorieBudget.minimumTarget }, "\(context)")
                            #expect(zip(targets, targets.dropFirst()).allSatisfy { $0 >= $1 }, "\(context)")
                            if let previousActivityTargets {
                                #expect(zip(previousActivityTargets, targets).allSatisfy { $0 <= $1 }, "\(context)")
                            }
                            previousActivityTargets = targets
                        }
                    }
                }
            }
        }
    }

    @Test(
        "With the toggle off the step always shows the calculation, whatever was typed",
        arguments: ["", "abc", "999", "1850", "99999999999"]
    )
    func toggleOffShowsTheCalculation(text: String) {
        for basis in auditPeople(calorieDeficit: 500) {
            var draft = OnboardingGoalSummaryDraft()
            draft.manualTargetText = text
            draft.useManualOverride = false

            #expect(draft.displayTarget(basis: basis) == basis.calculatedTarget)
        }
    }

    @Test(
        "The step hands on one target, and every later surface shows that same number",
        arguments: [false, true]
    )
    func handedOnTargetIsShownEverywhere(isManual: Bool) {
        for deficit in [-500.0, 0, 500, 1_000] {
            for basis in auditPeople(calorieDeficit: deficit) {
                var draft = OnboardingGoalSummaryDraft()
                draft.seedManualTarget(basis: basis)
                if isManual {
                    draft.useManualOverride = true
                    draft.manualTargetText = "1850"
                }
                let target = draft.displayTarget(basis: basis)
                let plate = OnboardingGoalPlate(basis: basis, target: target)
                let selection = MacroRatioSelection(
                    calorieTarget: target,
                    protein: MacroRatioSelection.defaultSplit.protein,
                    carbs: MacroRatioSelection.defaultSplit.carbs,
                    fat: MacroRatioSelection.defaultSplit.fat
                )
                let profile = OnboardingProfileSave.makeProfile(from: .init(
                    age: basis.age, sex: basis.sex, heightCm: basis.heightCm, weightKg: basis.weightKg,
                    activityLevel: basis.activityLevel, energyCalculationMode: .dynamicHealth,
                    calorieDeficit: basis.calorieDeficit, calorieTarget: target,
                    isManualTarget: draft.appliesManualTarget,
                    proteinRatio: selection.protein, carbRatio: selection.carbs, fatRatio: selection.fat
                ))
                let budget = profile.activityBudget(
                    consumed: 0,
                    activeEnergyKcal: 0,
                    recentActiveEnergySamples: [],
                    isActivityLoading: false,
                    activityMessage: nil,
                    date: makeTestDate(year: 2020, month: 6, day: 15)
                )
                let hero = TodayHeroSummary(mealTotals: [:], budget: budget, locale: auditUS)
                let context = "manual \(isManual), deficit \(deficit), \(basis)"

                #expect(draft.appliesManualTarget == isManual, "\(context)")
                #expect(target == (isManual ? 1_850 : basis.calculatedTarget), "\(context)")
                #expect(
                    OnboardingFlow.step(after: .goalSummary, calorieTarget: target)
                        == .macroRatios(calorieTarget: plate.targetKcal, usesDirectGrams: false),
                    "\(context)"
                )

                #expect(profile.dailyCalorieTarget == plate.targetKcal, "\(context)")
                #expect(profile.bmr.truncatedSafely == plate.restKcal, "\(context)")
                #expect(profile.tdee.truncatedSafely == plate.burnKcal, "\(context)")
                #expect(profile.proteinTargetG == selection.grams(for: .protein), "\(context)")
                #expect(profile.carbTargetG == selection.grams(for: .carbs), "\(context)")
                #expect(profile.fatTargetG == selection.grams(for: .fat), "\(context)")
                #expect(profile.manualOverride == isManual, "\(context)")
                #expect(profile.energyCalculationMode == (isManual ? .lifestyleEstimate : .dynamicHealth), "\(context)")

                if !isManual {
                    #expect(
                        profile.dailyCalorieTarget
                            == NutritionCalculator.defaultTarget(tdee: profile.tdee, deficit: profile.calorieDeficit),
                        "\(context)"
                    )
                }

                #expect(budget.adjustedTarget == plate.targetKcal, "\(context)")
                #expect(hero.headline == plate.targetKcal, "\(context)")
                #expect(hero.caption == "kcal left of \(plate.targetKcal.formatted(.number.locale(auditUS)))", "\(context)")
                #expect(
                    SettingsGoalSummary.dailyTargetText(profile.dailyCalorieTarget, locale: auditUS)
                        == "\(plate.targetKcal.formatted(.number.locale(auditUS))) kcal a day",
                    "\(context)"
                )
                #expect(GoalEditSeed(profile: profile).targetText == "\(plate.targetKcal)", "\(context)")
                #expect(GoalEditSeed(profile: profile).manualOverride == isManual, "\(context)")
                let subtitle = SettingsGoalSummary.goalSubtitle(
                    calorieDeficit: profile.calorieDeficit,
                    isManualOverride: profile.manualOverride,
                    locale: .current
                )
                #expect(
                    subtitle == (isManual ? "A number you set yourself" : "About " + auditLowercasingFirst(plate.paceCaption)),
                    "\(context)"
                )
            }
        }
    }
}

@MainActor
@Suite("Onboarding nutrient selection audit")
struct AuditOnboardingNutrientSelectionTests {
    private var everySubset: [[TrackedNutrient]] {
        let optional = TrackedNutrient.editableGoalNutrients
        return (0 ..< (1 << optional.count)).map { mask in
            optional.enumerated().compactMap { index, nutrient in mask & (1 << index) != 0 ? nutrient : nil }
        }
    }

    @Test("For every subset of extras, the macros lead, the extras follow in order, and toggling is reversible")
    func everySubsetNormalizesAndToggles() {
        let core = TrackedNutrient.defaultSelection
        #expect(everySubset.count == 128)

        for subset in everySubset {
            let raw = TrackedNutrient.rawSelection(from: core + subset)
            let selection = OnboardingNutrientSelection(rawValue: raw)

            #expect(selection.selected == core + subset, "\(subset)")
            #expect(selection.extras == subset, "\(subset)")
            #expect(selection.normalizedRawValue == raw, "\(subset)")
            #expect(core.allSatisfy(selection.isSelected), "\(subset)")

            for nutrient in TrackedNutrient.editableGoalNutrients {
                let toggled = OnboardingNutrientSelection(rawValue: selection.toggling(nutrient))
                let back = toggled.toggling(nutrient)

                #expect(toggled.isSelected(nutrient) != selection.isSelected(nutrient), "\(subset) \(nutrient)")
                #expect(Array(toggled.selected.prefix(core.count)) == core, "\(subset) \(nutrient)")
                #expect(toggled.extras.filter { $0 != nutrient } == subset.filter { $0 != nutrient }, "\(subset) \(nutrient)")
                if subset.contains(nutrient) {
                    #expect(back == TrackedNutrient.rawSelection(from: core + subset.filter { $0 != nutrient } + [nutrient]))
                } else {
                    #expect(back == raw, "\(subset) \(nutrient)")
                }
            }
        }
    }

    @Test("A stored value holding only extras is read as stored but normalized with the macros in front")
    func extrasOnlyValuesNormalize() {
        let core = TrackedNutrient.defaultSelection

        for subset in everySubset {
            let selection = OnboardingNutrientSelection(rawValue: TrackedNutrient.rawSelection(from: subset))

            #expect(selection.extras == subset, "\(subset)")
            #expect(selection.normalizedRawValue == TrackedNutrient.rawSelection(from: core + subset), "\(subset)")
            #expect(selection.selected.count >= TrackedNutrient.minimumSelectionCount, "\(subset)")
            if subset.count >= TrackedNutrient.minimumSelectionCount {
                #expect(selection.isSelected(.protein) == false, "\(subset)")
            }
        }
    }
}

@MainActor
@Suite("Settings calorie estimate audit")
struct AuditSettingsCalorieEstimateTests {
    @Test("Every combination of the four facts gives one consistent toggle, icon, subtitle and footer")
    func everyCombinationIsConsistent() {
        for isManual in [false, true] {
            for mode in EnergyCalculationMode.allCases {
                for isHealthAvailable in [false, true] {
                    for isRequesting in [false, true] {
                        let estimate = SettingsCalorieEstimate(
                            isManualOverride: isManual,
                            energyCalculationMode: mode,
                            isHealthAvailable: isHealthAvailable,
                            isRequestingAuthorization: isRequesting
                        )
                        let isOn = !isManual && mode == .dynamicHealth
                        let context = "manual \(isManual), \(mode), health \(isHealthAvailable), requesting \(isRequesting)"

                        #expect(estimate.effectiveEnergyCalculationMode == (isManual ? .lifestyleEstimate : mode), "\(context)")
                        #expect(estimate.isToggleBound == !isManual, "\(context)")
                        #expect(estimate.isToggleOn == isOn, "\(context)")
                        #expect(estimate.showsDynamicMetrics == isOn, "\(context)")
                        #expect(estimate.isActiveEnergyTrackingEnabled == isOn, "\(context)")
                        #expect(estimate.modeIconName == (isOn ? "heart.text.square.fill" : "figure.walk"), "\(context)")
                        #expect(estimate.modeSubtitle.hasPrefix("On") == isOn, "\(context)")
                        #expect(estimate.isToggleDisabled == (isManual || isRequesting || (!isOn && !isHealthAvailable)), "\(context)")
                        #expect(estimate.isDynamicStatusInformational == (mode == .dynamicHealth), "\(context)")

                        let footer = estimate.footerText
                        if isManual {
                            #expect(footer == "Manual calorie targets stay fixed until you turn the override off.", "\(context)")
                        } else if !isHealthAvailable {
                            #expect(footer == AppleHealthAdjustmentSettings.unavailableMessage, "\(context)")
                        } else if isOn {
                            #expect(footer.hasPrefix("Auto-adjust uses Apple Health activity"), "\(context)")
                        } else {
                            #expect(footer.hasPrefix("Your activity level sets the estimate."), "\(context)")
                        }
                    }
                }
            }
        }
    }

    @Test(
        "Settings, the activity lock and the budget agree on whether Apple Health drives the target",
        arguments: [false, true], EnergyCalculationMode.allCases
    )
    func settingsAgreeWithTheProfile(isManual: Bool, mode: EnergyCalculationMode) {
        let profile = UserProfile(
            age: 30, sex: .male, heightCm: 180, weightKg: 80, activityLevel: .moderatelyActive,
            manualOverride: isManual, energyCalculationMode: mode
        )
        let estimate = SettingsCalorieEstimate(
            isManualOverride: profile.manualOverride,
            energyCalculationMode: profile.energyCalculationMode,
            isHealthAvailable: true,
            isRequestingAuthorization: false
        )
        let budget = profile.activityBudget(
            consumed: 0,
            activeEnergyKcal: 0,
            recentActiveEnergySamples: [],
            isActivityLoading: false,
            activityMessage: nil,
            date: makeTestDate(year: 2020, month: 6, day: 15)
        )

        #expect(estimate.effectiveEnergyCalculationMode == profile.effectiveEnergyCalculationMode)
        #expect(ProfileEditActivityLevelPolicy.isLocked(for: profile) == estimate.isToggleOn)
        #expect(budget.isDynamicModeRequested == estimate.isActiveEnergyTrackingEnabled)
    }

    @Test(
        "Any tracker message, even an empty one, drops auto-adjust back to the lifestyle estimate",
        arguments: [nil, "", "Health access denied."], EnergyCalculationMode.allCases
    )
    func trackerMessageFallback(message: String?, mode: EnergyCalculationMode) {
        #expect(
            SettingsCalorieEstimate.fallsBackToLifestyle(energyCalculationMode: mode, trackerMessage: message)
                == (message != nil && mode == .dynamicHealth)
        )
    }

    @Test(
        "Settings and Nutrition Details render the same Apple Health figures the same way",
        arguments: [0.0, 0.4, 0.5, 49.5, 299.5, 300.49, -0.5, 1e30, .nan, .infinity, -.infinity]
    )
    func healthFiguresMatchNutritionDetails(kcal: Double) {
        #expect(
            SettingsCalorieEstimate.todayText(activeEnergyKcal: kcal)
                == NutritionDetailsSummary.activeEnergyText(activeEnergyKcal: kcal)
        )
        #expect(
            SettingsCalorieEstimate.baselineText(activityBaselineKcal: kcal)
                == NutritionDetailsSummary.baselineText(activityBaselineKcal: kcal)
        )
    }

    @Test(
        "Health figures round half away from zero to whole kilocalories",
        arguments: [
            (0.4, "0 kcal"),
            (0.5, "1 kcal"),
            (49.5, "50 kcal"),
            (299.5, "300 kcal"),
            (300.49, "300 kcal"),
            (Double.nan, "0 kcal"),
            (Double.infinity, "0 kcal"),
        ]
    )
    func healthFiguresRound(kcal: Double, expected: String) {
        #expect(SettingsCalorieEstimate.todayText(activeEnergyKcal: kcal) == expected)
        #expect(SettingsCalorieEstimate.baselineText(activityBaselineKcal: kcal) == expected)
    }

    @Test("No baseline reads as a dash on both surfaces")
    func missingBaselineIsADash() {
        #expect(SettingsCalorieEstimate.baselineText(activityBaselineKcal: nil) == "-")
        #expect(NutritionDetailsSummary.baselineText(activityBaselineKcal: nil) == "-")
    }

    @Test("The valid-days row reads the budget's own count against the required seven", arguments: [0, 1, 6, 7, 14, 21])
    func validDaysReadAgainstTheRequiredCount(days: Int) {
        let reference = makeTestDate(year: 2020, month: 6, day: 15)
        let budget = ActivityCalorieBudget(
            consumed: 0,
            staticTarget: 2_000,
            bmr: 1_600,
            calorieDeficit: 300,
            activeEnergyKcal: 0,
            recentActiveEnergySamples: (0 ..< days).map {
                DailyActiveEnergySample(date: reference.addingTimeInterval(-86_400 * Double($0 + 1)), activeEnergyKcal: 300)
            },
            calculationMode: .dynamicHealth,
            isManualOverride: false,
            isActivityLoading: false,
            activityMessage: nil,
            date: reference
        )

        #expect(SettingsCalorieEstimate.validActivityDaysText(validActivityDays: budget.validActivityDays) == "\(days)/7")
        #expect(SettingsCalorieEstimate.validActivityDaysDescription.contains("7 days are needed"))
        #expect((budget.dynamicStatus == .ready) == (days >= 7))
    }
}

@MainActor
@Suite("Settings goal and profile rows audit")
struct AuditSettingsRowsTests {
    @Test(
        "The daily target headline groups at the thousand and at the top of the calorie domain",
        arguments: [
            (0, auditUS, "0 kcal a day"),
            (999, auditUS, "999 kcal a day"),
            (1_000, auditUS, "1,000 kcal a day"),
            (1_000, auditDanish, "1.000 kcal a day"),
            (1_000_000_000, auditUS, "1,000,000,000 kcal a day"),
        ]
    )
    func dailyTargetHeadline(target: Int, locale: Locale, expected: String) {
        #expect(SettingsGoalSummary.dailyTargetText(target, locale: locale) == expected)
    }

    @Test("Every nutrient reads its goal with the wording of its kind, written and spoken")
    func everyNutrientAndKindIsWorded() {
        for nutrient in TrackedNutrient.allCases {
            for kind in NutrientGoalKind.allCases {
                let summary = SettingsGoalSummary(targets: [nutrient: 30], goalKinds: [nutrient: kind])
                let written = nutrient.unit.formatted(30, locale: auditUS)
                let spoken = nutrient.unit.spokenFormatted(30)
                let prefix = switch kind {
                case .minimum: "At least "
                case .target: ""
                case .maximum: "At most "
                }

                #expect(summary.nutrients == [nutrient])
                #expect(summary.text(for: nutrient, locale: auditUS) == prefix + written, "\(nutrient) \(kind)")
                #expect(summary.spokenText(for: nutrient) == prefix + spoken, "\(nutrient) \(kind)")
            }
        }
    }

    @Test("A nutrient with no saved goal gets no row, and reads as not set if asked")
    func nutrientsWithoutAGoalAreNotSet() {
        let summary = SettingsGoalSummary(targets: [.fiber: 30], goalKinds: [:])

        for nutrient in TrackedNutrient.allCases where nutrient != .fiber {
            #expect(!summary.nutrients.contains(nutrient))
            #expect(summary.text(for: nutrient, locale: auditUS) == SettingsGoalSummary.notSetText)
            #expect(summary.spokenText(for: nutrient) == SettingsGoalSummary.notSetText)
        }
    }

    @Test("Every height the About You slider can produce reads the same in Settings")
    func heightsMatchTheOnboardingReadout() {
        let range = OnboardingPersonalInfo.heightRange
        for height in stride(from: range.lowerBound, through: range.upperBound, by: OnboardingPersonalInfo.heightStep) {
            let summary = SettingsProfileSummary(age: 30, sex: .male, heightCm: height, weightKg: 70, activityLevel: .sedentary)

            #expect(summary.heightText == OnboardingPersonalInfo.heightLabel(height))
            #expect(summary.heightText == "\(Int(height)) cm")
        }
    }

    @Test("Every weight the About You slider can produce reads the same in Settings, in either locale")
    func weightsMatchTheOnboardingReadout() {
        let range = OnboardingPersonalInfo.weightRange
        for weight in stride(from: range.lowerBound, through: range.upperBound, by: OnboardingPersonalInfo.weightStep) {
            let summary = SettingsProfileSummary(age: 30, sex: .male, heightCm: 175, weightKg: weight, activityLevel: .sedentary)

            for locale in [auditUS, auditDanish] {
                #expect(summary.weightText(locale: locale) == OnboardingPersonalInfo.weightLabel(weight, locale: locale))
            }
            let usText = summary.weightText(locale: auditUS)
            #expect(usText.hasSuffix(".0 kg") || usText.hasSuffix(".5 kg"), "\(weight)")
        }
    }

    @Test("Without a locale the weight row uses the reader's own")
    func weightTextUsesTheCurrentLocale() {
        let summary = SettingsProfileSummary(age: 30, sex: .female, heightCm: 165, weightKg: 62.5, activityLevel: .lightlyActive)

        #expect(summary.weightText == summary.weightText(locale: .current))
    }

    @Test("Ages, sexes and activity levels read the same in Settings as they were chosen")
    func agesSexesAndActivityLevels() {
        for age in [OnboardingPersonalInfo.ageRange.lowerBound, 30, OnboardingPersonalInfo.ageRange.upperBound] {
            let summary = SettingsProfileSummary(age: age, sex: .male, heightCm: 175, weightKg: 70, activityLevel: .sedentary)
            #expect(summary.ageText == "\(age)")
            #expect(OnboardingPersonalInfo.ageLabel(age) == "\(summary.ageText) years")
        }
        for sex in Sex.allCases {
            #expect(SettingsProfileSummary(age: 30, sex: sex, heightCm: 175, weightKg: 70, activityLevel: .sedentary).sexText == sex.displayName)
        }
        let expectedActivity: [ActivityLevel: String] = [
            .sedentary: "Sedentary",
            .lightlyActive: "Lightly active",
            .moderatelyActive: "Moderately active",
            .veryActive: "Very active",
            .extraActive: "Extra active",
        ]
        for activity in ActivityLevel.allCases {
            let summary = SettingsProfileSummary(age: 30, sex: .male, heightCm: 175, weightKg: 70, activityLevel: activity)
            #expect(summary.activityText == expectedActivity[activity])
        }
    }
}
