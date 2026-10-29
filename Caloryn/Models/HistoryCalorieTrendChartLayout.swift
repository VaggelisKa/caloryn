import CoreGraphics
import Foundation

struct HistoryCalorieTrendChartLayout: Equatable {
    enum Surface: Equatable {
        case card
        case detail
    }

    enum BarEmphasis: Equatable {
        case normal
        case selected
        /// Another bar is the selection. It still keeps its status colour: status is told by
        /// lightness alone, so a dimmed ink "over" bar would read as an "under" one.
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

    var usesDenseAxisLabels: Bool {
        range == .twoWeeks || range == .quarter
    }

    var xAxisDomain: ClosedRange<Double> {
        axis.domain
    }

    func hitTargetWidth(plotWidth: CGFloat) -> CGFloat {
        axis.hitTargetWidth(plotWidth: plotWidth)
    }

    func selectedSlot(chartValue: Double?) -> Int? {
        guard let chartValue else { return nil }
        return axis.slot(for: chartValue)
    }

    static func barEmphasis(pointID: String, selectedPointID: String?) -> BarEmphasis {
        guard let selectedPointID else { return .normal }
        return selectedPointID == pointID ? .selected : .muted
    }
}
