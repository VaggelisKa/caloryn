import SwiftUI

struct HistoryMacroPatternsSection: View {
    let range: HistoryRange
    let projection: HistoryMacroPatternsProjection

    private var rows: [HistoryMacroRowSummary] {
        projection.patterns.map { pattern in
            HistoryMacroRowSummary(
                id: pattern.id,
                name: pattern.nutrient.displayName,
                goalKind: pattern.goalKind,
                averageGrams: pattern.current.averageValue,
                hitDays: pattern.current.hitDays,
                loggedDays: pattern.current.loggedDays,
                range: range,
                averageGramsChange: pattern.previous.loggedDays > 0 ? pattern.averageValueDelta : nil
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HistorySectionTitle("Macros")

                if let summaryText = projection.summaryText {
                    Text(summaryText)
                        .font(CalorynTheme.cardSubtitle)
                        .foregroundStyle(CalorynTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(rows) { row in
                    HistoryMacroPatternRow(row: row)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HistoryMacroPatternRow: View {
    let row: HistoryMacroRowSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    name
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 1) {
                        detail
                        change
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    name
                    detail
                    change
                }
            }

            HistoryInkBar(ratio: row.hitRatio)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilityLabel)
    }

    private var name: some View {
        Text(row.name)
            .font(CalorynTheme.cardSubtitle.weight(.semibold))
            .foregroundStyle(CalorynTheme.textPrimary)
    }

    private var detail: some View {
        Text(row.detailText)
            .font(CalorynTheme.cardSubtitle.monospacedDigit())
            .foregroundStyle(CalorynTheme.textSecondary)
    }

    @ViewBuilder
    private var change: some View {
        if let changeText = row.changeText {
            Text(changeText)
                .font(CalorynTheme.caption.monospacedDigit())
                .foregroundStyle(CalorynTheme.textSecondary)
        }
    }
}
