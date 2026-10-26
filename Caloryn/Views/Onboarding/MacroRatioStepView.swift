import SwiftUI

struct MacroRatioStepView: View {
    let calorieTarget: Int
    @Binding var proteinRatio: Double
    @Binding var carbRatio: Double
    @Binding var fatRatio: Double
    var primaryButtonTitle = "Start tracking"
    var onComplete: () -> Void

    private var selection: MacroRatioSelection {
        MacroRatioSelection(
            calorieTarget: calorieTarget,
            protein: proteinRatio,
            carbs: carbRatio,
            fat: fatRatio
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                OnboardingStepHeader(
                    title: "Macro ratios",
                    subtitle: "Fine-tune how your \(calorieTarget.formatted()) kcal are split."
                )

                VStack(spacing: 0) {
                    OnboardingHairline()
                    macroSlider(macro: .protein, ratio: $proteinRatio)
                    OnboardingHairline()
                    macroSlider(macro: .carbs, ratio: $carbRatio)
                    OnboardingHairline()
                    macroSlider(macro: .fat, ratio: $fatRatio)
                }

                if let validationMessage = selection.validationMessage {
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
                .disabled(!selection.isValid)
                .accessibilityIdentifier("onboarding.macroRatios.continue")
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    proteinRatio = MacroRatioSelection.defaultSplit.protein
                    carbRatio    = MacroRatioSelection.defaultSplit.carbs
                    fatRatio     = MacroRatioSelection.defaultSplit.fat
                    onComplete()
                } label: {
                    Text("Skip")
                        .font(CalorynTheme.toolbarAction)
                        .foregroundStyle(CalorynTheme.textPrimary)
                }
            }
        }
        .calorynPageCanvas()
        // The existing toolbar item is `topBarTrailing`; the drill-down modifier
        // owns `cancellationAction` (the leading slot), so this screen does not end
        // up with two back buttons the way `PortionPickerView` would.
        .calorynDrillDownNavigation()
    }

    // MARK: - Macro Slider

    /// Macros are told apart by their label, never by colour: one ink for all three. At
    /// accessibility sizes the name goes above its figures, so it is never broken mid-word.
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
}

#Preview {
    NavigationStack {
        MacroRatioStepView(
            calorieTarget: 2000,
            proteinRatio: .constant(0.30),
            carbRatio: .constant(0.40),
            fatRatio: .constant(0.30)
        ) { }
    }
}
