import SwiftUI

struct HistoryAveragesSection: View {
    let averages: HistoryAverages
    @Binding var grouping: HistoryAverages.Grouping

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let selected = averages.resolved(grouping)
        let series = averages.series(for: selected)

        VStack(alignment: .leading, spacing: 14) {
            if averages.groupings.count > 1 {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 8) {
                        HistorySectionTitle("Averages")
                        Spacer(minLength: 8)
                        groupingPicker(selected: selected)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HistorySectionTitle("Averages")
                        groupingPicker(selected: selected)
                    }
                }
            } else {
                HistorySectionTitle("\(selected.title) averages")
            }

            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(series.periods) { period in
                        HistoryAverageRow(
                            period: period,
                            fill: series.fillFraction(for: period),
                            goal: series.goalFraction(for: period)
                        )
                    }
                }
                .id(selected)
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("history.averages")
    }

    private func groupingPicker(selected: HistoryAverages.Grouping) -> some View {
        HStack(spacing: 6) {
            ForEach(averages.groupings) { option in
                let isSelected = option == selected

                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                        grouping = option
                    }
                } label: {
                    Text(option.title)
                        .calorynChip(isSelected: isSelected)
                        .fixedSize()
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityIdentifier("history.averages.\(option.rawValue)")
            }
        }
    }
}

private struct HistoryAverageRow: View {
    let period: HistoryAverages.Period
    let fill: Double
    let goal: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    title
                    Spacer(minLength: 8)
                    amount
                }

                VStack(alignment: .leading, spacing: 2) {
                    title
                    amount
                }
            }

            HistoryGoalBar(fill: fill, goal: goal, tint: period.status.tint)

            Text(period.gapText)
                .font(CalorynTheme.caption.monospacedDigit())
                .foregroundStyle(CalorynTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(period.accessibilityLabel)
        .accessibilityIdentifier("history.averages.period")
    }

    private var title: some View {
        Text(period.title)
            .font(CalorynTheme.cardSubtitle.weight(.semibold))
            .foregroundStyle(CalorynTheme.textPrimary)
            .lineLimit(1)
    }

    @ViewBuilder
    private var amount: some View {
        if let valueText = period.valueText {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(valueText)
                    .font(CalorynTheme.cardSubtitle.weight(.semibold).monospacedDigit())
                    .foregroundStyle(CalorynTheme.textPrimary)
                Text(period.unitText)
                    .font(CalorynTheme.cardSubtitle)
                    .foregroundStyle(CalorynTheme.textSecondary)
            }
        }
    }
}

struct HistoryGoalBar: View {
    let fill: Double
    let goal: Double
    let tint: Color

    private let barHeight: CGFloat = 8
    private let markerSize = CGSize(width: 2, height: 14)

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width

            ZStack(alignment: .leading) {
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(CalorynTheme.fillTrack)

                    Rectangle()
                        .fill(tint)
                        .frame(width: width * fill)
                }
                .frame(height: barHeight)
                .clipShape(Capsule())

                Capsule()
                    .fill(CalorynTheme.dataReference)
                    .frame(width: markerSize.width, height: markerSize.height)
                    .offset(x: min(width - markerSize.width, max(0, width * goal - markerSize.width / 2)))
            }
            .frame(width: width, height: geometry.size.height)
        }
        .frame(height: markerSize.height)
        .accessibilityHidden(true)
    }
}
