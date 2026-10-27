import Foundation

struct RegularWidthSplit: Equatable {
    static let primaryColumnFraction: CGFloat = 0.4
    static let primaryColumnMinimumWidth: CGFloat = 380
    static let tallSplitMinimumPageWidth: CGFloat = primaryColumnMinimumWidth / primaryColumnFraction

    let showsColumns: Bool
    let arrangesAroundFold: Bool

    init(isRegularWidth: Bool, isRegularHeight: Bool, pageSize: CGSize) {
        let isWiderThanTall = pageSize.width > pageSize.height
        let fitsTallSplit = pageSize.width >= Self.tallSplitMinimumPageWidth
        showsColumns = isRegularWidth && isRegularHeight && (isWiderThanTall || fitsTallSplit)
        arrangesAroundFold = showsColumns && isWiderThanTall
    }
}
