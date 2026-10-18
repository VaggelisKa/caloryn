import SwiftUI

/// The recurring-pattern insight: History's one grouped surface, a white bordered callout
/// that opens the evidence behind it. The basis ("Based on 30 logged days…") lives on the
/// details screen it opens, which leads with it.
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

                    Text(pattern.comparisonText)
                        .font(CalorynTheme.cardSubtitle)
                        .foregroundStyle(CalorynTheme.textSecondary)
                        .lineSpacing(3)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
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

#if DEBUG
#Preview("Recurring Pattern Card") {
    HistoryPreviewFixtures.preview(for: .recurringInsight)
}
#endif
