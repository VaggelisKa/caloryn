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
                            Text("\(age) years")
                                .font(CalorynTheme.numericBody)
                                .foregroundStyle(CalorynTheme.textPrimary)
                            Spacer()
                            Stepper("", value: $age, in: 16...100)
                                .labelsHidden()
                        }
                    }

                    fieldCard("Height") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(Int(heightCm)) cm")
                                .font(CalorynTheme.numericBody)
                                .foregroundStyle(CalorynTheme.textPrimary)
                            Slider(value: $heightCm, in: 120...220, step: 1)
                                .tint(CalorynTheme.sage)
                        }
                    }

                    fieldCard("Weight") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(format: "%.1f kg", weightKg))
                                .font(CalorynTheme.numericBody)
                                .foregroundStyle(CalorynTheme.textPrimary)
                            Slider(value: $weightKg, in: 40...200, step: 0.5)
                                .tint(CalorynTheme.sage)
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
                    .font(.system(.headline, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .adaptiveGlassProminentButton()
            .tint(CalorynTheme.sage)
            .padding(.horizontal, CalorynTheme.pagePadding)
            .padding(.bottom, 16)
        }
        .toolbarVisibility(.hidden, for: .navigationBar)
    }

    private func fieldCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(CalorynTheme.caption)
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
