import SwiftUI

// Type sizes and small pieces shared by the Today screens (Today, Nutrition Details, the
// missing-food editor) on the Plate / Market design. The foundation's `CalorynTheme` fonts
// cover most of the vocabulary; these are the few sizes the boards use that it has no token
// for. All text-style relative, so Dynamic Type still scales them, and `.default` design with
// tabular digits on numbers, as `docs/design/plate-market.md` asks. Colours stay in
// `CalorynTheme`.
enum TodayPlateFont {
    /// "Friday 17 October" on the date row: 22pt heavy.
    static let dateTitle: Font = CalorynTypeface.text(.title2, weight: .heavy)
    /// A food row's name: 16pt medium.
    static let rowTitle: Font = CalorynTypeface.text(.callout, weight: .medium)
    /// A food row's grams: 13pt, tabular.
    static let rowDetail: Font = CalorynTypeface.text(.footnote).monospacedDigit()
    /// A food row's kcal: 16pt semibold, tabular, right-aligned in a fixed column.
    static let rowValue: Font = CalorynTypeface.text(.callout, weight: .semibold).monospacedDigit()
    /// The hero's caption under the number ("kcal left of 2,000"): 15pt medium.
    static let heroCaption: Font = CalorynTypeface.text(.subheadline, weight: .medium).monospacedDigit()
    /// The empty meal row's sentence: 15pt.
    static let emptyRow: Font = CalorynTypeface.text(.subheadline)
    /// A Nutrition Details section title ("Against your targets"): 15pt bold.
    static let detailsSectionTitle: Font = CalorynTypeface.text(.subheadline, weight: .bold)
    /// A Nutrition Details row: 15pt, tabular.
    static let detailsRow: Font = CalorynTypeface.text(.subheadline).monospacedDigit()
    /// The amount on a target row ("46g"): 15pt semibold, tabular.
    static let detailsRowValue: Font = CalorynTypeface.text(.subheadline, weight: .semibold).monospacedDigit()
    /// The line beside the big number ("of 2,000 kcal"): 15pt semibold.
    static let detailsNumberCaption: Font = CalorynTypeface.text(.subheadline, weight: .semibold).monospacedDigit()
    /// Notes and trailing counts ("3 kinds today"): 13pt.
    static let detailsNote: Font = CalorynTypeface.text(.footnote).monospacedDigit()
    /// The data-quality note at the foot of the sheet: 12pt.
    static let detailsFootnote: Font = CalorynTypeface.text(.caption)
}

/// The "Recipe" / "Yours" badge on a logged entry's row: the same badge `FoodRowView` draws
/// on search and My Foods rows, sentence case, bold, one tint whatever meal the row sits
/// under (`fillBadge` / `textSecondary`).
struct TodayTypeBadge: View {
    let isRecipe: Bool

    var body: some View {
        Text(isRecipe ? "Recipe" : "Yours")
            .font(CalorynTheme.badgeText)
            .fontWeight(.bold)
            .foregroundStyle(CalorynTheme.textSecondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(CalorynTheme.fillBadge, in: .capsule)
    }
}

/// Lays chips out left to right and wraps them onto further lines, for chip rows whose
/// count depends on the day (fruit and veg kinds, the Nutri-Score grades) or on the text
/// size (the missing-food editor's meal chips).
///
/// No chip is ever wider than the line. One that would be — a long scanned product name —
/// gets the whole line on its own and is offered exactly that width, so its `lineLimit(1)`
/// truncates it with an ellipsis instead of drawing it past the margin.
struct ChipFlowLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = rows(for: subviews, maxWidth: maxWidth)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: min(width, maxWidth), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(for: subviews, maxWidth: bounds.width) {
            var x = bounds.minX
            for item in row.items {
                let size = CGSize(width: min(item.size.width, bounds.width), height: item.size.height)
                subviews[item.index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Item {
        let index: Int
        let size: CGSize
    }

    private struct Row {
        var items: [Item] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(for subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = chipSize(subviews[index], maxWidth: maxWidth)
            if !current.items.isEmpty, current.width + spacing + size.width > maxWidth {
                rows.append(current)
                current = Row()
            }
            current.width = current.items.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.items.append(Item(index: index, size: size))
        }
        if !current.items.isEmpty {
            rows.append(current)
        }
        return rows
    }

    /// The chip's own width when it fits on a line, otherwise what it measures when offered
    /// the line's width — a one-line `Text` then reports its truncated size.
    private func chipSize(_ subview: LayoutSubview, maxWidth: CGFloat) -> CGSize {
        let ideal = subview.sizeThatFits(.unspecified)
        guard maxWidth.isFinite, ideal.width > maxWidth else { return ideal }
        let fitted = subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
        return CGSize(width: min(fitted.width, maxWidth), height: fitted.height)
    }
}

/// Today's navigation bar, which has nothing in it: the date row is the heading. iOS 26
/// collapses a titleless bar to nothing, so the date row sits straight under the status bar.
/// Before it the bar still stands 44pt tall above the date row, empty, so there it is hidden
/// and the status bar is backed with the page colour, which is what the bar was doing for the
/// rows that scroll under the clock.
private struct TodayTitlelessBarModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
        } else {
            content
                .toolbar(.hidden, for: .navigationBar)
                .overlay(alignment: .top) {
                    Color.clear
                        .frame(height: 0)
                        .background(CalorynTheme.pageBackground.ignoresSafeArea(edges: .top))
                        .allowsHitTesting(false)
                }
        }
    }
}

extension View {
    /// Apply inside Today's `NavigationStack`, on the screen content, with the page canvas.
    func todayTitlelessBar() -> some View {
        modifier(TodayTitlelessBarModifier())
    }
}
