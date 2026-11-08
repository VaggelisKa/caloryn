import SwiftUI

struct HistoryOverviewSection: View {
    let overview: HistoryOverviewSummary

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = 40

    private var averageLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
    }

    var body: some View {
        headline
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("history.goalSummary.card")
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 4) {
            if overview.hasLoggedDays {
                averageLayout {
                    Text(overview.averageValueText)
                        .font(CalorynTheme.heroNumber(size: heroSize))
                        .tracking(-heroSize * 0.01)
                        .foregroundStyle(CalorynTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(overview.averageUnitText)
                        .font(CalorynTheme.cardSubtitle.weight(.medium))
                        .foregroundStyle(CalorynTheme.textSecondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(overview.averageAccessibilityLabel)
                .accessibilityIdentifier("history.goalSummary.metric.kcal/day-avg")
            } else {
                Text(overview.emptyHeadlineText)
                    .font(CalorynTheme.sectionTitle)
                    .foregroundStyle(CalorynTheme.textPrimary)
            }

            supportLine
                .font(CalorynTheme.cardSubtitle.monospacedDigit())
                .foregroundStyle(CalorynTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var supportLine: Text {
        guard let gap = overview.goalGap else { return Text(overview.supportText) }
        let emphasis = Text(gap.emphasis)
            .fontWeight(.semibold)
            .foregroundStyle(CalorynTheme.textPrimary)
        return Text("\(emphasis)\(gap.remainder)")
    }
}
