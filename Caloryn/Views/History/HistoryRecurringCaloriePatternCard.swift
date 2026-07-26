import SwiftUI

struct HistoryRecurringCaloriePatternCard: View {
    let pattern: HistoryRecurringCaloriePattern
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(pattern.headline)
                        .font(CalorynTheme.itemTitle)
                        .foregroundStyle(CalorynTheme.textPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(CalorynTheme.compactIcon)
                        .foregroundStyle(CalorynTheme.textSecondary)
                        .accessibilityHidden(true)
                }

                Text(pattern.comparisonText)
                    .font(CalorynTheme.bodyText)
                    .foregroundStyle(CalorynTheme.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(pattern.basisText)
                    .font(CalorynTheme.microCaption)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .historyCard()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("history.recurringPattern.card")
        .accessibilityHint("Shows the evidence behind this pattern")
    }
}

#if DEBUG
#Preview("Recurring Pattern Card") {
    HistoryPreviewFixtures.preview(for: .recurringInsight)
}
#endif
