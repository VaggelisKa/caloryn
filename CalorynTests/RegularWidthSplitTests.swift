import CoreGraphics
import Testing
@testable import Caloryn

@Suite("Regular-width split")
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

    @Test("An 11-inch iPad in portrait keeps one page")
    func smallTabletPortrait() {
        #expect(!split(page: CGSize(width: 834, height: 1194)).showsColumns)
    }

    @Test("A page taller than wide splits from exactly the tall-split width, and not a point less")
    func tallSplitThreshold() {
        let width = RegularWidthSplit.tallSplitMinimumPageWidth

        #expect(split(page: CGSize(width: width, height: 1_400)).showsColumns)
        #expect(!split(page: CGSize(width: width - 1, height: 1_400)).showsColumns)
    }
}
