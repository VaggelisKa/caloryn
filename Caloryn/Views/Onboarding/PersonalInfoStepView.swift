import SwiftUI

struct PersonalInfoStepView: View {
    @Binding var age: Int
    @Binding var sex: Sex
    @Binding var heightCm: Double
    @Binding var weightKg: Double
    var onContinue: () -> Void

    @ScaledMetric private var spacing: CGFloat = 26
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: spacing) {
                OnboardingStepHeader(
                    title: "About you",
                    subtitle: "We'll use this to calculate your daily target."
                )

                VStack(spacing: 0) {
                    sexRow
                    OnboardingHairline()
                    ageRow
                    OnboardingHairline()
                    sliderRow(
                        "Height",
                        value: OnboardingPersonalInfo.heightLabel(heightCm),
                        binding: $heightCm,
                        range: OnboardingPersonalInfo.heightRange,
                        step: OnboardingPersonalInfo.heightStep
                    )
                    OnboardingHairline()
                    sliderRow(
                        "Weight",
                        value: OnboardingPersonalInfo.weightLabel(weightKg),
                        binding: $weightKg,
                        range: OnboardingPersonalInfo.weightRange,
                        step: OnboardingPersonalInfo.weightStep
                    )
                }
            }
            .padding(.horizontal, CalorynTheme.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom) {
            OnboardingActionBar {
                Button(action: onContinue) {
                    Text("Continue")
                }
                .calorynPrimaryButton()
                .accessibilityIdentifier("onboarding.personalInfo.continue")
            }
        }
        .calorynPageCanvas()
        .toolbarVisibility(.hidden, for: .navigationBar)
    }

    private var sexRow: some View {
        OnboardingAdaptiveRow {
            rowLabel("Sex")
        } trailing: {
            let chips = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(WrappingChipFlow())
                : AnyLayout(HStackLayout(spacing: 8))
            chips {
                ForEach(Sex.allCases) { option in
                    Button {
                        withAnimation(.smooth(duration: 0.2)) {
                            sex = option
                        }
                    } label: {
                        Text(option.displayName)
                            .calorynChip(isSelected: sex == option)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(sex == option ? .isSelected : [])
                }
            }
        }
        .padding(.vertical, 14)
    }

    private var ageRow: some View {
        let range = OnboardingPersonalInfo.ageRange

        return OnboardingAdaptiveRow {
            rowLabel("Age")
                .accessibilityHidden(true)
        } trailing: {
            CalorynStepperPill(
                accessibilityTitle: "Age",
                value: OnboardingPersonalInfo.ageLabel(age),
                size: .compact,
                canDecrement: age > range.lowerBound,
                canIncrement: age < range.upperBound,
                onDecrement: { age = max(range.lowerBound, age - 1) },
                onIncrement: { age = min(range.upperBound, age + 1) }
            )
        }
        .padding(.vertical, 12)
    }

    private func sliderRow(
        _ label: String,
        value: String,
        binding: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                rowLabel(label)
                Spacer(minLength: 8)
                Text(value)
                    .font(CalorynTheme.numericBody)
                    .foregroundStyle(CalorynTheme.textPrimary)
            }

            OnboardingSlider(value: binding, range: range, step: step, label: label)
        }
        .padding(.vertical, 14)
    }

    private func rowLabel(_ text: String) -> some View {
        Text(text)
            .font(CalorynTheme.bodyText)
            .foregroundStyle(CalorynTheme.textPrimary)
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
