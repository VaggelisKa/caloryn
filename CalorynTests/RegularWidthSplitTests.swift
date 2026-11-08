import CoreGraphics
import Testing
@testable import Caloryn

@Suite("Regular-width split")
@MainActor
struct RegularWidthSplitTests {
    private func split(
        regularWidth: Bool = true,
        regularHeight: Bool = true,
        page: CGSize,
        splitsShortPages: Bool = false
    ) -> RegularWidthSplit {
        RegularWidthSplit(
            isRegularWidth: regularWidth,
            isRegularHeight: regularHeight,
            pageSize: page,
            splitsShortPages: splitsShortPages
        )
    }

    @Test("A compact-width page never gets columns, however wide")
    func compactWidth() {
        #expect(!split(regularWidth: false, page: CGSize(width: 1_200, height: 800)).showsColumns)
    }

    @Test("A compact-height page never gets columns, however wide, unless the screen splits short pages")
    func compactHeight() {
        #expect(!split(regularHeight: false, page: CGSize(width: 832, height: 419)).showsColumns)
    }

    @Test("A short page that splits sits side by side, since a phone held landscape has no fold")
    func shortSplitIsSideBySide() {
        let proMax = split(regularHeight: false, page: CGSize(width: 832, height: 419), splitsShortPages: true)

        #expect(proMax.showsColumns)
        #expect(!proMax.arrangesAroundFold)
    }

    @Test("A short page splits from exactly the short-split width, and not a point less")
    func shortSplitThreshold() {
        let width = RegularWidthSplit.shortSplitMinimumPageWidth

        #expect(split(regularHeight: false, page: CGSize(width: width, height: 419), splitsShortPages: true).showsColumns)
        #expect(!split(regularHeight: false, page: CGSize(width: width - 1, height: 419), splitsShortPages: true).showsColumns)
    }

    @Test("A short page never splits at compact width or when taller than wide")
    func shortSplitNeedsRegularWidthAndLandscape() {
        #expect(!split(regularWidth: false, regularHeight: false, page: CGSize(width: 832, height: 419), splitsShortPages: true).showsColumns)
        #expect(!split(regularHeight: false, page: CGSize(width: 1_100, height: 1_200), splitsShortPages: true).showsColumns)
    }

    @Test("The short split gives the meal rows no less content width than the smallest iPhone in portrait")
    func shortSplitLeavesTheSecondaryColumnItsMinimum() {
        let width = RegularWidthSplit.shortSplitMinimumPageWidth

        #expect(
            width - RegularWidthSplit.primaryColumnWidth(forPageWidth: width)
                >= RegularWidthSplit.shortSecondaryColumnMinimumWidth
        )
        let smallestPortraitPhoneWidth: CGFloat = 375
        #expect(
            RegularWidthSplit.shortSecondaryColumnMinimumWidth - 2 * CalorynTheme.pagePadding
                >= smallestPortraitPhoneWidth - 2 * CalorynTheme.pagePadding
        )
    }

    @Test("The inner display in portrait keeps one page")
    func innerDisplayPortrait() {
        #expect(!split(page: CGSize(width: 669, height: 951)).showsColumns)
    }

    @Test("The inner display in landscape splits around the fold")
    func innerDisplayLandscape() {
        let inner = split(page: CGSize(width: 951, height: 669))

        #expect(inner.showsColumns)
        #expect(inner.arrangesAroundFold)
    }

    @Test("A 13-inch iPad in portrait splits side by side, with no fold to arrange around")
    func largeTabletPortrait() {
        let iPad = split(page: CGSize(width: 1032, height: 1376))

        #expect(iPad.showsColumns)
        #expect(!iPad.arrangesAroundFold)
    }

    @Test("An 11-inch iPad in portrait splits side by side, from the 820pt iPad Air up")
    func elevenInchTabletPortrait() {
        let air = split(page: CGSize(width: 820, height: 1180))
        let pro = split(page: CGSize(width: 834, height: 1194))

        #expect(air.showsColumns)
        #expect(!air.arrangesAroundFold)
        #expect(pro.showsColumns)
    }

    @Test("An iPad mini in portrait keeps one page")
    func miniTabletPortrait() {
        #expect(!split(page: CGSize(width: 744, height: 1133)).showsColumns)
    }

    @Test("The primary column never drops below its minimum, and grows with the page past it")
    func primaryColumnWidth() {
        #expect(RegularWidthSplit.primaryColumnWidth(forPageWidth: 834) == RegularWidthSplit.primaryColumnMinimumWidth)
        #expect(RegularWidthSplit.primaryColumnWidth(forPageWidth: 1032) == 1032 * RegularWidthSplit.primaryColumnFraction)
    }

    @Test("The tall split leaves the secondary column at least its minimum")
    func tallSplitLeavesTheSecondaryColumnItsMinimum() {
        let width = RegularWidthSplit.tallSplitMinimumPageWidth

        #expect(
            width - RegularWidthSplit.primaryColumnWidth(forPageWidth: width)
                >= RegularWidthSplit.secondaryColumnMinimumWidth
        )
    }

    @Test("A page taller than wide splits from exactly the tall-split width, and not a point less")
    func tallSplitThreshold() {
        let width = RegularWidthSplit.tallSplitMinimumPageWidth

        #expect(split(page: CGSize(width: width, height: 1_400)).showsColumns)
        #expect(!split(page: CGSize(width: width - 1, height: 1_400)).showsColumns)
    }
}
