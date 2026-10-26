import SwiftUI

private struct FoodSearchSkeletonRow: View {
    let row: FoodSearchSkeleton.Row

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @ScaledMetric(relativeTo: .callout) private var nameLine: CGFloat = 21
    @ScaledMetric(relativeTo: .footnote) private var detailLine: CGFloat = 18
    @ScaledMetric(relativeTo: .callout) private var figureLine: CGFloat = 21
    @ScaledMetric(relativeTo: .caption2) private var captionLine: CGFloat = 13

    @ScaledMetric(relativeTo: .callout) private var nameBar: CGFloat = 11
    @ScaledMetric(relativeTo: .footnote) private var detailBar: CGFloat = 9
    @ScaledMetric(relativeTo: .callout) private var figureBar: CGFloat = 11
    @ScaledMetric(relativeTo: .caption2) private var captionBar: CGFloat = 7
    @ScaledMetric(relativeTo: .caption2) private var captionWidth: CGFloat = 44

    @ScaledMetric(relativeTo: .callout) private var rowPadding: CGFloat = 12.5

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
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

struct FoodSearchSkeletonRows: View {
    var rowCount = FoodSearchSkeleton.trailingRowCount
    var startingAt = 0

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
