import SwiftUI
import UIKit

/// Today's hero: the meal donut on the left and the number column on the right — kcal left
/// (or over), its caption, the dynamic-target cue, what was eaten, and the legend.
///
/// Renders `TodayHeroSummary` and decides nothing. The whole hero is one accessibility
/// element carrying the ring's label, value and hint (`CalorieRingSummary`), and it is a
/// native `Button` that opens Nutrition Details — the same contract the ring had.
struct CalorieHeroView: View {
    let summary: TodayHeroSummary
    var onDetailsRequested: (() -> Void)? = nil

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    @ScaledMetric(relativeTo: .largeTitle) private var numberSize: CGFloat = 56
    @ScaledMetric(relativeTo: .footnote) private var legendKeySize: CGFloat = 10

    private static let donutSize: CGFloat = 168

    /// Side by side as the board draws it; stacked from xxxLarge, where a 168pt donut leaves
    /// the number column (176pt on a 402pt phone) narrower than a legend row
    /// ("Breakfast … not yet" needs about 189pt there). Between Large and xxLarge on a
    /// narrower phone the legend's names and values shrink a little instead (see
    /// `legendRow`).
    private var layout: AnyLayout {
        dynamicTypeSize >= .xxxLarge
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 18))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 18))
    }

    var body: some View {
        Group {
            if onDetailsRequested != nil {
                Button(action: requestDetails) {
                    heroVisual
                }
                .buttonStyle(CalorieRingButtonStyle())
            } else {
                heroVisual
            }
        }
    }

    private var heroVisual: some View {
        layout {
            CalorieDonutView(summary: summary.donut, size: Self.donutSize)

            numberColumn
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape([.interaction, .accessibility], .rect)
        .animation(accessibilityReduceMotion ? nil : .smooth(duration: 0.35), value: summary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary.ring.accessibilityLabel)
        .accessibilityValue(summary.ring.accessibilityValue)
        .accessibilityHint(CalorieRingSummary.accessibilityHint(isInteractive: onDetailsRequested != nil))
    }

    private var numberColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(summary.headlineText)
                .font(CalorynTheme.heroNumber(size: numberSize))
                .tracking(-numberSize * 0.035)
                .foregroundStyle(CalorynTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(numberTransition)

            Text(summary.caption)
                .font(TodayPlateFont.heroCaption)
                .fontWeight(summary.isOver ? .semibold : .medium)
                .foregroundStyle(summary.isOver ? CalorynTheme.textPrimary : CalorynTheme.textSecondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            dynamicTargetCue

            Text(summary.eatenLine)
                .font(CalorynTheme.legendText)
                .foregroundStyle(CalorynTheme.textSecondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            legend
                .padding(.top, 10)
        }
    }

    // MARK: - Legend

    private var legend: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(summary.donut.legend) { entry in
                legendRow(entry)
            }
        }
    }

    private func legendRow(_ entry: CalorieDonutSummary.LegendEntry) -> some View {
        let isOverRow = entry.meal == nil

        return HStack(spacing: 8) {
            legendKey(entry)

            Text(summary.legendName(for: entry))
                .fontWeight(isOverRow ? .bold : .medium)
                .foregroundStyle(isOverRow ? CalorynTheme.textPrimary : CalorynTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 4)

            Text(summary.legendValue(for: entry))
                .fontWeight(isOverRow ? .bold : .medium)
                .foregroundStyle(entry.isLogged ? CalorynTheme.textPrimary : CalorynTheme.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .contentTransition(numberTransition)
        }
        .font(CalorynTheme.legendText)
    }

    /// A filled circle in the meal's fill (ink for the overshoot); a hollow ring for a meal
    /// nothing is logged in yet. The only keys on the screen — headers carry no glyphs.
    @ViewBuilder
    private func legendKey(_ entry: CalorieDonutSummary.LegendEntry) -> some View {
        let color = entry.meal.map(CalorynTheme.mealFill) ?? CalorynTheme.textPrimary

        if entry.isLogged {
            Circle()
                .fill(color)
                .frame(width: legendKeySize, height: legendKeySize)
        } else {
            Circle()
                .strokeBorder(color, lineWidth: 1.5)
                .frame(width: legendKeySize, height: legendKeySize)
        }
    }

    // MARK: - Dynamic target cue

    /// The auto-adjust status, under the caption exactly as it sat under the ring's number.
    @ViewBuilder
    private var dynamicTargetCue: some View {
        switch summary.ring.cue {
        case .none:
            EmptyView()
        case .updating:
            HStack(spacing: 5) {
                ProgressView()
                    .controlSize(.mini)

                Text(summary.ring.cue.text ?? "")
                    .lineLimit(1)
            }
            .font(CalorynTheme.microCaption)
            .foregroundStyle(CalorynTheme.textSecondary)
            .padding(.top, 2)
        case .increase:
            cueLabel(iconName: "flame.fill", color: CalorynTheme.textPrimary)
        case .reduction:
            cueLabel(iconName: "arrow.down.circle.fill", color: CalorynTheme.textSecondary)
        }
    }

    private func cueLabel(iconName: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(CalorynTheme.compactIcon)

            Text(summary.ring.cue.text ?? "")
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .font(CalorynTheme.numericMicroCaptionEmphasized)
        .foregroundStyle(color)
        .padding(.top, 2)
        .accessibilityLabel(summary.ring.cue.accessibilityLabel ?? "")
    }

    // MARK: - Reduce Motion

    /// Digits roll when the number changes, unless Reduce Motion is on: then they swap.
    private var numberTransition: ContentTransition {
        accessibilityReduceMotion ? .identity : .numericText()
    }

    // MARK: - Opening details

    private func requestDetails() {
        guard let onDetailsRequested else { return }
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred(intensity: 0.75)
        onDetailsRequested()
    }
}

