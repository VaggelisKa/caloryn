import CoreGraphics
import Foundation

struct HistoryWeeklyConsistencyChart: Equatable {
    static let denseWeekThreshold = 10

    let axis: HistoryChartIndexAxis

    init(weekCount: Int) {
        axis = HistoryChartIndexAxis(slotCount: weekCount)
    }

    var weekCount: Int { axis.slotCount }

    var isDense: Bool { weekCount > Self.denseWeekThreshold }

    var barWidth: CGFloat { isDense ? 12 : 16 }

    var xAxisDomain: ClosedRange<Double> { axis.domain }

    var indices: [Double] { axis.indices }

    static func label(forOffset offset: Int) -> String {
        "W\(offset + 1)"
    }

    func label(forChartValue value: Double) -> String? {
        guard let slot = axis.slot(for: value) else { return nil }
        return Self.label(forOffset: slot)
    }

    static func accessibilityLabel(loggedDayCount: Int, totalDayCount: Int) -> String {
        "Weekly consistency of on-track days. \(loggedDayCount) of \(totalDayCount) days logged."
    }
}
