import SwiftUI

struct CalorieHeroView: View {
    let summary: TodayHeroSummary
    var columns: TodayDashboardLayout.HeroColumns = .two
    var onDetailsRequested: (() -> Void)? = nil

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @ScaledMetric(relativeTo: .largeTitle) private var numberSize: CGFloat = 56
    @ScaledMetric(relativeTo: .footnote) private var legendKeySize: CGFloat = 12

    @State private var isRevealed = false

    private static let donutSize: CGFloat = 168
    private static let columnSpacing: CGFloat = 18
    private static let threeColumnFiguresWidth: CGFloat = 200
    private static let threeColumnLegendWidth: CGFloat = 220

    /// The number column's width at regular width when the legend stays under the number —
    /// the dashboard column of a split Today, or a regular-width page too narrow for three
    /// columns. Left to fill, the legend put each value 400pt from its name; a first cap of
    /// 320pt still left 190pt of air and read as sparse. 220pt is the column on the widest
    /// phone (a 440pt Pro Max gives it 214pt). Compact widths keep filling: the column is
    /// 176pt on a 402pt phone and a cap would only cost accessibility sizes room.
    private static let regularWidthNumberColumnWidth: CGFloat = 220

    private var numberColumnMaxWidth: CGFloat {
        horizontalSizeClass == .regular ? Self.regularWidthNumberColumnWidth : .infinity
    }
    private var displayed: TodayHeroSummary {
        isRevealed || accessibilityReduceMotion ? summary : summary.unrevealed
    }

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
        Group {
            switch columns {
            case .two:
                layout {
                    CalorieDonutView(summary: summary.donut, size: Self.donutSize)

                    numberColumn
                        .frame(maxWidth: numberColumnMaxWidth, alignment: .leading)
                }
            case .three:
                HStack(alignment: .center, spacing: Self.columnSpacing) {
                    CalorieDonutView(summary: summary.donut, size: Self.donutSize)

                    figures
                        .frame(width: Self.threeColumnFiguresWidth, alignment: .leading)

                    legend
                        .frame(width: Self.threeColumnLegendWidth, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape([.interaction, .accessibility], .rect)
        .animation(accessibilityReduceMotion ? nil : .smooth(duration: 0.35), value: summary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary.ring.accessibilityLabel)
        .accessibilityValue(summary.ring.accessibilityValue)
        .accessibilityHint(CalorieRingSummary.accessibilityHint(isInteractive: onDetailsRequested != nil))
        .revealOnAppear($isRevealed)
    }

    private var numberColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            figures

            legend
                .padding(.top, 12)
        }
    }

    private var figures: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(displayed.headlineText)
                .font(CalorynTheme.heroNumber(size: numberSize))
                .tracking(-numberSize * 0.01)
                .foregroundStyle(CalorynTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(numberTransition(for: displayed.headline))

            Text(displayed.caption)
                .font(TodayPlateFont.heroCaption)
                .fontWeight(displayed.isOver ? .semibold : .medium)
                .foregroundStyle(displayed.isOver ? CalorynTheme.textPrimary : CalorynTheme.textSecondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .contentTransition(textTransition)

            Text(displayed.eatenLine)
                .font(CalorynTheme.legendText)
                .foregroundStyle(CalorynTheme.textSecondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .contentTransition(textTransition)
        }
        .animation(accessibilityReduceMotion ? nil : .smooth(duration: 0.35), value: displayed)
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(displayed.donut.legend) { entry in
                legendRow(entry)
            }
        }
        .animation(accessibilityReduceMotion ? nil : .smooth(duration: 0.35), value: displayed)
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

            Text(displayed.legendValue(for: entry))
                .fontWeight(isOverRow ? .bold : .medium)
                .foregroundStyle(entry.isLogged ? CalorynTheme.textPrimary : CalorynTheme.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .contentTransition(numberTransition(for: entry.kcal))
        }
        .font(CalorynTheme.legendText)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    @ViewBuilder
    private func legendKey(_ entry: CalorieDonutSummary.LegendEntry) -> some View {
        if let meal = entry.meal {
            if entry.isLogged {
                Circle()
                    .fill(CalorynTheme.mealFill(meal))
                    .frame(width: legendKeySize, height: legendKeySize)
            } else {
                Circle()
                    .strokeBorder(CalorynTheme.mealFill(meal), lineWidth: 1.5)
                    .frame(width: legendKeySize, height: legendKeySize)
            }
        } else {
            Circle()
                .strokeBorder(CalorynTheme.dataPrimary, lineWidth: 2)
                .frame(width: legendKeySize, height: legendKeySize)
        }
    }

    private func numberTransition(for value: Int) -> ContentTransition {
        accessibilityReduceMotion ? .identity : .numericText(value: Double(value))
    }

    private var textTransition: ContentTransition {
        accessibilityReduceMotion ? .identity : .numericText()
    }

    private func requestDetails() {
        guard let onDetailsRequested else { return }
        CalorynHaptics.tap(.medium, intensity: 0.75)
        onDetailsRequested()
    }
}

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
    .background(CalorynTheme.backgroundPrimary)
}

private func previewBudget(consumed: Double) -> CalorieBudget {
    CalorieBudget(consumed: consumed, target: 2_000)
}
