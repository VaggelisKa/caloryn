import SwiftUI

struct GoalSummaryStepView: View {
    let age: Int
    let sex: Sex
    let heightCm: Double
    let weightKg: Double
    let activityLevel: ActivityLevel
    @Binding var calorieDeficit: Double
    var onContinue: (Int, Bool) -> Void

    @State private var manualTarget: String = ""
    @State private var useManualOverride = false
    @FocusState private var isManualTargetFocused: Bool

    private var bmr: Double {
        NutritionCalculator.bmr(sex: sex, weightKg: weightKg, heightCm: heightCm, age: age)
    }

    private var tdee: Double {
        NutritionCalculator.tdee(bmr: bmr, activity: activityLevel)
    }

    private var calculatedTarget: Int {
        NutritionCalculator.defaultTarget(tdee: tdee, deficit: calorieDeficit)
    }

    private var appliesManualTarget: Bool {
        if useManualOverride, let manual = Int(manualTarget), manual >= 1000 {
            return true
        }
        return false
    }

    private var displayTarget: Int {
        if appliesManualTarget, let manual = Int(manualTarget) {
            return manual
        }
        return calculatedTarget
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Text("Your Goal")
                        .font(CalorynTheme.sectionTitle)
                        .foregroundStyle(CalorynTheme.textPrimary)
                    Text("Based on your profile, here's your plan.")
                        .font(CalorynTheme.bodyText)
                        .foregroundStyle(CalorynTheme.textSecondary)
                }
                .padding(.top, 8)

                targetDisplay

                statsCards

                deficitSlider

                manualOverrideSection
            }
            .padding(.horizontal, CalorynTheme.pagePadding)
            .padding(.bottom, 100)
        }
        .safeAreaInset(edge: .bottom) {
            Button { onContinue(displayTarget, appliesManualTarget) } label: {
                Text("Continue")
                    .font(CalorynTheme.buttonLabel)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .adaptiveGlassProminentButton()
            .padding(.horizontal, CalorynTheme.pagePadding)
            .padding(.bottom, 16)
            .accessibilityIdentifier("onboarding.goalSummary.continue")
        }
        .onChange(of: calculatedTarget) {
            if !useManualOverride {
                manualTarget = "\(calculatedTarget)"
            }
        }
        .onAppear {
            manualTarget = "\(calculatedTarget)"
        }
    }

    private var targetDisplay: some View {
        VStack(spacing: 6) {
            Text("\(displayTarget)")
                .font(CalorynTheme.displayNumber)
                .foregroundStyle(CalorynTheme.sage)
                .accessibilityIdentifier("onboarding.goalSummary.target")
            Text("daily calories")
                .font(CalorynTheme.bodyText)
                .foregroundStyle(CalorynTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .glassCard()
    }

    private var statsCards: some View {
        HStack(spacing: CalorynTheme.cardSpacing) {
            statPill("BMR", value: "\(Int(bmr))", unit: "kcal")
            statPill("Daily Burn", value: "\(Int(tdee))", unit: "kcal")
            statPill("Deficit", value: "\(Int(calorieDeficit))", unit: "kcal")
        }
    }

    private func statPill(_ label: String, value: String, unit: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(CalorynTheme.caption)
                .foregroundStyle(CalorynTheme.textSecondary)
            Text(value)
                .font(CalorynTheme.numericBody)
                .foregroundStyle(CalorynTheme.textPrimary)
            Text(unit)
                .font(CalorynTheme.numericMicroCaption)
                .foregroundStyle(CalorynTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .glassCard(cornerRadius: CalorynTheme.smallCornerRadius)
    }

    private var deficitSlider: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CALORIE ADJUSTMENT")
                .font(CalorynTheme.sectionEyebrow)
                .foregroundStyle(CalorynTheme.textSecondary)

            HStack {
                Text("Surplus")
                    .font(CalorynTheme.microCaption)
                    .foregroundStyle(CalorynTheme.textSecondary)
                Slider(value: $calorieDeficit, in: -500...1000, step: 50)
                    .disabled(useManualOverride)
                Text("Deficit")
                    .font(CalorynTheme.microCaption)
                    .foregroundStyle(CalorynTheme.textSecondary)
            }

            Text(deficitLabel)
                .font(CalorynTheme.caption)
                .foregroundStyle(CalorynTheme.terracotta)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .glassCard(cornerRadius: CalorynTheme.smallCornerRadius)
    }

    private var deficitLabel: String {
        if calorieDeficit > 0 {
            return "-\(Int(calorieDeficit)) kcal/day (lose weight)"
        } else if calorieDeficit < 0 {
            return "+\(Int(abs(calorieDeficit))) kcal/day (gain weight)"
        }
        return "Maintenance (no change)"
    }

    private var manualOverrideSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $useManualOverride) {
                Text("Set custom target")
                    .font(CalorynTheme.bodyText)
                    .foregroundStyle(CalorynTheme.textPrimary)
            }

            if useManualOverride {
                HStack {
                    TextField("Calories", text: $manualTarget)
                        .keyboardType(.numberPad)
                        .font(CalorynTheme.numericBody)
                        .focused($isManualTargetFocused)
                        .calorynInputField(isFocused: isManualTargetFocused)
                    Text("kcal/day")
                        .font(CalorynTheme.caption)
                        .foregroundStyle(CalorynTheme.textSecondary)
                }
            }
        }
        .glassCard(cornerRadius: CalorynTheme.smallCornerRadius)
    }
}

#Preview {
    NavigationStack {
        GoalSummaryStepView(
            age: 30,
            sex: .male,
            heightCm: 180,
            weightKg: 80,
            activityLevel: .moderatelyActive,
            calorieDeficit: .constant(500)
        ) { _, _ in }
    }
}
