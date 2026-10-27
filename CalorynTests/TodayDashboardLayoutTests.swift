import CoreGraphics
import Testing
@testable import Caloryn

@Suite("Today dashboard layout")
struct TodayDashboardLayoutTests {
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
            contentWidth: page.width - 40,
            isWiderThanTall: page.width > page.height,
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
    }

    @Test("The open inner display in landscape splits the dashboard from the meals")
    func innerDisplayLandscape() {
        let inner = layout(page: CGSize(width: 951, height: 669))

        #expect(inner.breakpoint == .wideRegular)
        #expect(inner.showsMealsBesideDashboard)
        #expect(inner.heroColumns == .two)
        #expect(inner.showsTargetsPanel)
        #expect(inner.detailsPlacement == .belowHero)
    }

    @Test("A wide-regular page never widens the hero, since its column is the narrow one")
    func wideRegularKeepsTheTwoColumnHero() {
        let iPadLandscape = layout(page: CGSize(width: 1376, height: 1032))

        #expect(iPadLandscape.breakpoint == .wideRegular)
        #expect(iPadLandscape.heroColumns == .two)
    }

    @Test("A large iPad in portrait puts the targets beside the hero")
    func largeTabletPortrait() {
        let iPad = layout(page: CGSize(width: 1032, height: 1376))

        #expect(iPad.breakpoint == .narrowRegular)
        #expect(iPad.heroColumns == .three)
        #expect(iPad.detailsPlacement == .besideHero)
    }

    @Test("A smaller iPad in portrait keeps the targets under the hero")
    func smallTabletPortrait() {
        let iPad = layout(page: CGSize(width: 834, height: 1194))

        #expect(iPad.breakpoint == .narrowRegular)
        #expect(iPad.heroColumns == .three)
        #expect(iPad.detailsPlacement == .besideEachOtherBelowHero)
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
        let width = TodayDashboardLayout.threeColumnHeroWidth
        let fits = layout(page: CGSize(width: width + 40, height: 1_000))
        let short = layout(page: CGSize(width: width + 39, height: 1_000))

        #expect(fits.heroColumns == .three)
        #expect(short.heroColumns == .two)
        #expect(short.detailsPlacement == .besideEachOtherBelowHero)
    }

    @Test("Below the cluster width the details stack under the hero")
    func narrowRegularBelowClusterWidth() {
        let narrow = layout(page: CGSize(width: 540, height: 800))

        #expect(narrow.breakpoint == .narrowRegular)
        #expect(narrow.heroColumns == .two)
        #expect(narrow.detailsPlacement == .belowHero)
    }

    @Test("Accessibility text keeps the stacking hero and stacks the details too")
    func largeTextStacks() {
        let inner = layout(page: CGSize(width: 1032, height: 1376), largeText: true)

        #expect(inner.breakpoint == .narrowRegular)
        #expect(inner.heroColumns == .two)
        #expect(inner.showsTargetsPanel)
        #expect(inner.detailsPlacement == .belowHero)
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
