import SwiftUI

// The Plate / Market vocabulary (`docs/design/plate-market.md`): hairline lists on the page,
// the few grouped surfaces, the ink primary button and chips. Every colour comes from
// `CalorynTheme`.

// MARK: - Hairline lists

private struct CalorynHairlineSeparatorsModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listRowSeparatorTint(CalorynTheme.hairline)
            .listRowBackground(Color.clear)
    }
}

// MARK: - Grouped surface

private struct CalorynGroupSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: CalorynTheme.groupCornerRadius, style: .continuous)

        content
            .background(CalorynTheme.backgroundSecondary, in: shape)
            .overlay {
                shape
                    .strokeBorder(CalorynTheme.hairline, lineWidth: CalorynTheme.hairlineWidth)
                    .allowsHitTesting(false)
            }
    }
}

// MARK: - Primary button

/// Rebuilds the button around a label sized to the 54pt capsule, then hands it to the
/// system's prominent style, so iOS 26 keeps Liquid Glass and iOS 18 gets a bordered
/// prominent capsule. A `PrimitiveButtonStyle` is the only place that can size the *label*
/// from a modifier applied to the `Button`: a frame on the button itself does not grow the
/// bezel.
private struct CalorynPrimaryButtonStyle: PrimitiveButtonStyle {
    let meal: MealType?

    func makeBody(configuration: Configuration) -> some View {
        CalorynPrimaryButton(configuration: configuration, meal: meal)
    }
}

/// A view rather than the style's body, so it can read `isEnabled`: the system greys a
/// disabled bezel, and a paper label on that grey disappears in both appearances.
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
    /// The capsule is 54pt tall. Both prominent styles pad the label by 7pt top and bottom at
    /// the regular control size, so the label itself is 40pt.
    static let height: CGFloat = 54
    static let labelHeight: CGFloat = 40
}

// MARK: - Chips

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
    /// Row chrome for a plain list on the page: separators tinted `hairline`, and no row
    /// background so the canvas shows through.
    ///
    /// Apply it where `.listRowBackground` would go — on each `Section`, `ForEach` or row —
    /// not on the `List`: row traits written on the list itself reach no row. Pair with
    /// `calorynPlainListStyle()` on the list.
    func calorynHairlineSeparators() -> some View {
        modifier(CalorynHairlineSeparatorsModifier())
    }

    /// Only the clear row background, for rows that draw their own separators or hide them.
    func calorynClearRowBackground() -> some View {
        listRowBackground(Color.clear)
    }

    /// One of the few grouped surfaces built as a stack (the History insight): `backgroundSecondary`,
    /// a 22pt continuous corner, a 1pt `hairline` border, no shadow. Surface only — add the
    /// padding the content needs inside it.
    ///
    /// Not for `List`/`Form` sections. Those keep the system inset-grouped shape (its own
    /// corner radius, no border) via `calorynGroupedListStyle()` / `calorynFormStyle()` plus
    /// `.listRowBackground(CalorynTheme.backgroundSecondary)` on each `Section`: a row cannot draw
    /// a border round its whole section. See `docs/design/plate-market.md`, "Grouped surfaces".
    func calorynGroupSurface() -> some View {
        modifier(CalorynGroupSurfaceModifier())
    }

    /// The primary button: a full-width 54pt capsule in ink with a paper label, 17pt bold.
    /// Liquid Glass (`.glassProminent`) on iOS 26, `.borderedProminent` before it, tinted
    /// either way. Apply to a `Button`; its label needs no font, frame or padding.
    ///
    /// Ink everywhere but the Portion sheet's "Log to <meal>", which passes the target `meal`:
    /// the capsule takes the meal's fill and the label its `mealOnFill` colour, since a paper
    /// label on the yellow breakfast fill is 1.7:1.
    func calorynPrimaryButton(meal: MealType? = nil) -> some View {
        buttonStyle(CalorynPrimaryButtonStyle(meal: meal))
    }

    /// A 34pt capsule chip. Selected is filled in ink with a paper label; unselected is a
    /// 1pt `hairline` border with an ink label. Pass `meal` for the Portion sheet's meal
    /// chips: selected fills with the meal's fill and labels in `mealOnFill`, unselected
    /// writes the label in the meal's ink.
    ///
    /// Apply to the label, inside a `Button` with `.buttonStyle(.plain)`. A selected chip
    /// carries the `.isSelected` trait; repeat it on the `Button` — the element VoiceOver
    /// lands on — as `.accessibilityAddTraits(isSelected ? .isSelected : [])`.
    func calorynChip(isSelected: Bool, meal: MealType? = nil) -> some View {
        modifier(CalorynChipModifier(isSelected: isSelected, meal: meal))
    }
}

/// The system switch, tinted `accentControl` rather than the app's ink.
///
/// A `Toggle` takes the app-wide `.tint(textPrimary)`, and in dark mode that put the
/// switch's white knob on a near-white track (about 1.1:1): on and off could only be told
/// apart by where the knob was, and the knob could not be seen. The knob's colour is not
/// ours to set, so the track is what changes. Applied app-wide in `ContentView`; it keeps
/// the system switch, its glass knob on iOS 26 and its haptics.
struct CalorynToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Toggle(configuration)
            .toggleStyle(.switch)
            .tint(CalorynTheme.accentControl)
    }
}
