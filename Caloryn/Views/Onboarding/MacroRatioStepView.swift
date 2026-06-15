import SwiftUI

struct MacroRatioStepView: View {
    let calorieTarget: Int
    @Binding var proteinRatio: Double
    @Binding var carbRatio: Double
    @Binding var fatRatio: Double
    var primaryButtonTitle = "Start Tracking"
    var onComplete: () -> Void

    private var total: Double { proteinRatio + carbRatio + fatRatio }
    private var isValid: Bool { abs(total - 1.0) <= 0.01 }

    private var proteinGrams: Double {
        NutritionCalculator.macroGrams(calories: Double(calorieTarget), ratio: proteinRatio, caloriesPerGram: 4)
    }

    private var carbGrams: Double {
        NutritionCalculator.macroGrams(calories: Double(calorieTarget), ratio: carbRatio, caloriesPerGram: 4)
    }

    private var fatGrams: Double {
        NutritionCalculator.macroGrams(calories: Double(calorieTarget), ratio: fatRatio, caloriesPerGram: 9)
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

                macroSlider(
                    name: "Protein",
                    ratio: $proteinRatio,
                    grams: proteinGrams,
                    color: CalorynTheme.proteinColor,
                    range: 0.10...0.50
                )

                macroSlider(
                    name: "Carbs",
                    ratio: $carbRatio,
                    grams: carbGrams,
                    color: CalorynTheme.carbColor,
                    range: 0.10...0.60
                )

                macroSlider(
                    name: "Fat",
                    ratio: $fatRatio,
                    grams: fatGrams,
                    color: CalorynTheme.fatColor,
                    range: 0.10...0.50
                )

                if !isValid {
                    Text("Ratios should total 100% (currently \(Int(total * 100))%)")
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
                    .font(.system(.headline, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .adaptiveGlassProminentButton()
            .tint(CalorynTheme.sage)
            .disabled(!isValid)
            .padding(.horizontal, CalorynTheme.pagePadding)
            .padding(.bottom, 16)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Skip") {
                    proteinRatio = 0.30
                    carbRatio    = 0.40
                    fatRatio     = 0.30
                    onComplete()
                }
                .foregroundStyle(CalorynTheme.textSecondary)
            }
        }
    }

    // MARK: - Macro Slider

    private func macroSlider(
        name: String,
        ratio: Binding<Double>,
        grams: Double,
        color: Color,
        range: ClosedRange<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                Text(name)
                    .font(CalorynTheme.itemTitle)
                    .foregroundStyle(CalorynTheme.textPrimary)
                Spacer()
                Text("\(Int(ratio.wrappedValue * 100))%")
                    .font(CalorynTheme.numericBody)
                    .foregroundStyle(color)
                Text("·")
                    .foregroundStyle(CalorynTheme.textSecondary)
                Text("\(Int(grams))g")
                    .font(CalorynTheme.numericCaption)
                    .foregroundStyle(CalorynTheme.textSecondary)
            }
            Slider(value: ratio, in: range, step: 0.05)
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
