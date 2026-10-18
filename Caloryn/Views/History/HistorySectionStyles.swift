import SwiftUI

// History's pieces of the Plate / Market vocabulary (`docs/design/plate-market.md`): content
// sits directly on the page under sentence-case bold section titles, bars are ink on a
// hairline track, and rows are split by a drawn hairline. Every colour is a `CalorynTheme`
// token. The one grouped surface on the screen, the recurring-pattern insight, uses the
// foundation's `calorynGroupSurface()`.

/// A non-meal section title: 17pt bold ink, sentence case, marked as a heading for VoiceOver.
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

/// An 8pt bar: an ink fill over a hairline track. Macros are told apart by their label, so
/// every bar is ink.
struct HistoryInkBar: View {
    /// 0...1; clamped.
    let ratio: Double

    /// False on the first frame, so the fill grows in from the leading edge.
    @State private var isRevealed = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(CalorynTheme.fillTrack)

                Rectangle()
                    .fill(CalorynTheme.dataPrimary)
                    .frame(width: isRevealed ? geometry.size.width * min(1, max(0, ratio)) : 0)
            }
        }
        .frame(height: 8)
        .revealOnAppear($isRevealed)
        .clipShape(Capsule())
        .accessibilityHidden(true)
    }
}

/// The 1pt rule a scroll view draws between its own rows.
struct HistoryHairline: View {
    var body: some View {
        Rectangle()
            .fill(CalorynTheme.separator)
            .frame(height: CalorynTheme.hairlineWidth)
            .accessibilityHidden(true)
    }
}

/// The sentence-case status pill on a selected day or week: ink text on a hairline wash.
/// Status is never a colour here — the word carries it.
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
