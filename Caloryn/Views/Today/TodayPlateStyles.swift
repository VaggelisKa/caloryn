import SwiftUI

enum TodayPlateFont {
    static let dateTitle: Font = CalorynTypeface.text(.title2, weight: .heavy)
    static let rowTitle: Font = CalorynTypeface.text(.callout, weight: .medium)
    static let rowDetail: Font = CalorynTypeface.text(.footnote).monospacedDigit()
    static let rowValue: Font = CalorynTypeface.text(.callout, weight: .semibold).monospacedDigit()
    static let heroCaption: Font = CalorynTypeface.text(.subheadline, weight: .medium).monospacedDigit()
    static let emptyRow: Font = CalorynTypeface.text(.subheadline)
    static let detailsSectionTitle: Font = CalorynTypeface.text(.subheadline, weight: .bold)
    static let detailsRow: Font = CalorynTypeface.text(.subheadline).monospacedDigit()
    static let detailsRowValue: Font = CalorynTypeface.text(.subheadline, weight: .semibold).monospacedDigit()
    static let detailsNumberCaption: Font = CalorynTypeface.text(.subheadline, weight: .semibold).monospacedDigit()
    static let detailsNote: Font = CalorynTypeface.text(.footnote).monospacedDigit()
    static let detailsFootnote: Font = CalorynTypeface.text(.caption)
}

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

    private func chipSize(_ subview: LayoutSubview, maxWidth: CGFloat) -> CGSize {
        let ideal = subview.sizeThatFits(.unspecified)
        guard maxWidth.isFinite, ideal.width > maxWidth else { return ideal }
        let fitted = subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
        return CGSize(width: min(fitted.width, maxWidth), height: fitted.height)
    }
}

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
                        .background(CalorynTheme.backgroundPrimary.ignoresSafeArea(edges: .top))
                        .allowsHitTesting(false)
                }
        }
    }
}

extension View {
    func todayTitlelessBar() -> some View {
        modifier(TodayTitlelessBarModifier())
    }
}
