import SwiftUI

struct NutrientSelectionStepView: View {
    @Binding var selectedNutrientIDs: String
    var isCompleting = false
    var onComplete: () -> Void

    private var selectedNutrients: [TrackedNutrient] {
        TrackedNutrient.selected(from: selectedNutrientIDs)
    }

    private var selectedExtras: [TrackedNutrient] {
        selectedNutrients.filter { !TrackedNutrient.defaultSelection.contains($0) }
    }

    private var optionalNutrientColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Nutrients to Track")
                        .font(CalorynTheme.sectionTitle)
                        .foregroundStyle(CalorynTheme.textPrimary)

                    Text("Choose what you want to track.")
                        .font(CalorynTheme.bodyText)
                        .foregroundStyle(CalorynTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)

                coreMacroSection

                VStack(alignment: .leading, spacing: 12) {
                    Text("ADDITIONAL NUTRIENTS")
                        .font(CalorynTheme.sectionEyebrow)
                        .foregroundStyle(CalorynTheme.textSecondary)

                    AdaptiveGlassContainer(spacing: 10) {
                        LazyVGrid(columns: optionalNutrientColumns, spacing: 10) {
                            ForEach(TrackedNutrient.editableGoalNutrients) { nutrient in
                                NutrientSelectionTile(
                                    nutrient: nutrient,
                                    isSelected: selectedNutrients.contains(nutrient)
                                ) {
                                    toggle(nutrient)
                                }
                            }
                        }
                    }
                }

            }
            .padding(.horizontal, CalorynTheme.pagePadding)
            .padding(.bottom, 100)
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: onComplete) {
                HStack(spacing: 8) {
                    if isCompleting {
                        ProgressView()
                            .tint(.white)
                    }

                    Text("Start Tracking")
                        .font(CalorynTheme.buttonLabel)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .adaptiveGlassProminentButton()
            .tint(CalorynTheme.sage)
            .disabled(isCompleting)
            .padding(.horizontal, CalorynTheme.pagePadding)
            .padding(.bottom, 16)
            .accessibilityIdentifier("onboarding.startTracking")
        }
        .onAppear(perform: ensureDefaultMacrosSelected)
    }

    private var coreMacroSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CORE MACROS")
                .font(CalorynTheme.sectionEyebrow)
                .foregroundStyle(CalorynTheme.textSecondary)

            HStack(spacing: 10) {
                ForEach(TrackedNutrient.defaultSelection) { nutrient in
                    VStack(spacing: 8) {
                        Image(systemName: nutrient.systemImage)
                            .font(CalorynTheme.inlineIcon)
                            .foregroundStyle(nutrient.color)
                            .frame(width: 28, height: 28)

                        Text(nutrient.displayName)
                            .font(CalorynTheme.caption)
                            .foregroundStyle(CalorynTheme.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .adaptiveGlassCard(cornerRadius: CalorynTheme.smallCornerRadius)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(nutrient.displayName) selected")
                }
            }
        }
    }

    private func toggle(_ nutrient: TrackedNutrient) {
        var extras = selectedExtras
        if extras.contains(nutrient) {
            extras.removeAll { $0 == nutrient }
        } else {
            extras.append(nutrient)
        }

        selectedNutrientIDs = TrackedNutrient.rawSelection(from: TrackedNutrient.defaultSelection + extras)
    }

    private func ensureDefaultMacrosSelected() {
        selectedNutrientIDs = TrackedNutrient.rawSelection(from: TrackedNutrient.defaultSelection + selectedExtras)
    }
}

private struct NutrientSelectionTile: View {
    let nutrient: TrackedNutrient
    let isSelected: Bool
    var onToggle: () -> Void

    private var usesLiquidGlassSelectedStyle: Bool {
        if #available(iOS 26.0, *) {
            isSelected
        } else {
            false
        }
    }

    private var contentForeground: Color {
        usesLiquidGlassSelectedStyle ? CalorynTheme.warmWhite : CalorynTheme.textPrimary
    }

    private var iconForeground: Color {
        if usesLiquidGlassSelectedStyle {
            return CalorynTheme.warmWhite
        }

        return isSelected ? CalorynTheme.sage : nutrient.color
    }

    private var selectionIndicatorForeground: Color {
        if usesLiquidGlassSelectedStyle {
            return CalorynTheme.warmWhite
        }

        return isSelected ? CalorynTheme.sage : CalorynTheme.textSecondary
    }

    var body: some View {
        Button(action: onToggle) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 8) {
                    Image(systemName: nutrient.systemImage)
                        .font(CalorynTheme.inlineIcon)
                        .foregroundStyle(iconForeground)
                        .frame(width: 28, height: 28)

                    Text(nutrient.displayName)
                        .font(CalorynTheme.caption)
                        .foregroundStyle(contentForeground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .frame(maxWidth: .infinity)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(CalorynTheme.inlineIcon)
                    .foregroundStyle(selectionIndicatorForeground)
                    .padding(10)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 74)
            .contentShape(
                RoundedRectangle(cornerRadius: CalorynTheme.smallCornerRadius, style: .continuous)
            )
            .adaptiveSelectableGlass(
                isSelected: isSelected,
                cornerRadius: CalorynTheme.smallCornerRadius
            )
            .animation(.smooth(duration: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(nutrient.displayName), \(isSelected ? "selected" : "not selected")")
    }
}

    #Preview {
        NavigationStack {
            NutrientSelectionStepView(
                selectedNutrientIDs: .constant(TrackedNutrient.defaultSelectionRaw)
            ) { }
        }
    }
