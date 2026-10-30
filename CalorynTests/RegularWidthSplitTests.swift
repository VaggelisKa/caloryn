import CoreGraphics
import Testing
@testable import Caloryn

@Suite("Regular-width split")
@MainActor
struct RegularWidthSplitTests {
    private func split(
        regularWidth: Bool = true,
        regularHeight: Bool = true,
        page: CGSize
    ) -> RegularWidthSplit {
        RegularWidthSplit(isRegularWidth: regularWidth, isRegularHeight: regularHeight, pageSize: page)
    }

    @Test("A compact-width page never gets columns, however wide")
    func compactWidth() {
        #expect(!split(regularWidth: false, page: CGSize(width: 1_200, height: 800)).showsColumns)
    }

    @Test("A compact-height page never gets columns, however wide")
    func compactHeight() {
        #expect(!split(regularHeight: false, page: CGSize(width: 956, height: 440)).showsColumns)
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
