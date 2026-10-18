import SwiftUI

// The Plate / Market vocabulary for the onboarding steps (`docs/design/plate-market.md`,
// boards `PlateWelcome` and `PlateGoal`): content directly on the page, a heavy
// sentence-case title, hairline rows, chips for small choices and the ink primary button
// at the foot. Every colour comes from `CalorynTheme`.

/// Type sizes the boards use that `CalorynTheme` has no name for. Text-style-relative, so
/// Dynamic Type still scales them.
enum OnboardingTypography {
    /// A row's label and value on the goal step, 15pt.
    static let rowText: Font = .system(.subheadline)
    static let rowValue: Font = .system(.subheadline).monospacedDigit()
    /// Supporting copy under a figure or a choice, 13pt.
    static let detail: Font = .system(.footnote)
    /// "Gain / Keep / Lose" under the slider, 12pt.
    static let scaleLabel: Font = .system(.caption)
    /// A text link ("Set a number yourself instead"), 15pt semibold.
    static let link: Font = .system(.subheadline, weight: .semibold)
    /// A choice row's title, 16pt medium.
    static let choiceTitle: Font = .system(.callout, weight: .medium)
}

/// The step's title and the line under it, left-aligned as the boards draw them.
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

/// A bold section title over a group of rows ("How fast", "Where the number comes from").
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

/// The 1pt rule drawn between rows on the page. A scroll view has no list separators, so
/// it draws its own (see "Pages" in the spec).
struct OnboardingHairline: View {
    var body: some View {
        Rectangle()
            .fill(CalorynTheme.hairline)
            .frame(height: CalorynTheme.hairlineWidth)
            .accessibilityHidden(true)
    }
}

/// A slider that moves in steps without drawing them. `Slider(step:)` draws a tick per step
/// on iOS 26 — a dotted rule under the height and weight tracks — and `PlateGoal` draws a
/// bare track, so the value is snapped through the binding (`SliderStep`) instead, and
/// VoiceOver still adjusts it one step at a time. Edit Profile's height and weight use it too.
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

/// The foot of every step: the ink primary button over a fade from the page, so content
/// scrolling under it does not end in a hard edge.
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
                    .init(color: CalorynTheme.pageBackground.opacity(0), location: 0),
                    .init(color: CalorynTheme.pageBackground, location: 0.35),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        }
    }
}

/// One option of a single choice (activity level, calorie estimate): a title, a line of
/// detail and a round mark on the right. Rows sit on the page between hairlines, not in
/// cards.
struct OnboardingChoiceRow: View {
    let title: String
    let detail: String
    let isSelected: Bool
    var isDisabled = false
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
            // The label's own shape is the union of its glyphs, so without this the
            // row is only tappable on its text (and under the 44pt minimum).
            .contentShape([.interaction, .accessibility], Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
        // The detail is what tells the options apart, so it stays in the spoken
        // label; selection is a trait rather than words in that label.
        .accessibilityLabel("\(title), \(detail)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// The radio mark of a choice row: an ink disc with a paper tick when chosen, a quiet ring
/// when not. Drawn rather than an SF Symbol so the tick takes the page colour in both
/// appearances.
struct OnboardingSelectionMark: View {
    let isSelected: Bool

    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 24

    var body: some View {
        ZStack {
            if isSelected {
                Circle()
                    .fill(CalorynTheme.textPrimary)
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.45, weight: .bold))
                    .foregroundStyle(CalorynTheme.pageBackground)
            } else {
                Circle()
                    .strokeBorder(CalorynTheme.textTertiary, lineWidth: 1.5)
            }
        }
        .frame(width: size, height: size)
        .animation(.smooth(duration: 0.2), value: isSelected)
        .accessibilityHidden(true)
    }
}

/// A row's label beside its control, or above it at accessibility text sizes, where the two
/// no longer fit on one line and the control would truncate (the same switch
/// `CustomFoodFormView` makes for its barcode row).
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

/// Chips that wrap onto as many lines as they need, left-aligned, so a choice never
/// truncates its options: the nutrients step always, the sex choice and the custom food
/// form's "Count as" when the text is large. A chip wider than the whole line is offered the
/// line's width rather than overflowing it.
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
