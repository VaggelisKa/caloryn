import CoreGraphics
import Testing
@testable import Caloryn

@Suite("Today dashboard layout")
struct TodayDashboardLayoutTests {
    private static let pageMargins = 2 * CalorynTheme.pagePadding

    private func layout(
        regularWidth: Bool = true,
        regularHeight: Bool = true,
        page: CGSize,
        largeText: Bool = false,
        hasTargets: Bool = true
    ) -> TodayDashboardLayout {
        TodayDashboardLayout(
            isRegularWidth: regularWidth,
            isRegularHeight: regularHeight,
            pageSize: page,
            isLargeText: largeText,
            hasTargets: hasTargets
        )
    }

    @Test("A compact-width phone keeps the single page with nothing promoted")
    func compactPhone() {
        let phone = layout(regularWidth: false, page: CGSize(width: 402, height: 874))

        #expect(phone.breakpoint == .compact)
        #expect(phone.heroColumns == .two)
        #expect(!phone.showsTargetsPanel)
        #expect(phone.detailsPlacement == .belowHero)
        #expect(!phone.showsMealsBesideDashboard)
        #expect(phone.mealRowMaximumWidth == .infinity)
    }

    @Test("Compact width stays compact however wide the proposal is")
    func compactWidthIgnoresTheProposal() {
        let window = layout(regularWidth: false, page: CGSize(width: 900, height: 600))

        #expect(window.breakpoint == .compact)
        #expect(window.heroColumns == .two)
        #expect(!window.showsTargetsPanel)
    }

    @Test("The open inner display in portrait gets the wide hero with targets and cluster beneath")
    func innerDisplayPortrait() {
        let inner = layout(page: CGSize(width: 669, height: 951))

        #expect(inner.breakpoint == .narrowRegular)
        #expect(inner.heroColumns == .three)
        #expect(inner.showsTargetsPanel)
        #expect(inner.detailsPlacement == .besideEachOtherBelowHero)
        #expect(!inner.showsMealsBesideDashboard)
        #expect(inner.mealRowMaximumWidth > 669 - Self.pageMargins)
    }

    @Test("The open inner display in landscape splits the dashboard from the meals")
    func innerDisplayLandscape() {
        let inner = layout(page: CGSize(width: 951, height: 669))

        #expect(inner.breakpoint == .wideRegular)
        #expect(inner.showsMealsBesideDashboard)
        #expect(inner.arrangesSplitAroundFold)
        #expect(inner.heroColumns == .two)
        #expect(inner.showsTargetsPanel)
        #expect(inner.detailsPlacement == .belowHero)
    }

    @Test("A wide-regular page never widens the hero, since its column is the narrow one")
    func wideRegularKeepsTheTwoColumnHero() {
        let iPadLandscape = layout(page: CGSize(width: 1376, height: 1032))

        #expect(iPadLandscape.breakpoint == .wideRegular)
        #expect(iPadLandscape.arrangesSplitAroundFold)
        #expect(iPadLandscape.heroColumns == .two)
    }

    @Test("A large iPad in portrait splits too, side by side rather than around a fold")
    func largeTabletPortrait() {
        let iPad = layout(page: CGSize(width: 1032, height: 1376))

        #expect(iPad.breakpoint == .wideRegular)
        #expect(iPad.showsMealsBesideDashboard)
        #expect(!iPad.arrangesSplitAroundFold)
        #expect(iPad.heroColumns == .two)
        #expect(iPad.detailsPlacement == .belowHero)
        #expect(iPad.showsTargetsPanel)
    }

    @Test("A smaller iPad in portrait keeps one list, the targets under the hero and the meals at a readable width")
    func smallTabletPortrait() {
        let iPad = layout(page: CGSize(width: 834, height: 1194))

        #expect(iPad.breakpoint == .narrowRegular)
        #expect(iPad.heroColumns == .three)
        #expect(iPad.detailsPlacement == .besideEachOtherBelowHero)
        #expect(iPad.mealRowMaximumWidth == TodayDashboardLayout.readableMealRowWidth)
        #expect(iPad.mealRowMaximumWidth < 834 - Self.pageMargins)
    }

    @Test("Half of an iPad in Split View is narrow-regular with the wide hero")
    func splitViewHalf() {
        let half = layout(page: CGSize(width: 683, height: 1024))

        #expect(half.breakpoint == .narrowRegular)
        #expect(half.heroColumns == .three)
        #expect(half.showsTargetsPanel)
    }

    @Test("A regular-width phone held landscape is narrow-regular: too short to split")
    func regularWidthCompactHeight() {
        let maxLandscape = layout(regularHeight: false, page: CGSize(width: 956, height: 440))

        #expect(maxLandscape.breakpoint == .narrowRegular)
        #expect(!maxLandscape.showsMealsBesideDashboard)
        #expect(maxLandscape.heroColumns == .three)
        #expect(maxLandscape.detailsPlacement == .besideEachOtherBelowHero)
    }

    @Test("The hero takes three columns from exactly their width, and not a point less")
    func threeColumnThreshold() {
        let width = TodayDashboardLayout.threeColumnHeroWidth + Self.pageMargins
        let fits = layout(page: CGSize(width: width, height: 1_000))
        let short = layout(page: CGSize(width: width - 1, height: 1_000))

        #expect(fits.heroColumns == .three)
        #expect(short.heroColumns == .two)
        #expect(short.detailsPlacement == .besideEachOtherBelowHero)
    }

