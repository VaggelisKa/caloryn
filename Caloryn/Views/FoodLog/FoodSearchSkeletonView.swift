import SwiftUI

/// A placeholder shaped like `FoodRowView`: the name over its brand-and-serving line on
/// the left, the two-line kcal figure on the right.
///
/// Each bar sits in a line as tall as the `FoodRowTypography` style it stands in for, with
/// the real row's spacings, so the placeholder is the height of the row that replaces it
/// and grows with Dynamic Type at the same rate.
private struct FoodSearchSkeletonRow: View {
    let row: FoodSearchSkeleton.Row

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // Line heights of the four `FoodRowTypography` styles at the default size.
    @ScaledMetric(relativeTo: .callout) private var nameLine: CGFloat = 21
    @ScaledMetric(relativeTo: .footnote) private var detailLine: CGFloat = 18
    @ScaledMetric(relativeTo: .callout) private var figureLine: CGFloat = 21
    @ScaledMetric(relativeTo: .caption2) private var captionLine: CGFloat = 13

    // Bars about the cap height of each style, so a line reads as text, not a block.
    @ScaledMetric(relativeTo: .callout) private var nameBar: CGFloat = 11
    @ScaledMetric(relativeTo: .footnote) private var detailBar: CGFloat = 9
    @ScaledMetric(relativeTo: .callout) private var figureBar: CGFloat = 11
    @ScaledMetric(relativeTo: .caption2) private var captionBar: CGFloat = 7
    @ScaledMetric(relativeTo: .caption2) private var captionWidth: CGFloat = 44

    /// The plain list's own vertical row inset, which a `FoodRowView` gets for free and
    /// these rows — all one cell — do not.
    @ScaledMetric(relativeTo: .callout) private var rowPadding: CGFloat = 12.5

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                // `FoodRowView` stacks at these sizes, the figure reading inline below.
                VStack(alignment: .leading, spacing: 4) {
                    SkeletonBar(width: row.titleWidth, height: nameBar, lineHeight: nameLine)
                    SkeletonBar(width: row.subtitleWidth, height: detailBar, lineHeight: detailLine)
                    SkeletonBar(width: row.calorieWidth + captionWidth, height: figureBar, lineHeight: figureLine)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        SkeletonBar(width: row.titleWidth, height: nameBar, lineHeight: nameLine)
                        SkeletonBar(width: row.subtitleWidth, height: detailBar, lineHeight: detailLine)
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 1) {
                        SkeletonBar(width: row.calorieWidth, height: figureBar, lineHeight: figureLine)
                        SkeletonBar(width: captionWidth, height: captionBar, lineHeight: captionLine)
                    }
                }
            }
        }
        .padding(.vertical, rowPadding)
    }
}

/// Placeholder rows divided by the list's hairline, as `calorynHairlineSeparators()` divides
/// real ones. `separatorAfterLast` is for the full-screen block, whose last row runs on into
/// more; the trailing group ends where the list does.
private struct FoodSearchSkeletonStack: View {
    let rows: [FoodSearchSkeleton.Row]
    var separatorAfterLast = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(rows) { row in
                FoodSearchSkeletonRow(row: row)

                if separatorAfterLast || row.id != rows.last?.id {
                    Rectangle()
                        .fill(CalorynTheme.separator)
                        .frame(height: CalorynTheme.hairlineWidth)
                }
            }
        }
    }
}

/// A run of placeholder rows under one shimmer, for use as a single `List` row.
///
/// One cell rather than one per row so the sweep crosses the whole group; a
/// `List` cannot overlay anything across its own rows.
struct FoodSearchSkeletonRows: View {
    var rowCount = FoodSearchSkeleton.trailingRowCount
    var startingAt = 0

    /// No vertical inset — each placeholder row carries the list's own — and the 16pt
    /// margin the real rows and their section titles share.
    static let listRowInsets = EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)

    var body: some View {
        ShimmeringPlaceholder {
            FoodSearchSkeletonStack(
                rows: FoodSearchSkeleton.rows(count: rowCount, startingAt: startingAt)
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Searching for more results")
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilityIdentifier("foodSearch.loadingMore")
    }
}

/// The whole area below the search field while a query is in flight and nothing
/// local matched it.
///
/// No stand-in for a section title: with nothing local to show, the results that replace
/// this arrive untitled, so a title bar here would only make the rows jump.
///
/// A scroll-disabled `ScrollView` rather than a bare `VStack`: the rows are
/// deliberately more than fit, and a `VStack` cannot shrink below its content —
/// it pushed the overflow out both ends and shoved the search field up behind
/// the toolbar. A `ScrollView` takes whatever height it is offered and clips.
struct FoodSearchSkeletonList: View {
    var body: some View {
        ScrollView {
            ShimmeringPlaceholder {
                FoodSearchSkeletonStack(
                    rows: FoodSearchSkeleton.rows(count: FoodSearchSkeleton.fullScreenRowCount),
                    separatorAfterLast: true
                )
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .scrollDisabled(true)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Searching")
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilityIdentifier("foodSearch.loading")
    }
}

#Preview("Full screen") {
    VStack(spacing: 0) {
        FoodSearchSkeletonList()
    }
    .calorynSheetCanvas()
}

#Preview("Trailing rows") {
    List {
        FoodRowView(name: "Skyr", brand: "Arla", caloriesPer100g: 63)
            .calorynHairlineSeparators()
        FoodSearchSkeletonRows()
            .listRowInsets(FoodSearchSkeletonRows.listRowInsets)
            .listRowSeparator(.hidden, edges: .bottom)
            .listRowSeparatorTint(CalorynTheme.separator)
            .calorynClearRowBackground()
    }
    .calorynPlainListStyle()
    .calorynSheetCanvas()
}
