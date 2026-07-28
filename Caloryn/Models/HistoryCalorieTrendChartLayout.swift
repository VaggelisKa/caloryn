import CoreGraphics
import Foundation

/// How the calorie-trend bar chart is sized and which bar is emphasised.
///
/// The same series is drawn twice — compactly on the History card and larger in
/// the drill-down — and the only thing that varies is bar width and height. Both
/// decisions turn on the range (the 7-day range plots seven bars, the others up
/// to thirty) and on which of the two surfaces is asking, so both facts are taken
/// and neither surface computes its own.
struct HistoryCalorieTrendChartLayout: Equatable {
    enum Surface: Equatable {
        /// The summary card on the History screen.
        case card
        /// The pushed drill-down, which is taller and tappable.
        case detail
    }

    /// How prominently one bar is drawn, given what is selected. The view maps
    /// these to a tint; no colour is decided here.
    enum BarEmphasis: Equatable {
        /// Nothing is selected, so every bar reads at full strength.
        case normal
        /// This bar is the selection.
        case selected
        /// Another bar is the selection, so this one recedes.
        case muted
    }

    let range: HistoryRange
    let surface: Surface
    let axis: HistoryChartIndexAxis

    init(range: HistoryRange, surface: Surface, pointCount: Int) {
        self.range = range
        self.surface = surface
        axis = HistoryChartIndexAxis(slotCount: pointCount)
    }

    /// Only the 7-day range has room for wide bars; every longer range plots at
    /// least fourteen and has to fit them in the same width.
    var barWidth: CGFloat {
        switch surface {
        case .card:
            range == .week ? 10 : 6
        case .detail:
            range == .week ? 14 : 10
        }
    }

    var chartHeight: CGFloat {
        switch surface {
        case .card:
            range == .week ? 160 : 180
        case .detail:
            range == .week ? 220 : 240
        }
    }

    var xAxisDomain: ClosedRange<Double> {
        axis.domain
    }

    func hitTargetWidth(plotWidth: CGFloat) -> CGFloat {
        axis.hitTargetWidth(plotWidth: plotWidth)
    }

    /// The slot a tap landed on, or `nil` when it missed the plot entirely.
    ///
    /// Takes the already-resolved chart-space x value rather than the chart
    /// proxy, so the containment and rounding rules are reachable without a
    /// rendered chart.
    func selectedSlot(chartValue: Double?) -> Int? {
        guard let chartValue else { return nil }
        return axis.slot(for: chartValue)
    }

    /// Selecting a bar dims its neighbours; selecting nothing dims none of them.
    static func barEmphasis(pointID: String, selectedPointID: String?) -> BarEmphasis {
        guard let selectedPointID else { return .normal }
        return selectedPointID == pointID ? .selected : .muted
    }
}
