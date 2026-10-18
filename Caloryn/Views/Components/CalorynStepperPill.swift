import SwiftUI

/// The Plate stepper for a count: a `surface` capsule with round minus and plus buttons at
/// its ends and the value between them — the Portion sheet's grams pill (`GramAmountField`)
/// without the typed field.
///
/// It stands in for the stock `Stepper` and for a wheel `Picker`, whose own fills (the
/// stepper's minus/plus pill, the wheel's selection band) are a cool system grey that no
/// token reaches and the colour census cannot see.
///
/// `.regular` is the Portion sheet's size: a big number with its unit beside it in
/// secondary text. `.compact` sits at the trailing end of a form row ("Age", "Snack slot").
///
/// To VoiceOver it is one adjustable element, as a stock stepper is: swipe up or down to
/// step. The identifier goes on that element.
struct CalorynStepperPill: View {
    enum Size {
        case regular
        case compact
    }

    let accessibilityTitle: String
    let value: String
    var unit: String? = nil
    var size: Size = .regular
    let canDecrement: Bool
    let canIncrement: Bool
    let onDecrement: () -> Void
    let onIncrement: () -> Void

    @ScaledMetric(relativeTo: .body) private var regularHeight: CGFloat = 68
    @ScaledMetric(relativeTo: .body) private var regularButton: CGFloat = 48
    @ScaledMetric(relativeTo: .largeTitle) private var regularNumber: CGFloat = 36
    @ScaledMetric(relativeTo: .title3) private var regularUnit: CGFloat = 20
    @ScaledMetric(relativeTo: .body) private var compactHeight: CGFloat = 38
    @ScaledMetric(relativeTo: .body) private var compactButton: CGFloat = 30

    // Capped the way `GramAmountField` caps its pill: both buttons and the value share one
    // line on a phone at every text size.
    private var pillHeight: CGFloat {
        size == .regular ? min(regularHeight, 80) : min(compactHeight, 56)
    }

    private var buttonDiameter: CGFloat {
        size == .regular ? min(regularButton, 60) : min(compactButton, 44)
    }

    /// Apple's minimum touch target. The compact pill's 30pt circles are smaller, so each
    /// button takes touches across 44pt while laying out, and drawing, at its own size.
    private static let minimumHitTarget: CGFloat = 44

    private var hitTargetOverhang: CGFloat {
        max(0, Self.minimumHitTarget - buttonDiameter) / 2
    }

    var body: some View {
        HStack(spacing: size == .regular ? 0 : 8) {
            stepButton(systemImage: "minus", isEnabled: canDecrement, action: onDecrement)
            valueLabel
            stepButton(systemImage: "plus", isEnabled: canIncrement, action: onIncrement)
        }
        .padding(.horizontal, size == .regular ? 10 : 4)
        .frame(minHeight: pillHeight)
        .background(CalorynTheme.surface, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(CalorynTheme.hairline, lineWidth: CalorynTheme.hairlineWidth)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityTitle)
        .accessibilityValue([value, unit].compactMap { $0 }.joined(separator: " "))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                if canIncrement { onIncrement() }
            case .decrement:
                if canDecrement { onDecrement() }
            @unknown default:
                break
            }
        }
    }

    @ViewBuilder
    private var valueLabel: some View {
        switch size {
        case .regular:
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value)
                    .font(CalorynTheme.heroNumber(size: min(regularNumber, 52)))
                    .tracking(-min(regularNumber, 52) * 0.03)
                    .foregroundStyle(CalorynTheme.textPrimary)
                    .contentTransition(.numericText())

                if let unit {
                    Text(unit)
                        .font(.system(size: min(regularUnit, 28), weight: .semibold))
                        .foregroundStyle(CalorynTheme.textSecondary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity)
        case .compact:
            Text([value, unit].compactMap { $0 }.joined(separator: " "))
                .font(CalorynTheme.numericBody)
                .foregroundStyle(CalorynTheme.textPrimary)
                .lineLimit(1)
                .contentTransition(.numericText())
                .frame(minWidth: buttonDiameter)
        }
    }

    /// The board's round white button on the pill, with the hairline ring that still
    /// separates it from the pill in dark mode, where card and surface are one colour.
    private func stepButton(systemImage: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.smooth(duration: 0.2)) { action() }
        } label: {
            Image(systemName: systemImage)
                .font(size == .regular ? CalorynTheme.inlineIcon : CalorynTheme.compactIcon)
                .foregroundStyle(isEnabled ? CalorynTheme.textPrimary : CalorynTheme.textTertiary)
                .frame(width: buttonDiameter, height: buttonDiameter)
                .background(CalorynTheme.cardBackground, in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(CalorynTheme.hairline, lineWidth: CalorynTheme.hairlineWidth)
                }
                .shadow(color: CalorynTheme.hairline, radius: size == .regular ? 4 : 2, y: size == .regular ? 2 : 1)
                .frame(
                    width: buttonDiameter + hitTargetOverhang * 2,
                    height: buttonDiameter + hitTargetOverhang * 2
                )
                .contentShape(Rectangle())
                // Hands the overhang back to the layout, so the pill keeps its size.
                .padding(-hitTargetOverhang)
        }
        // Borderless, not plain: inside a `Form` row a plain button makes the whole row
        // its tap target, and a tap anywhere on "Age" would step it.
        .buttonStyle(.borderless)
        .disabled(!isEnabled)
    }
}

#Preview {
    VStack(spacing: 20) {
        CalorynStepperPill(
            accessibilityTitle: "Count",
            value: "2",
            unit: "slices",
            canDecrement: true,
            canIncrement: true,
            onDecrement: {},
            onIncrement: {}
        )

        HStack {
            Text("Age")
            Spacer()
            CalorynStepperPill(
                accessibilityTitle: "Age",
                value: "34",
                size: .compact,
                canDecrement: true,
                canIncrement: true,
                onDecrement: {},
                onIncrement: {}
            )
        }
    }
    .padding()
    .background(CalorynTheme.cardBackground)
}
