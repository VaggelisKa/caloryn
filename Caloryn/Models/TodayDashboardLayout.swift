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

    static let threeColumnHeroWidth: CGFloat = 624
    static let targetsBesideHeroMinimumWidth: CGFloat = 976
    static let clusterBesideTargetsMinimumWidth: CGFloat = 520

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
        detailsPlacement = if heroColumns == .three, contentWidth >= Self.targetsBesideHeroMinimumWidth {
            .besideHero
        } else if contentWidth >= Self.clusterBesideTargetsMinimumWidth {
            .besideEachOtherBelowHero
        } else {
            .belowHero
        }
    }
}
