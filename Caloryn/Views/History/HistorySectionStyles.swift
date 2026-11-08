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

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(CalorynTheme.fillTrack)

                Rectangle()
                    .fill(CalorynTheme.dataPrimary)
                    .frame(width: geometry.size.width * min(1, max(0, ratio)))
            }
        }
        .frame(height: 8)
        .clipShape(Capsule())
        .accessibilityHidden(true)
    }
}

struct HistoryGoalBar: View {
    let fill: Double
    let goal: Double
    let tint: Color

    private let barHeight: CGFloat = 8
    private let markerSize = CGSize(width: 2, height: 14)

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width

            ZStack(alignment: .leading) {
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(CalorynTheme.fillTrack)

                    Rectangle()
                        .fill(tint)
                        .frame(width: width * fill)
                }
                .frame(height: barHeight)
                .clipShape(Capsule())

                Capsule()
                    .fill(CalorynTheme.dataReference)
                    .frame(width: markerSize.width, height: markerSize.height)
                    .offset(x: min(width - markerSize.width, max(0, width * goal - markerSize.width / 2)))
            }
            .frame(width: width, height: geometry.size.height)
        }
        .frame(height: markerSize.height)
        .accessibilityHidden(true)
    }
}

struct HistoryHairline: View {
    var body: some View {
        Rectangle()
            .fill(CalorynTheme.separator)
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
            .background(CalorynTheme.fillTrack, in: Capsule())
            .accessibilityLabel(status.sentenceLabel)
    }
}
