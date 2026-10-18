import SwiftUI

private struct CalorynHairlineSeparatorsModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listRowSeparatorTint(CalorynTheme.hairline)
            .listRowBackground(Color.clear)
    }
}

private struct CalorynGroupSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: CalorynTheme.groupCornerRadius, style: .continuous)

        content
            .background(CalorynTheme.cardBackground, in: shape)
            .overlay {
                shape
                    .strokeBorder(CalorynTheme.hairline, lineWidth: CalorynTheme.hairlineWidth)
                    .allowsHitTesting(false)
            }
    }
}

private struct CalorynPrimaryButtonStyle: PrimitiveButtonStyle {
    let meal: MealType?

    func makeBody(configuration: Configuration) -> some View {
        CalorynPrimaryButton(configuration: configuration, meal: meal)
    }
}

private struct CalorynPrimaryButton: View {
    let configuration: PrimitiveButtonStyleConfiguration
    let meal: MealType?

    @Environment(\.isEnabled) private var isEnabled

    private var fill: Color {
        meal.map(CalorynTheme.mealFill) ?? CalorynTheme.textPrimary
    }

    private var label: Color {
        guard isEnabled else { return CalorynTheme.textSecondary }
        return meal.map(CalorynTheme.mealOnFill) ?? CalorynTheme.pageBackground
    }

    var body: some View {
        Button(role: configuration.role, action: configuration.trigger) {
            configuration.label
                .font(CalorynTheme.primaryButtonLabel)
                .foregroundStyle(label)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: CalorynPrimaryButtonMetrics.labelHeight)
        }
        .systemProminentButtonStyle()
        .buttonBorderShape(.capsule)
        .tint(fill)
    }
}

enum CalorynPrimaryButtonMetrics {
    static let height: CGFloat = 54
    static let labelHeight: CGFloat = 40
}

private struct CalorynChipModifier: ViewModifier {
    let isSelected: Bool
    let meal: MealType?

    @ScaledMetric(relativeTo: .footnote) private var height: CGFloat = 34

    private var foreground: Color {
        switch (isSelected, meal) {
        case (true, let meal?): CalorynTheme.mealOnFill(meal)
        case (true, nil): CalorynTheme.pageBackground
        case (false, let meal?): CalorynTheme.mealInk(meal)
        case (false, nil): CalorynTheme.textPrimary
        }
    }

    private var selectedFill: Color {
        if let meal { return CalorynTheme.mealFill(meal) }
        return CalorynTheme.textPrimary
    }

    func body(content: Content) -> some View {
        content
            .font(CalorynTheme.chipLabel)
            .fontWeight(isSelected ? .bold : .medium)
            .lineLimit(1)
            .foregroundStyle(foreground)
            .padding(.horizontal, 14)
            .frame(minHeight: height)
            .background {
                if isSelected {
                    Capsule().fill(selectedFill)
                }
            }
            .overlay {
                if !isSelected {
                    Capsule()
                        .strokeBorder(CalorynTheme.hairline, lineWidth: CalorynTheme.hairlineWidth)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Capsule())
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

extension View {
    func calorynHairlineSeparators() -> some View {
        modifier(CalorynHairlineSeparatorsModifier())
    }

    func calorynClearRowBackground() -> some View {
        listRowBackground(Color.clear)
    }

    func calorynGroupSurface() -> some View {
        modifier(CalorynGroupSurfaceModifier())
    }

    func calorynPrimaryButton(meal: MealType? = nil) -> some View {
        buttonStyle(CalorynPrimaryButtonStyle(meal: meal))
    }

    func calorynChip(isSelected: Bool, meal: MealType? = nil) -> some View {
        modifier(CalorynChipModifier(isSelected: isSelected, meal: meal))
    }
}

struct CalorynToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Toggle(configuration)
            .toggleStyle(.switch)
            .tint(CalorynTheme.controlTint)
    }
}
