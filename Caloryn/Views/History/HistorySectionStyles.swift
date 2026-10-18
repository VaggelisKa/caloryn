import SwiftUI

struct HistorySectionTitle: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(CalorynTheme.sectionHeaderTitle)
            .foregroundStyle(CalorynTheme.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }
}

struct HistoryInkBar: View {
    let ratio: Double

    @State private var isRevealed = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(CalorynTheme.hairline)

                Rectangle()
                    .fill(CalorynTheme.textPrimary)
                    .frame(width: isRevealed ? geometry.size.width * min(1, max(0, ratio)) : 0)
            }
        }
        .frame(height: 8)
        .revealOnAppear($isRevealed)
        .clipShape(Capsule())
        .accessibilityHidden(true)
    }
}

struct HistoryHairline: View {
    var body: some View {
        Rectangle()
            .fill(CalorynTheme.hairline)
            .frame(height: CalorynTheme.hairlineWidth)
            .accessibilityHidden(true)
    }
}

struct HistoryStatusBadge: View {
    let status: HistoryGoalStatus

    var body: some View {
        Text(status.sentenceLabel)
            .font(CalorynTheme.badgeText)
            .foregroundStyle(CalorynTheme.textPrimary)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(CalorynTheme.hairline, in: Capsule())
            .accessibilityLabel(status.sentenceLabel)
    }
}
