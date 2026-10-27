import Foundation

struct TodayDashboardLayout: Equatable {
    enum Breakpoint: Equatable {
        case compact
        case narrowRegular
        case wideRegular
    }

    enum HeroColumns: Equatable {
        case two
        case three
    }

    enum DetailsPlacement: Equatable {
        case belowHero
        case besideEachOtherBelowHero
    }

    static let heroDonutSize: CGFloat = 168
    static let heroColumnSpacing: CGFloat = 18
    static let heroFiguresColumnWidth: CGFloat = 200
    static let heroLegendColumnWidth: CGFloat = 220
    static let trailingClusterWidth: CGFloat = 240
    static let clusterBesideTargetsSpacing: CGFloat = 24
    static let clusterBesideTargetsMinimumPanelWidth: CGFloat = 256
    static let dashboardColumnFraction: CGFloat = 0.4
    static let dashboardColumnMinimumWidth: CGFloat = 380
    static let readableMealRowWidth: CGFloat = 672

    static let threeColumnHeroWidth: CGFloat =
        heroDonutSize + heroFiguresColumnWidth + heroLegendColumnWidth + 2 * heroColumnSpacing
    static let clusterBesideTargetsMinimumWidth: CGFloat =
        clusterBesideTargetsMinimumPanelWidth + clusterBesideTargetsSpacing + trailingClusterWidth
    static let tallSplitMinimumPageWidth: CGFloat =
        dashboardColumnMinimumWidth / dashboardColumnFraction

    let breakpoint: Breakpoint
    let heroColumns: HeroColumns
    let showsTargetsPanel: Bool
    let detailsPlacement: DetailsPlacement
    let arrangesSplitAroundFold: Bool
    let mealRowMaximumWidth: CGFloat

    var showsMealsBesideDashboard: Bool {
        breakpoint == .wideRegular
    }

    init(
        isRegularWidth: Bool,
        isRegularHeight: Bool,
        pageSize: CGSize,
        isLargeText: Bool,
        hasTargets: Bool
    ) {
        let isWiderThanTall = pageSize.width > pageSize.height
        let fitsTallSplit = pageSize.width >= Self.tallSplitMinimumPageWidth
        let breakpoint: Breakpoint = if !isRegularWidth {
            .compact
        } else if isRegularHeight, isWiderThanTall || fitsTallSplit {
            .wideRegular
        } else {
            .narrowRegular
        }
        self.breakpoint = breakpoint
        showsTargetsPanel = breakpoint != .compact && hasTargets
        arrangesSplitAroundFold = breakpoint == .wideRegular && isWiderThanTall
        mealRowMaximumWidth = isRegularWidth && !isLargeText ? Self.readableMealRowWidth : .infinity

        guard breakpoint == .narrowRegular, !isLargeText else {
            heroColumns = .two
            detailsPlacement = .belowHero
            return
        }

        let contentWidth = pageSize.width - 2 * CalorynTheme.pagePadding
        heroColumns = contentWidth >= Self.threeColumnHeroWidth ? .three : .two
        detailsPlacement = contentWidth >= Self.clusterBesideTargetsMinimumWidth
            ? .besideEachOtherBelowHero
            : .belowHero
    }
}
