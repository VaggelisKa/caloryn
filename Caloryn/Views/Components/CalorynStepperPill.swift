import SwiftUI

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

    private var pillHeight: CGFloat {
        size == .regular ? min(regularHeight, 80) : min(compactHeight, 56)
    }

    private var buttonDiameter: CGFloat {
        size == .regular ? min(regularButton, 60) : min(compactButton, 44)
    }

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
        .background(CalorynTheme.backgroundTertiary, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(CalorynTheme.separator, lineWidth: CalorynTheme.hairlineWidth)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityTitle)
        .accessibilityValue([value, unit].compactMap { $0 }.joined(separator: " "))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                if canIncrement { step(onIncrement) }
            case .decrement:
                if canDecrement { step(onDecrement) }
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
                    .tracking(-min(regularNumber, 52) * 0.01)
                    .foregroundStyle(CalorynTheme.textPrimary)
                    .contentTransition(.numericText())

                if let unit {
                    Text(unit)
                        .font(CalorynTypeface.fixed(size: min(regularUnit, 28), weight: .semibold))
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

    private func stepButton(systemImage: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            step(action)
        } label: {
            Image(systemName: systemImage)
                .font(size == .regular ? CalorynTheme.inlineIcon : CalorynTheme.compactIcon)
                .foregroundStyle(isEnabled ? CalorynTheme.accent : CalorynTheme.textTertiary)
                .frame(width: buttonDiameter, height: buttonDiameter)
                .background(CalorynTheme.backgroundSecondary, in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(CalorynTheme.separator, lineWidth: CalorynTheme.hairlineWidth)
                }
                .shadow(color: CalorynTheme.shadow, radius: size == .regular ? 4 : 2, y: size == .regular ? 2 : 1)
                .frame(
                    width: buttonDiameter + hitTargetOverhang * 2,
                    height: buttonDiameter + hitTargetOverhang * 2
                )
                .contentShape(Rectangle())
                .padding(-hitTargetOverhang)
        }
        .buttonStyle(.borderless)
        .disabled(!isEnabled)
    }

    private func step(_ action: () -> Void) {
        CalorynHaptics.selectionChanged()
        withAnimation(.smooth(duration: 0.2)) { action() }
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
    .background(CalorynTheme.backgroundSecondary)
}
