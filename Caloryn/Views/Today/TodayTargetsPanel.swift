import SwiftUI

struct TodayTargetsPanel: View {
    let rows: [NutritionDetailsSections.TargetRow]
    let onDetailsRequested: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var isLargeText: Bool {
        dynamicTypeSize >= .xxxLarge
    }

    private var headerLayout: AnyLayout {
        isLargeText
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
            : AnyLayout(HStackLayout(spacing: 8))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            headerLayout {
                Text("Against your targets")
                    .font(TodayPlateFont.detailsSectionTitle)
                    .foregroundStyle(CalorynTheme.textPrimary)
                    .lineLimit(isLargeText ? nil : 1)
                    .minimumScaleFactor(isLargeText ? 1 : 0.8)
                    .fixedSize(horizontal: false, vertical: isLargeText)
                    .padding(.top, isLargeText ? 12 : 0)
                    .accessibilityAddTraits(.isHeader)

                if !isLargeText {
                    Spacer(minLength: 8)
                }

                Button(action: requestDetails) {
                    HStack(spacing: 3) {
                        Text("All nutrients")
                        Image(systemName: "chevron.right")
                            .imageScale(.small)
                            .accessibilityHidden(true)
                    }
                    .font(TodayPlateFont.detailsRowValue)
                    .foregroundStyle(CalorynTheme.accent)
                    .lineLimit(isLargeText ? nil : 1)
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

    private func requestDetails() {
        CalorynHaptics.tap(.medium, intensity: 0.75)
        onDetailsRequested()
    }
}
