import SwiftUI

struct MacroRatioStepView: View {
    let calorieTarget: Int
    @Binding var proteinRatio: Double
    @Binding var carbRatio: Double
    @Binding var fatRatio: Double
    var usesDirectGrams = false
    @Binding var gramGoals: MacroGramGoals
    var primaryButtonTitle = "Start tracking"
    var onComplete: () -> Void
    @FocusState private var focusedMacro: MacroRatioSelection.Macro?

    private var selection: MacroRatioSelection {
        MacroRatioSelection(
            calorieTarget: calorieTarget,
            protein: proteinRatio,
            carbs: carbRatio,
            fat: fatRatio
        )
    }

    private var canContinue: Bool {
        usesDirectGrams ? gramGoals.isValid : selection.isValid
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                OnboardingStepHeader(
                    title: usesDirectGrams ? "Macro goals" : "Macro ratios",
                    subtitle: usesDirectGrams
                        ? "Set the protein, carbs, and fat you want each day."
                        : "Fine-tune how your \(calorieTarget.formatted()) kcal are split."
                )

                if usesDirectGrams {
                    gramFields
                } else {
                    ratioFields
                }

                if let validationMessage = usesDirectGrams ? gramGoals.validationMessage : selection.validationMessage {
                    Text(validationMessage)
                        .font(OnboardingTypography.detail.weight(.semibold))
                        .foregroundStyle(CalorynTheme.textPrimary)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, CalorynTheme.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom) {
            OnboardingActionBar {
                Button(action: onComplete) {
                    Text(primaryButtonTitle)
                }
                .calorynPrimaryButton()
                .disabled(!canContinue)
                .accessibilityIdentifier("onboarding.macroRatios.continue")
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    skip()
                } label: {
                    Text("Skip")
                        .font(CalorynTheme.toolbarAction)
                        .foregroundStyle(CalorynTheme.accent)
                }
            }
        }
        .calorynPageCanvas()
        .calorynDrillDownNavigation()
    }

    private var ratioFields: some View {
        VStack(spacing: 0) {
            OnboardingHairline()
            macroSlider(macro: .protein, ratio: $proteinRatio)
            OnboardingHairline()
            macroSlider(macro: .carbs, ratio: $carbRatio)
            OnboardingHairline()
            macroSlider(macro: .fat, ratio: $fatRatio)
        }
    }

    private var gramFields: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHairline()
            gramField(macro: .protein, text: proteinText)
            OnboardingHairline()
            gramField(macro: .carbs, text: carbText)
            OnboardingHairline()
            gramField(macro: .fat, text: fatText)

            if let summary = gramGoals.accountSummary(calorieTarget: calorieTarget) {
                Text(summary)
                    .font(OnboardingTypography.detail)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .padding(.top, 16)
                    .accessibilityIdentifier("onboarding.macroGrams.account")
            }
        }
    }

    private var proteinText: Binding<String> {
        Binding(get: { gramGoals.proteinText }, set: { gramGoals.proteinText = $0 })
    }

    private var carbText: Binding<String> {
        Binding(get: { gramGoals.carbText }, set: { gramGoals.carbText = $0 })
    }

    private var fatText: Binding<String> {
        Binding(get: { gramGoals.fatText }, set: { gramGoals.fatText = $0 })
    }

    private func skip() {
        if usesDirectGrams {
            gramGoals = .derived(
                calorieTarget: calorieTarget,
                protein: MacroRatioSelection.defaultSplit.protein,
                carbs: MacroRatioSelection.defaultSplit.carbs,
                fat: MacroRatioSelection.defaultSplit.fat
            )
        } else {
            proteinRatio = MacroRatioSelection.defaultSplit.protein
            carbRatio = MacroRatioSelection.defaultSplit.carbs
            fatRatio = MacroRatioSelection.defaultSplit.fat
        }
        onComplete()
    }

    private func macroSlider(
        macro: MacroRatioSelection.Macro,
        ratio: Binding<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            OnboardingAdaptiveRow(alignment: .firstTextBaseline, spacing: 10) {
                Text(macro.displayName)
                    .font(OnboardingTypography.choiceTitle)
                    .foregroundStyle(CalorynTheme.textPrimary)
            } trailing: {
                Text(selection.percentText(for: macro))
                    .font(CalorynTheme.numericBody.weight(.semibold))
                    .foregroundStyle(CalorynTheme.textPrimary)
                Text(selection.gramsText(for: macro))
                    .font(OnboardingTypography.rowValue)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .frame(minWidth: 48, alignment: .trailing)
            }
            .accessibilityElement(children: .combine)

            OnboardingSlider(value: ratio, range: macro.sliderRange, step: 0.05, label: macro.displayName)
        }
        .padding(.vertical, 14)
    }

    private func gramField(macro: MacroRatioSelection.Macro, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            OnboardingAdaptiveRow(alignment: .firstTextBaseline, spacing: 10) {
                Text(macro.displayName)
                    .font(OnboardingTypography.choiceTitle)
                    .foregroundStyle(CalorynTheme.textPrimary)
            } trailing: {
                Text(gramGoals.sharePercentText(for: macro, calorieTarget: calorieTarget))
                    .font(CalorynTheme.numericBody.weight(.semibold))
                    .foregroundStyle(CalorynTheme.textPrimary)
                TextField("0", text: text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(CalorynTheme.numericBody)
                    .foregroundStyle(CalorynTheme.textPrimary)
                    .focused($focusedMacro, equals: macro)
                    .calorynInputField(isFocused: focusedMacro == macro)
                    .frame(width: 88)
                    .accessibilityIdentifier("onboarding.macroGrams.\(macroIdentifier(macro))")
                    .accessibilityLabel("\(macro.displayName) goal in grams")
                Text("g")
                    .font(OnboardingTypography.rowValue)
                    .foregroundStyle(CalorynTheme.textSecondary)
            }
        }
        .padding(.vertical, 14)
    }

    private func macroIdentifier(_ macro: MacroRatioSelection.Macro) -> String {
        switch macro {
        case .protein: "protein"
        case .carbs: "carbs"
        case .fat: "fat"
        }
    }
}

#Preview {
    NavigationStack {
        MacroRatioStepView(
            calorieTarget: 2000,
            proteinRatio: .constant(0.30),
            carbRatio: .constant(0.40),
            fatRatio: .constant(0.30),
            gramGoals: .constant(.empty)
        ) { }
    }
}
