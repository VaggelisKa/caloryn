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
        case besideHero
    }

    static let heroDonutSize: CGFloat = 168
    static let heroColumnSpacing: CGFloat = 18
    static let heroFiguresColumnWidth: CGFloat = 200
    static let heroLegendColumnWidth: CGFloat = 220
    static let heroBesideTargetsSpacing: CGFloat = 32
    static let targetsBesideHeroMinimumPanelWidth: CGFloat = 320
    static let trailingClusterWidth: CGFloat = 240
    static let clusterBesideTargetsSpacing: CGFloat = 24
    static let clusterBesideTargetsMinimumPanelWidth: CGFloat = 256

    static let threeColumnHeroWidth: CGFloat =
        heroDonutSize + heroFiguresColumnWidth + heroLegendColumnWidth + 2 * heroColumnSpacing
    static let targetsBesideHeroMinimumWidth: CGFloat =
        threeColumnHeroWidth + heroBesideTargetsSpacing + targetsBesideHeroMinimumPanelWidth
    static let clusterBesideTargetsMinimumWidth: CGFloat =
        clusterBesideTargetsMinimumPanelWidth + clusterBesideTargetsSpacing + trailingClusterWidth

    let breakpoint: Breakpoint
    let heroColumns: HeroColumns
    let showsTargetsPanel: Bool
    let detailsPlacement: DetailsPlacement

    var showsMealsBesideDashboard: Bool {
        breakpoint == .wideRegular
    }

    init(
        isRegularWidth: Bool,
        isRegularHeight: Bool,
        contentWidth: CGFloat,
        isWiderThanTall: Bool,
        isLargeText: Bool,
        hasTargets: Bool
    ) {
        let breakpoint: Breakpoint = if !isRegularWidth {
            .compact
        } else if isRegularHeight, isWiderThanTall {
            .wideRegular
        } else {
            .narrowRegular
        }
        self.breakpoint = breakpoint
        showsTargetsPanel = breakpoint != .compact && hasTargets

        guard breakpoint == .narrowRegular, !isLargeText else {
            heroColumns = .two
            detailsPlacement = .belowHero
            return
        }

        heroColumns = contentWidth >= Self.threeColumnHeroWidth ? .three : .two
        detailsPlacement = if contentWidth >= Self.targetsBesideHeroMinimumWidth {
            .besideHero
        } else if contentWidth >= Self.clusterBesideTargetsMinimumWidth {
            .besideEachOtherBelowHero
        } else {
            .belowHero
        }
    }
}
