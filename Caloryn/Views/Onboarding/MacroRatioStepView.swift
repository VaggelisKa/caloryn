import SwiftUI

struct MacroRatioStepView: View {
    let calorieTarget: Int
    @Binding var proteinRatio: Double
    @Binding var carbRatio: Double
    @Binding var fatRatio: Double
    var primaryButtonTitle = "Start Tracking"
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
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Macro Ratios")
                        .font(CalorynTheme.sectionTitle)
                        .foregroundStyle(CalorynTheme.textPrimary)
                    Text("Fine-tune how your \(calorieTarget) kcal are split.")
                        .font(CalorynTheme.bodyText)
                        .foregroundStyle(CalorynTheme.textSecondary)
                }
                .padding(.top, 8)

                macroSlider(macro: .protein, ratio: $proteinRatio)
                macroSlider(macro: .carbs, ratio: $carbRatio)
                macroSlider(macro: .fat, ratio: $fatRatio)

                if let validationMessage = selection.validationMessage {
                    Text(validationMessage)
                        .font(CalorynTheme.caption)
                        .foregroundStyle(CalorynTheme.terracotta)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, CalorynTheme.pagePadding)
            .padding(.bottom, 100)
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: onComplete) {
                Text(primaryButtonTitle)
                    .font(CalorynTheme.buttonLabel)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .adaptiveGlassProminentButton()
            .disabled(!selection.isValid)
            .padding(.horizontal, CalorynTheme.pagePadding)
            .padding(.bottom, 16)
            .accessibilityIdentifier("onboarding.macroRatios.continue")
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
                        .foregroundStyle(CalorynTheme.textSecondary)
                }
            }
        }
        .calorynPageCanvas()
        // The existing toolbar item is `topBarTrailing`; the drill-down modifier
        // owns `topBarLeading`, so this screen does not end up with two back
        // buttons the way `PortionPickerView` would.
        .calorynDrillDownNavigation()
    }

    // MARK: - Macro Slider

    private func color(for macro: MacroRatioSelection.Macro) -> Color {
        switch macro {
        case .protein: CalorynTheme.proteinColor
        case .carbs: CalorynTheme.carbColor
        case .fat: CalorynTheme.fatColor
        }
    }

    private func macroSlider(
        macro: MacroRatioSelection.Macro,
        ratio: Binding<Double>
    ) -> some View {
        let color = color(for: macro)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                Text(macro.displayName)
                    .font(CalorynTheme.itemTitle)
                    .foregroundStyle(CalorynTheme.textPrimary)
                Spacer()
                Text(selection.percentText(for: macro))
                    .font(CalorynTheme.numericBody)
                    .foregroundStyle(color)
                Text("·")
                    .foregroundStyle(CalorynTheme.textSecondary)
                Text(selection.gramsText(for: macro))
                    .font(CalorynTheme.numericCaption)
                    .foregroundStyle(CalorynTheme.textSecondary)
            }
            Slider(value: ratio, in: macro.sliderRange, step: 0.05)
                .tint(color)
        }
        .glassCard(cornerRadius: CalorynTheme.smallCornerRadius)
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
