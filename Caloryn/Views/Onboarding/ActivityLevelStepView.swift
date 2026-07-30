import SwiftUI

struct ActivityLevelStepView: View {
    @Binding var activityLevel: ActivityLevel
    var onContinue: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Activity Level")
                        .font(CalorynTheme.sectionTitle)
                        .foregroundStyle(CalorynTheme.textPrimary)
                    Text("How active are you on a typical week?")
                        .font(CalorynTheme.bodyText)
                        .foregroundStyle(CalorynTheme.textSecondary)
                }
                .padding(.top, 8)

                AdaptiveGlassContainer(spacing: CalorynTheme.cardSpacing) {
                    VStack(spacing: CalorynTheme.cardSpacing) {
                        ForEach(ActivityLevel.allCases) { level in
                            ActivityLevelCard(
                                level: level,
                                isSelected: activityLevel == level
                            ) {
                                withAnimation(.smooth(duration: 0.25)) {
                                    activityLevel = level
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
            Button(action: onContinue) {
                Text("Continue")
                    .font(CalorynTheme.buttonLabel)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .adaptiveGlassProminentButton()
            .padding(.horizontal, CalorynTheme.pagePadding)
            .padding(.bottom, 16)
            .accessibilityIdentifier("onboarding.activityLevel.continue")
        }
        .calorynPageCanvas()
        .calorynDrillDownNavigation()
    }
}

private struct ActivityLevelCard: View {
    let level: ActivityLevel
    let isSelected: Bool
    var onTap: () -> Void

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

    private var secondaryForeground: Color {
        usesLiquidGlassSelectedStyle ? CalorynTheme.warmWhite.opacity(0.9) : CalorynTheme.textSecondary
    }

    private var accentForeground: Color {
        usesLiquidGlassSelectedStyle ? CalorynTheme.warmWhite : CalorynTheme.sage
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: level.iconName)
                    .font(CalorynTheme.inlineIcon)
                    .foregroundStyle(accentForeground)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text(level.displayName)
                        .font(CalorynTheme.itemTitle)
                        .foregroundStyle(contentForeground)
                    Text(level.description)
                        .font(CalorynTheme.caption)
                        .foregroundStyle(secondaryForeground)
                }

                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(accentForeground)
                    .font(CalorynTheme.inlineIcon)
                    .opacity(isSelected ? 1 : 0)
            }
            .padding(CalorynTheme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .adaptiveSelectableGlass(
                isSelected: isSelected,
                cornerRadius: CalorynTheme.smallCornerRadius
            )
            .animation(.smooth(duration: 0.25), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        ActivityLevelStepView(activityLevel: .constant(.moderatelyActive)) { }
    }
}
