import SwiftUI

struct NutrientSelectionStepView: View {
    @Binding var selectedNutrientIDs: String
    var isCompleting = false
    var onComplete: () -> Void

    /// The selection rules live here; the view reads them and renders. See
    /// `OnboardingNutrientSelection`.
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
                            .accessibilityValue(isSelected ? "selected" : "not selected")
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
                            // Only ever shown while the button is disabled, so it matches
                            // the disabled label rather than the paper one.
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

    /// Always on, so they are shown chosen but are not buttons.
    private var coreMacroSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            OnboardingSectionTitle("Core macros")

            WrappingChipFlow {
                ForEach(TrackedNutrient.defaultSelection) { nutrient in
                    Text(nutrient.displayName.sentenceCased)
                        .calorynChip(isSelected: true)
                        .accessibilityLabel("\(nutrient.displayName.sentenceCased) selected")
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
