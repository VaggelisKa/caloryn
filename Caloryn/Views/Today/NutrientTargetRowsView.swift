import SwiftUI

struct NutrientTargetRowsView: View {
    let rows: [NutritionDetailsSections.TargetRow]

    @ScaledMetric(relativeTo: .subheadline) private var barHeight: CGFloat = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(rows) { row in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(row.name)
                            .font(TodayPlateFont.detailsRow)
                            .foregroundStyle(CalorynTheme.textPrimary)
                            .lineLimit(1)
                            .layoutPriority(1)

                        Spacer(minLength: 0)

                        figures(row)
                            .multilineTextAlignment(.trailing)
                            .fixedSize(horizontal: false, vertical: true)
                            .contentTransition(.numericText())
                    }

                    progressBar(row.progress)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(row.accessibilityLabel)
            }
        }
    }

    private func figures(_ row: NutritionDetailsSections.TargetRow) -> Text {
        let value = Text(row.valueText)
            .font(TodayPlateFont.detailsRowValue)
            .fontWeight(row.isOverMaximum ? .bold : .semibold)
            .foregroundStyle(CalorynTheme.textPrimary)
        let target = Text(row.targetText)
            .font(TodayPlateFont.detailsRow)
            .foregroundStyle(CalorynTheme.textSecondary)

        guard let overText = row.overText else {
            return Text("\(value) \(target)")
        }
        let over = Text(", \(overText)")
            .font(TodayPlateFont.detailsRowValue)
            .foregroundStyle(CalorynTheme.textPrimary)
        return Text("\(value) \(target)\(over)")
    }

    private func progressBar(_ progress: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(CalorynTheme.fillTrack)

                Capsule()
                    .fill(CalorynTheme.dataPrimary)
                    .frame(width: geo.size.width * progress)
            }
        }
        .frame(height: barHeight)
        .clipShape(Capsule())
        .accessibilityHidden(true)
    }
}
