import SwiftUI

struct PersonalInfoStepView: View {
    @Binding var age: Int
    @Binding var sex: Sex
    @Binding var heightCm: Double
    @Binding var weightKg: Double
    var onContinue: () -> Void

    @ScaledMetric private var spacing: CGFloat = 24

    var body: some View {
        ScrollView {
            VStack(spacing: spacing) {
                VStack(spacing: 8) {
                    Text("About You")
                        .font(CalorynTheme.sectionTitle)
                        .foregroundStyle(CalorynTheme.textPrimary)
                    Text("We'll use this to calculate your daily target.")
                        .font(CalorynTheme.bodyText)
                        .foregroundStyle(CalorynTheme.textSecondary)
                }
                .padding(.top, 8)

                VStack(spacing: CalorynTheme.cardSpacing) {
                    fieldCard("Sex") {
                        Picker("Sex", selection: $sex) {
                            ForEach(Sex.allCases) { s in
                                Text(s.displayName).tag(s)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    fieldCard("Age") {
                        HStack {
                            Text(OnboardingPersonalInfo.ageLabel(age))
                                .font(CalorynTheme.numericBody)
                                .foregroundStyle(CalorynTheme.textPrimary)
                            Spacer()
                            Stepper("", value: $age, in: OnboardingPersonalInfo.ageRange)
                                .labelsHidden()
                        }
                    }

                    fieldCard("Height") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(OnboardingPersonalInfo.heightLabel(heightCm))
                                .font(CalorynTheme.numericBody)
                                .foregroundStyle(CalorynTheme.textPrimary)
                            Slider(
                                value: $heightCm,
                                in: OnboardingPersonalInfo.heightRange,
                                step: OnboardingPersonalInfo.heightStep
                            )
                        }
                    }

                    fieldCard("Weight") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(OnboardingPersonalInfo.weightLabel(weightKg))
                                .font(CalorynTheme.numericBody)
                                .foregroundStyle(CalorynTheme.textPrimary)
                            Slider(
                                value: $weightKg,
                                in: OnboardingPersonalInfo.weightRange,
                                step: OnboardingPersonalInfo.weightStep
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, CalorynTheme.pagePadding)
            .padding(.bottom, 100)
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: onContinue) {
                Text("Continue")
                    .font(CalorynTheme.buttonLabel)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .adaptiveGlassProminentButton()
            .padding(.horizontal, CalorynTheme.pagePadding)
            .padding(.bottom, 16)
            .accessibilityIdentifier("onboarding.personalInfo.continue")
        }
        .calorynPageCanvas()
        // This step hides the navigation bar outright, so there is no back
        // button to replace — `calorynDrillDownNavigation()` would install a
        // toolbar item into a bar that is never shown.
        .toolbarVisibility(.hidden, for: .navigationBar)
    }

    private func fieldCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(CalorynTheme.sectionEyebrow)
                .foregroundStyle(CalorynTheme.textSecondary)
                .textCase(.uppercase)
            content()
        }
        .glassCard(cornerRadius: CalorynTheme.smallCornerRadius)
    }
}

#Preview {
    NavigationStack {
        PersonalInfoStepView(
            age: .constant(30),
            sex: .constant(.male),
            heightCm: .constant(175),
            weightKg: .constant(75)
        ) { }
    }
}
