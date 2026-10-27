import SwiftUI

struct TodayTargetsPanel: View {
    let rows: [NutritionDetailsSections.TargetRow]
    let onDetailsRequested: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("Against your targets")
                    .font(TodayPlateFont.detailsSectionTitle)
                    .foregroundStyle(CalorynTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .accessibilityAddTraits(.isHeader)

                Spacer(minLength: 8)

                Button(action: onDetailsRequested) {
                    HStack(spacing: 3) {
                        Text("All nutrients")
                        Image(systemName: "chevron.right")
                            .imageScale(.small)
                    }
                    .font(TodayPlateFont.detailsRowValue)
                    .foregroundStyle(CalorynTheme.accent)
                    .lineLimit(1)
                    .frame(minHeight: 44)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("today.targetsPanel.allNutrients")
            }

            NutrientTargetRowsView(rows: rows)
        }
        .padding(.horizontal, CalorynTheme.cardPadding)
        .padding(.bottom, CalorynTheme.cardPadding)
        .padding(.top, 4)
        .calorynGroupSurface()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("today.targetsPanel")
    }
}
