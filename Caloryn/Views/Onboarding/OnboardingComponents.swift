import SwiftUI

enum OnboardingTypography {
    static let rowText: Font = CalorynTypeface.text(.subheadline)
    static let rowValue: Font = CalorynTypeface.text(.subheadline).monospacedDigit()
    static let detail: Font = CalorynTypeface.text(.footnote)
    static let scaleLabel: Font = CalorynTypeface.text(.caption)
    static let link: Font = CalorynTypeface.text(.subheadline, weight: .semibold)
    static let choiceTitle: Font = CalorynTypeface.text(.callout, weight: .medium)
}

struct OnboardingStepHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(CalorynTheme.screenTitle)
                .tracking(-0.3)
                .foregroundStyle(CalorynTheme.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Text(subtitle)
                .font(CalorynTheme.cardSubtitle)
                .foregroundStyle(CalorynTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct OnboardingSectionTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(CalorynTheme.sectionHeaderTitle)
            .foregroundStyle(CalorynTheme.textPrimary)
            .accessibilityAddTraits(.isHeader)
    }
}

struct OnboardingHairline: View {
    var body: some View {
        Rectangle()
            .fill(CalorynTheme.separator)
            .frame(height: CalorynTheme.hairlineWidth)
            .accessibilityHidden(true)
    }
}

struct OnboardingSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let label: String

    private var snappedValue: Binding<Double> {
        Binding(
            get: { value },
            set: { value = SliderStep.snap($0, in: range, step: step) }
        )
    }

    var body: some View {
        Slider(value: snappedValue, in: range) {
            Text(label)
        }
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                value = SliderStep.snap(value + step, in: range, step: step)
            case .decrement:
                value = SliderStep.snap(value - step, in: range, step: step)
            @unknown default:
                break
            }
        }
    }
}

struct OnboardingActionBar<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 14) {
            content
        }
        .padding(.horizontal, CalorynTheme.pagePadding)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background {
            LinearGradient(
                stops: [
                    .init(color: CalorynTheme.backgroundPrimary.opacity(0), location: 0),
                    .init(color: CalorynTheme.backgroundPrimary, location: 0.35),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        }
    }
}

struct OnboardingChoiceRow: View {
    let title: String
    let detail: String
    let isSelected: Bool
    var accessibilityIdentifier: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(OnboardingTypography.choiceTitle)
                        .foregroundStyle(CalorynTheme.textPrimary)

                    Text(detail)
                        .font(OnboardingTypography.detail)
                        .foregroundStyle(CalorynTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                OnboardingSelectionMark(isSelected: isSelected)
            }
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape([.interaction, .accessibility], Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
        .accessibilityLabel("\(title), \(detail)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

struct OnboardingSelectionMark: View {
    let isSelected: Bool

    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 24

    var body: some View {
        ZStack {
            if isSelected {
                Circle()
                    .fill(CalorynTheme.accent)
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.45, weight: .bold))
                    .foregroundStyle(CalorynTheme.textOnAccent)
            } else {
                Circle()
                    // swiftlint:disable:next text_token_as_shape
                    .strokeBorder(CalorynTheme.textTertiary, lineWidth: 1.5)
            }
        }
        .frame(width: size, height: size)
        .animation(.smooth(duration: 0.2), value: isSelected)
        .accessibilityHidden(true)
    }
}

struct OnboardingAdaptiveRow<Label: View, Trailing: View>: View {
    var alignment: VerticalAlignment = .center
    var spacing: CGFloat = 12
    @ViewBuilder let label: Label
    @ViewBuilder let trailing: Trailing

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                label
                HStack(alignment: alignment, spacing: spacing) {
                    trailing
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: alignment, spacing: spacing) {
                label
                Spacer(minLength: 8)
                trailing
            }
        }
    }
}

struct WrappingChipFlow: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews: subviews, width: proposal.width ?? .infinity)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(subviews: subviews, width: bounds.width)
        for row in rows {
            var x = bounds.minX
            for (index, size) in zip(row.indices, row.sizes) {
                subviews[index].place(
                    at: CGPoint(x: x, y: bounds.minY + row.y),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
        }
    }

    private struct Row {
        var indices: [Int] = []
        var sizes: [CGSize] = []
        var y: CGFloat = 0
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(subviews: Subviews, width: CGFloat) -> [Row] {
        let proposal = width.isFinite ? ProposedViewSize(width: width, height: nil) : .unspecified
        var rows: [Row] = []
        var current = Row()

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(proposal)
            let proposedWidth = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if proposedWidth > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row(y: current.y + current.height + lineSpacing)
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
            current.sizes.append(size)
        }
        if !current.indices.isEmpty {
            rows.append(current)
        }
        return rows
    }
}
