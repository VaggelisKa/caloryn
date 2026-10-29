import SwiftUI

struct HistoryRecurringCaloriePatternCard: View {
    let pattern: HistoryRecurringCaloriePattern
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(pattern.headline)
                        .font(CalorynTheme.sectionHeaderTitle)
                        .foregroundStyle(CalorynTheme.textPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    HistoryRecurringCaloriePatternPhraseText(
                        phrase: pattern.mealComparison,
                        font: CalorynTheme.cardSubtitle,
                        emphasisFont: CalorynTheme.cardSubtitle.weight(.semibold)
                    )
                    .lineSpacing(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                    Text(pattern.frequencyText)
                        .font(CalorynTheme.caption)
                        .foregroundStyle(CalorynTheme.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(CalorynTheme.compactIcon)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .padding(.top, 4)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 18)
            .calorynGroupSurface()
            .contentShape(.rect(cornerRadius: CalorynTheme.groupCornerRadius))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("history.recurringPattern.card")
        .accessibilityHint("Shows the evidence behind this pattern")
    }
}

struct HistoryRecurringCaloriePatternPhraseText: View {
    let phrase: HistoryRecurringCaloriePatternPhrase
    let font: Font
    let emphasisFont: Font

    var body: some View {
        Text(attributed)
            .font(font)
            .foregroundStyle(CalorynTheme.textSecondary)
    }

    private var attributed: AttributedString {
        phrase.runs.reduce(into: AttributedString()) { result, run in
            var part = AttributedString(run.text)
            if run.isEmphasised {
                part.font = emphasisFont
                part.foregroundColor = CalorynTheme.textPrimary
            }
            result += part
        }
    }
}

#if DEBUG
#Preview("Recurring Pattern Card") {
    HistoryPreviewFixtures.preview(for: .recurringInsight)
}
#endif
