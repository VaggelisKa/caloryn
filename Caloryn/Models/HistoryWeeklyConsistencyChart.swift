import CoreGraphics
import Foundation

/// How the weekly-consistency bar chart is laid out and labelled.
///
/// Takes the number of weeks — the only fact the layout turns on — rather than
/// the rollups themselves. Weeks are labelled by position, not by date, so a
/// week with nothing logged still holds its place in the sequence.
struct HistoryWeeklyConsistencyChart: Equatable {
    /// Past this many bars the labels no longer fit at the normal size, so both
    /// the bar and its label shrink together.
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

    /// Weeks are numbered from the start of the range, so W1 is the oldest.
    static func label(forOffset offset: Int) -> String {
        "W\(offset + 1)"
    }

    /// The label for a chart-space x value, or `nil` outside the series.
    func label(forChartValue value: Double) -> String? {
        guard let slot = axis.slot(for: value) else { return nil }
        return Self.label(forOffset: slot)
    }

    static func accessibilityLabel(loggedDayCount: Int, totalDayCount: Int) -> String {
        "Weekly consistency of on-track days. \(loggedDayCount) of \(totalDayCount) days logged."
    }
}
