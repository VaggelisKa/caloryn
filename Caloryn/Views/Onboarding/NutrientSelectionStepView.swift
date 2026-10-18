import SwiftUI

struct NutrientSelectionStepView: View {
    @Binding var selectedNutrientIDs: String
    var isCompleting = false
    var onComplete: () -> Void

    private var selection: OnboardingNutrientSelection {
        OnboardingNutrientSelection(rawValue: selectedNutrientIDs)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                OnboardingStepHeader(
                    title: "Nutrients to track",
                    subtitle: "Choose what you want to track."
                )

                coreMacroSection

                VStack(alignment: .leading, spacing: 12) {
                    OnboardingSectionTitle("Additional nutrients")

                    WrappingChipFlow {
                        ForEach(TrackedNutrient.editableGoalNutrients) { nutrient in
                            let isSelected = selection.isSelected(nutrient)
                            Button {
                                withAnimation(.smooth(duration: 0.2)) {
                                    selectedNutrientIDs = selection.toggling(nutrient)
                                }
                            } label: {
                                Text(nutrient.displayName.sentenceCased)
                                    .calorynChip(isSelected: isSelected)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(nutrient.displayName.sentenceCased)
                            .accessibilityAddTraits(isSelected ? .isSelected : [])
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
                Button(action: onComplete) {
                    HStack(spacing: 8) {
                        if isCompleting {
                            ProgressView()
                                .tint(CalorynTheme.textSecondary)
                        }

                        Text("Start tracking")
                    }
                }
                .calorynPrimaryButton()
                .disabled(isCompleting)
                .accessibilityIdentifier("onboarding.startTracking")
            }
        }
        .calorynPageCanvas()
        .calorynDrillDownNavigation()
        .onAppear(perform: ensureDefaultMacrosSelected)
    }

    private var coreMacroSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            OnboardingSectionTitle("Core macros")

            WrappingChipFlow {
                ForEach(TrackedNutrient.defaultSelection) { nutrient in
                    Text(nutrient.displayName.sentenceCased)
                        .calorynChip(isSelected: true)
                        .accessibilityLabel(nutrient.displayName.sentenceCased)
                }
            }

            Text("Always tracked.")
                .font(OnboardingTypography.detail)
                .foregroundStyle(CalorynTheme.textSecondary)
        }
    }

    private func ensureDefaultMacrosSelected() {
        selectedNutrientIDs = selection.normalizedRawValue
    }
}

#Preview {
    NavigationStack {
        NutrientSelectionStepView(
            selectedNutrientIDs: .constant(TrackedNutrient.defaultSelectionRaw)
        ) { }
    }
}
