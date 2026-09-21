import SwiftUI

/// A placeholder shaped like `FoodRowView`.
///
/// The heights are `@ScaledMetric` against the same text styles the real row
/// uses, so the placeholder grows with Dynamic Type at the rate the content it
/// stands in for does.
private struct FoodSearchSkeletonRow: View {
    let row: FoodSearchSkeleton.Row

    @ScaledMetric(relativeTo: .headline) private var titleHeight: CGFloat = 13
    @ScaledMetric(relativeTo: .caption) private var subtitleHeight: CGFloat = 10
    @ScaledMetric(relativeTo: .body) private var calorieHeight: CGFloat = 13
    @ScaledMetric(relativeTo: .caption2) private var calorieUnitHeight: CGFloat = 9
    @ScaledMetric(relativeTo: .headline) private var lineSpacing: CGFloat = 9
    /// Measured, not guessed: a `FoodRowView` in the plain results `List` sits on a
    /// ~75pt pitch once the list has added its own row insets, and these rows are all
    /// one cell, so they get none of that for free. Without this the trailing group
    /// read as a denser list stapled to the bottom of the real one.
    @ScaledMetric(relativeTo: .headline) private var rowPadding: CGFloat = 21

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: lineSpacing) {
                SkeletonBar(width: row.titleWidth, height: titleHeight)
                SkeletonBar(width: row.subtitleWidth, height: subtitleHeight)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: lineSpacing) {
                SkeletonBar(width: row.calorieWidth, height: calorieHeight)
                SkeletonBar(width: 52, height: calorieUnitHeight)
            }
        }
        .padding(.vertical, rowPadding)
    }
}

/// A run of placeholder rows under one shimmer, for use as a single `List` row.
///
/// One cell rather than one per row so the sweep crosses the whole group; a
/// `List` cannot overlay anything across its own rows.
struct FoodSearchSkeletonRows: View {
    var rowCount = FoodSearchSkeleton.trailingRowCount
    var startingAt = 0

    var body: some View {
        ShimmeringPlaceholder {
            VStack(spacing: 0) {
                ForEach(FoodSearchSkeleton.rows(count: rowCount, startingAt: startingAt)) { row in
                    FoodSearchSkeletonRow(row: row)
                }
            }
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
/// A scroll-disabled `ScrollView` rather than a bare `VStack`: the rows are
/// deliberately more than fit, and a `VStack` cannot shrink below its content —
/// it pushed the overflow out both ends and shoved the search field up behind
/// the toolbar. A `ScrollView` takes whatever height it is offered and clips.
struct FoodSearchSkeletonList: View {
    var body: some View {
        ScrollView {
            ShimmeringPlaceholder {
                VStack(alignment: .leading, spacing: 0) {
                    // Stands in for the "Search Results" section header, so the
                    // rows below it do not shift up when the results arrive.
                    SkeletonBar(width: 92, height: 11)
                        .padding(.bottom, 14)

                    ForEach(FoodSearchSkeleton.rows(count: FoodSearchSkeleton.fullScreenRowCount)) { row in
                        FoodSearchSkeletonRow(row: row)
                    }
                }
                .padding(.horizontal, CalorynTheme.pagePadding)
                .padding(.top, 20)
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
        FoodSearchSkeletonRows()
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
    .calorynPlainListStyle()
    .calorynSheetCanvas()
}
