import SwiftUI

// The library row of the Plate vocabulary (`docs/design/plate-market.md`, "Row"), for every row
// My Foods draws — foods, saved meals and recipes alike, so one list has one typography: name
// 16pt medium, detail 13pt in the secondary text, kcal 16pt semibold tabular over an 11pt unit,
// right-aligned in a fixed column.
//
// `FoodRowView` is the Add Food lane's row and keeps its own metrics; My Foods does not mix it
// into these lists. Fold the two together once both lanes have landed.
enum LibraryRowStyle {
    static let name: Font = .system(.callout, weight: .medium)
    static let detail: Font = .system(.footnote)
    static let kcal: Font = .system(.callout, weight: .semibold).monospacedDigit()
    static let unit: Font = .system(.caption2)
    /// The kcal column: wide enough for four digits, so numbers line up down a section.
    static let kcalColumnWidth: CGFloat = 44
    /// The board's row rhythm, 10pt above and below a row's text, where a plain list gives a
    /// taller row. The sides stay on the system's 16pt margin, which is where the large title
    /// and the + button sit: the board's 20pt would put the rows out of line with them.
    static let rowInsets = EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
    /// A section title sits on the same margin, close over the hairline that opens its rows.
    /// The list's own section spacing is the gap above it. Drawn as padding inside the header,
    /// not as its row insets, so the header's page-coloured background runs edge to edge.
    static let headerPadding = EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16)
}

/// A library row's frame: its text on the left, the kcal stack in its column on the right.
///
/// At accessibility text sizes the two do not fit side by side: the name would truncate to a
/// letter. There the kcal drops under the text as one line ("418 kcal total") and the text may
/// wrap; a badge moves under the name (`LibraryRowTitle`) and keeps to one line.
struct LibraryRowLayout<Content: View>: View {
    let caloriesText: String?
    let unit: String
    @ViewBuilder let content: () -> Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 4) {
                content()
                    .lineLimit(3)

                if let caloriesText {
                    LibraryRowCalories(caloriesText: caloriesText, unit: unit, isInline: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: .center, spacing: 10) {
                content()
                    .lineLimit(1)

                Spacer(minLength: 8)

                if let caloriesText {
                    LibraryRowCalories(caloriesText: caloriesText, unit: unit)
                }
            }
        }
    }
}

/// A row's name with its badge (Nutri-Score or type), side by side. At accessibility sizes the
/// badge goes under the name instead, so a long word keeps the row's full width rather than
/// breaking mid-word beside the badge.
struct LibraryRowTitle<Badge: View>: View {
    let name: String
    @ViewBuilder let badge: () -> Badge

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(spacing: 6))

        layout {
            Text(name)
                .font(LibraryRowStyle.name)
                .foregroundStyle(CalorynTheme.textPrimary)

            badge()
        }
    }
}

/// The right-hand stack of a library row: the kcal figure over its unit. Inline, under the
/// text at accessibility sizes, the two share a line instead.
struct LibraryRowCalories: View {
    let caloriesText: String
    let unit: String
    var isInline = false

    var body: some View {
        if isInline {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                figure
                unitText
            }
        } else {
            VStack(alignment: .trailing, spacing: 1) {
                figure
                unitText
            }
            .frame(minWidth: LibraryRowStyle.kcalColumnWidth, alignment: .trailing)
        }
    }

    private var figure: some View {
        Text(caloriesText)
            .font(LibraryRowStyle.kcal)
            .foregroundStyle(CalorynTheme.textPrimary)
            .lineLimit(1)
    }

    private var unitText: some View {
        Text(unit)
            .font(LibraryRowStyle.unit)
            .foregroundStyle(CalorynTheme.textSecondary)
            .lineLimit(1)
    }
}

/// The "Recipe" / "Yours" type badge, for a food listed among other kinds of food (Favorites). The
/// same tint and weight `FoodRowView` draws for its own badge. Always one line at its own
/// width: squeezed beside a long name it would otherwise break mid-word.
struct LibraryTypeBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(CalorynTheme.badgeText)
            .fontWeight(.bold)
            .foregroundStyle(CalorynTheme.typeBadgeText)
            .lineLimit(1)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(CalorynTheme.typeBadgeFill, in: .capsule)
            .fixedSize()
    }
}

extension View {
    /// Row chrome for the library's hairline list: a clear row on the page, hairline
    /// separators that stop at the content's right edge as the board draws them, and the
    /// section's own top separator kept (it rules the header off from the first row) while
    /// its bottom one goes. Apply to each `Section`.
    func libraryHairlineSection() -> some View {
        calorynHairlineSeparators()
            .listRowInsets(LibraryRowStyle.rowInsets)
            .listSectionSeparatorTint(CalorynTheme.hairline)
            .listSectionSeparator(.visible, edges: .top)
            .listSectionSeparator(.hidden, edges: .bottom)
    }

    /// Ends a row's bottom separator at the row content's trailing edge instead of the
    /// screen's, so the hairline keeps the page's right margin.
    func libraryRowSeparatorInset() -> some View {
        alignmentGuide(.listRowSeparatorTrailing) { dimensions in
            dimensions[.trailing]
        }
    }
}
