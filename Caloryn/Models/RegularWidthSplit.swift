import Foundation

struct RegularWidthSplit: Equatable {
    static let primaryColumnFraction: CGFloat = 0.4
    static let primaryColumnMinimumWidth: CGFloat = 380
    static let secondaryColumnMinimumWidth: CGFloat = 440
    static let shortSecondaryColumnMinimumWidth: CGFloat = 380
    static let tallSplitMinimumPageWidth: CGFloat = primaryColumnMinimumWidth + secondaryColumnMinimumWidth
    static let shortSplitMinimumPageWidth: CGFloat = primaryColumnMinimumWidth + shortSecondaryColumnMinimumWidth

    let showsColumns: Bool
    let arrangesAroundFold: Bool

    init(isRegularWidth: Bool, isRegularHeight: Bool, pageSize: CGSize, splitsShortPages: Bool = false) {
        let isWiderThanTall = pageSize.width > pageSize.height
        guard isRegularHeight else {
            showsColumns = splitsShortPages
                && isRegularWidth
                && isWiderThanTall
                && pageSize.width >= Self.shortSplitMinimumPageWidth
            arrangesAroundFold = false
            return
        }
        let fitsTallSplit = pageSize.width >= Self.tallSplitMinimumPageWidth
        showsColumns = isRegularWidth && (isWiderThanTall || fitsTallSplit)
        arrangesAroundFold = showsColumns && isWiderThanTall
    }

    static func primaryColumnWidth(forPageWidth pageWidth: CGFloat) -> CGFloat {
        max(pageWidth * primaryColumnFraction, primaryColumnMinimumWidth)
    }
}
