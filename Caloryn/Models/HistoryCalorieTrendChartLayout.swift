import CoreGraphics
import Foundation

struct HistoryCalorieTrendChartLayout: Equatable {
    let range: HistoryRange
    let axis: HistoryChartIndexAxis

    init(range: HistoryRange, pointCount: Int) {
        self.range = range
        axis = HistoryChartIndexAxis(slotCount: pointCount)
    }

    var barWidth: CGFloat {
        range == .week ? 10 : 6
    }

    var chartHeight: CGFloat {
        range == .week ? 160 : 180
    }

    var usesDenseAxisLabels: Bool {
        range == .twoWeeks || range == .quarter
    }

    var xAxisDomain: ClosedRange<Double> {
        axis.domain
    }
}
