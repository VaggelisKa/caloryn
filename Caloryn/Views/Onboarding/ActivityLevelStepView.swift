import SwiftUI

struct ActivityLevelStepView: View {
    @Binding var activityLevel: ActivityLevel
    var onContinue: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                OnboardingStepHeader(
                    title: "Activity level",
                    subtitle: "How active are you in a typical week?"
                )

                VStack(spacing: 0) {
                    ForEach(ActivityLevel.allCases) { level in
                        OnboardingHairline()
                        OnboardingChoiceRow(
                            title: level.displayName.sentenceCased,
                            detail: level.description,
                            isSelected: activityLevel == level,
                            accessibilityIdentifier: "onboarding.activityLevel.option.\(level.rawValue)"
                        ) {
                            withAnimation(.smooth(duration: 0.25)) {
                                activityLevel = level
                            }
                        }
                    }
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
                .accessibilityIdentifier("onboarding.activityLevel.continue")
            }
        }
        .calorynPageCanvas()
        .calorynDrillDownNavigation()
    }
}

#Preview {
    NavigationStack {
        ActivityLevelStepView(activityLevel: .constant(.moderatelyActive)) { }
    }
}