/// The pressed state of the hero's native `Button`: a slight shrink, and none at all under
/// Reduce Motion.
private struct CalorieRingButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(accessibilityReduceMotion ? 1 : (configuration.isPressed ? 0.97 : 1))
            .animation(
                accessibilityReduceMotion ? nil : .smooth(duration: 0.2),
                value: configuration.isPressed
            )
    }
}

#Preview("Hero - under and over") {
    VStack(spacing: 32) {
        CalorieHeroView(
            summary: TodayHeroSummary(
                mealTotals: [.breakfast: 382, .lunch: 463, .snack: 118],
                budget: previewBudget(consumed: 963)
            ),
            onDetailsRequested: {}
        )
        CalorieHeroView(
            summary: TodayHeroSummary(
                mealTotals: [.breakfast: 382, .lunch: 463, .dinner: 1_377, .snack: 118],
                budget: previewBudget(consumed: 2_340)
            ),
            onDetailsRequested: {}
        )
    }
    .padding(20)
    .background(CalorynTheme.pageBackground)
}

#Preview("Hero - dynamic increase") {
    CalorieHeroView(
        summary: TodayHeroSummary(
            mealTotals: [.breakfast: 600, .lunch: 700],
            budget: previewBudget(consumed: 1_300, mode: .dynamicHealth, activeEnergy: 500)
        ),
        onDetailsRequested: {}
    )
    .padding(20)
    .background(CalorynTheme.pageBackground)
}

private func previewBudget(
    consumed: Double,
    mode: EnergyCalculationMode = .lifestyleEstimate,
    activeEnergy: Double = 0
) -> ActivityCalorieBudget {
    ActivityCalorieBudget(
        consumed: consumed,
        staticTarget: 2_000,
        bmr: 1_700,
        calorieDeficit: 300,
        activeEnergyKcal: activeEnergy,
        recentActiveEnergySamples: (1...10).compactMap { offset in
            Calendar.current.date(byAdding: .day, value: -offset, to: Date.now.startOfDay)
                .map { DailyActiveEnergySample(date: $0, activeEnergyKcal: 300) }
        },
        calculationMode: mode,
        isManualOverride: false,
        isActivityLoading: false,
        activityMessage: nil,
        date: .now
    )
}
