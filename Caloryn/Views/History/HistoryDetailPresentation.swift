import SwiftUI

enum HistoryDetailPresentation {
    case pushed
    case inline
}

struct HistoryDetailPaneTitle: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(CalorynTheme.sectionTitle.weight(.heavy))
            .tracking(-0.2)
            .foregroundStyle(CalorynTheme.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }
}

struct HistoryDetailEmptyPane: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HistoryDetailPaneTitle("Details")

            Text("Log meals on a few more days to see the calorie trend in detail here.")
                .font(CalorynTheme.cardSubtitle)
                .foregroundStyle(CalorynTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, CalorynTheme.pagePadding)
        .padding(.top, 8)
        .frame(maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("history.detail.empty")
    }
}

extension View {
    @ViewBuilder
    func historyDetailChrome(_ title: String, presentation: HistoryDetailPresentation) -> some View {
        switch presentation {
        case .pushed:
            calorynDrillDownNavigation()
                .calorynInlineTitle(title)
        case .inline:
            self
        }
    }

    func historyDetailSource(isSelected: Bool, outset: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: CalorynTheme.groupCornerRadius, style: .continuous)

        return background {
            if isSelected {
                shape
                    .fill(CalorynTheme.backgroundSecondary)
                    .padding(-outset)
            }
        }
        .overlay {
            if isSelected {
                shape
                    .strokeBorder(CalorynTheme.accent.opacity(0.35), lineWidth: CalorynTheme.hairlineWidth)
                    .padding(-outset)
                    .allowsHitTesting(false)
            }
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
