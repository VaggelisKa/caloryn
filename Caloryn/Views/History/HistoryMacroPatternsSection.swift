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
                goalGrams: pattern.target,
                hitDays: pattern.current.hitDays,
                loggedDays: pattern.current.loggedDays,
                range: range,
                averageGramsChange: pattern.previous.loggedDays > 0 ? pattern.averageValueDelta : nil
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HistorySectionTitle("Macros")

            VStack(alignment: .leading, spacing: 16) {
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
        VStack(alignment: .leading, spacing: 6) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    name
                    Spacer(minLength: 8)
                    amount
                }

                VStack(alignment: .leading, spacing: 2) {
                    name
                    amount
                }
            }

            HistoryInkBar(ratio: row.averageRatio)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.metText)
                    .font(CalorynTheme.caption.monospacedDigit())
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let changeText = row.changeText {
                    Text(changeText)
                        .font(CalorynTheme.caption.monospacedDigit())
                        .foregroundStyle(CalorynTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilityLabel)
    }

    private var name: some View {
        Text(row.name)
            .font(CalorynTheme.cardSubtitle.weight(.semibold))
            .foregroundStyle(CalorynTheme.textPrimary)
            .lineLimit(1)
    }

    private var amount: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(row.averageText)
                .font(CalorynTheme.cardSubtitle.weight(.semibold).monospacedDigit())
                .foregroundStyle(CalorynTheme.textPrimary)
            Text(row.goalText)
                .font(CalorynTheme.cardSubtitle.monospacedDigit())
                .foregroundStyle(CalorynTheme.textSecondary)
        }
    }
}
