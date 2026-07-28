import CoreGraphics
import Foundation

/// The positional x-axis every History bar chart plots against.
///
/// History's charts do not plot dates: a point's x value is its offset in the
/// projected series, so a missing day still occupies a slot and the spacing
/// stays even. The three charts that do this each carried their own copy of the
/// domain padding and the "which slot did the reader touch" rounding; this owns
/// both once, and takes only the number of slots.
struct HistoryChartIndexAxis: Equatable {
    /// Chart-space padding at each end, so the first and last bars are drawn
    /// whole rather than clipped by the plot edge.
    static let edgePadding = 0.5

    /// A tap slot narrower than this is not reliably hittable, so slots stop
    /// shrinking here even when that makes neighbours overlap.
    static let minimumHitTargetWidth: CGFloat = 18

    let slotCount: Int

    init(slotCount: Int) {
        self.slotCount = max(slotCount, 0)
    }

    var indices: [Double] {
        (0 ..< slotCount).map(Double.init)
    }

    /// An empty series still needs a domain the chart can scale against.
    var domain: ClosedRange<Double> {
        guard slotCount > 0 else { return 0 ... 1 }
        return (0 - Self.edgePadding) ... (Double(slotCount - 1) + Self.edgePadding)
    }

    /// The slot a chart-space x value falls in, or `nil` outside the series.
    func slot(for value: Double) -> Int? {
        guard value.isFinite else { return nil }
        let rounded = value.rounded()
        guard rounded >= 0, rounded < Double(slotCount) else { return nil }
        return Int(rounded)
    }

    /// Width of one tap target when the plot is `plotWidth` wide.
    func hitTargetWidth(plotWidth: CGFloat) -> CGFloat {
        let slots = CGFloat(max(slotCount, 1))
        return max(plotWidth / slots, Self.minimumHitTargetWidth)
    }

    /// The x offset inside the plot, or `nil` when the touch missed the plot.
    func plotLocalX(for location: CGPoint, in plotRect: CGRect) -> CGFloat? {
        guard plotRect.contains(location) else { return nil }
        return location.x - plotRect.minX
    }
}