    @Test("A page taller than wide splits from exactly the width that gives the dashboard its column, and not a point less")
    func tallSplitThreshold() {
        let width = TodayDashboardLayout.tallSplitMinimumPageWidth
        let fits = layout(page: CGSize(width: width, height: 1_400))
        let short = layout(page: CGSize(width: width - 1, height: 1_400))

        #expect(fits.breakpoint == .wideRegular)
        #expect(!fits.arrangesSplitAroundFold)
        #expect(short.breakpoint == .narrowRegular)
        #expect(short.heroColumns == .three)
        #expect(short.detailsPlacement == .besideEachOtherBelowHero)
    }

    @Test("A wide page with compact height stays one list, however wide")
    func compactHeightNeverSplitsTall() {
        let wide = layout(regularHeight: false, page: CGSize(width: 1_100, height: 1_200))

        #expect(wide.breakpoint == .narrowRegular)
        #expect(!wide.showsMealsBesideDashboard)
    }

    @Test("The tall split's dashboard column is never narrower than the inner display's landscape one")
    func tallSplitColumnMatchesTheInnerDisplay() {
        #expect(
            TodayDashboardLayout.tallSplitMinimumPageWidth * TodayDashboardLayout.dashboardColumnFraction
                == TodayDashboardLayout.dashboardColumnMinimumWidth
        )
        #expect(
            951 * TodayDashboardLayout.dashboardColumnFraction >= TodayDashboardLayout.dashboardColumnMinimumWidth
        )
        #expect(669 < TodayDashboardLayout.tallSplitMinimumPageWidth)
    }

    @Test("Every regular-width page caps the meal rows at a readable width")
    func mealRowsAreCappedAtRegularWidth() {
        let pages = [
            layout(page: CGSize(width: 669, height: 951)),
            layout(page: CGSize(width: 951, height: 669)),
            layout(page: CGSize(width: 1032, height: 1376)),
            layout(page: CGSize(width: 1376, height: 1032)),
            layout(regularHeight: false, page: CGSize(width: 956, height: 440)),
        ]

        for page in pages {
            #expect(page.mealRowMaximumWidth == TodayDashboardLayout.readableMealRowWidth)
        }
    }

    @Test("Large text lets the meal rows fill the width they are given")
    func largeTextLeavesMealRowsUncapped() {
        let iPad = layout(page: CGSize(width: 834, height: 1194), largeText: true)

        #expect(iPad.mealRowMaximumWidth == .infinity)
    }

    @Test("The cluster sits beside the targets from exactly their combined width, and not a point less")
    func clusterBesideTargetsThreshold() {
        let width = TodayDashboardLayout.clusterBesideTargetsMinimumWidth + Self.pageMargins
        let fits = layout(page: CGSize(width: width, height: 1_000))
        let short = layout(page: CGSize(width: width - 1, height: 1_000))

        #expect(fits.detailsPlacement == .besideEachOtherBelowHero)
        #expect(fits.heroColumns == .two)
        #expect(short.detailsPlacement == .belowHero)
    }

    @Test("The thresholds are built from the widths the hero and the cluster are drawn at")
    func thresholdsComeFromTheDrawnWidths() {
        #expect(
            TodayDashboardLayout.threeColumnHeroWidth == TodayDashboardLayout.heroDonutSize
                + TodayDashboardLayout.heroFiguresColumnWidth
                + TodayDashboardLayout.heroLegendColumnWidth
                + 2 * TodayDashboardLayout.heroColumnSpacing
        )
        #expect(
            TodayDashboardLayout.clusterBesideTargetsMinimumWidth
                > TodayDashboardLayout.trailingClusterWidth + TodayDashboardLayout.clusterBesideTargetsSpacing
        )
    }

    @Test("Below the cluster width the details stack under the hero")
    func narrowRegularBelowClusterWidth() {
        let narrow = layout(page: CGSize(width: 540, height: 800))

        #expect(narrow.breakpoint == .narrowRegular)
        #expect(narrow.heroColumns == .two)
        #expect(narrow.detailsPlacement == .belowHero)
    }

    @Test("Large text (xxxLarge and up) on a large iPad in portrait still splits, with the stacking hero")
    func largeTextTallSplit() {
        let iPad = layout(page: CGSize(width: 1032, height: 1376), largeText: true)

        #expect(iPad.breakpoint == .wideRegular)
        #expect(iPad.heroColumns == .two)
        #expect(iPad.showsTargetsPanel)
        #expect(iPad.detailsPlacement == .belowHero)
    }

    @Test("Large text on a narrow-regular page keeps the stacking hero and stacks the details too")
    func largeTextNarrowRegularStacks() {
        let iPad = layout(page: CGSize(width: 834, height: 1194), largeText: true)

        #expect(iPad.breakpoint == .narrowRegular)
        #expect(iPad.heroColumns == .two)
        #expect(iPad.showsTargetsPanel)
        #expect(iPad.detailsPlacement == .belowHero)
    }

    @Test("Large text on a wide-regular page keeps the split and stacks its column")
    func largeTextWideRegular() {
        let landscape = layout(page: CGSize(width: 951, height: 669), largeText: true)

        #expect(landscape.breakpoint == .wideRegular)
        #expect(landscape.heroColumns == .two)
        #expect(landscape.detailsPlacement == .belowHero)
    }

    @Test("Without nutrient targets there is no panel to promote")
    func noTargetsNoPanel() {
        let portrait = layout(page: CGSize(width: 669, height: 951), hasTargets: false)
        let landscape = layout(page: CGSize(width: 951, height: 669), hasTargets: false)

        #expect(!portrait.showsTargetsPanel)
        #expect(portrait.heroColumns == .three)
        #expect(!landscape.showsTargetsPanel)
    }
}
