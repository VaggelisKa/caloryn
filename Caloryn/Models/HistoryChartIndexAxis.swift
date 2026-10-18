import CoreGraphics
import Foundation

struct HistoryChartIndexAxis: Equatable {
    static let edgePadding = 0.5

    static let minimumHitTargetWidth: CGFloat = 18

    let slotCount: Int

    init(slotCount: Int) {
        self.slotCount = max(slotCount, 0)
    }

    var indices: [Double] {
        (0 ..< slotCount).map(Double.init)
    }

    var domain: ClosedRange<Double> {
        guard slotCount > 0 else { return 0 ... 1 }
        return (0 - Self.edgePadding) ... (Double(slotCount - 1) + Self.edgePadding)
    }

    func slot(for value: Double) -> Int? {
        guard value.isFinite else { return nil }
        let rounded = value.rounded()
        guard rounded >= 0, rounded < Double(slotCount) else { return nil }
        return Int(rounded)
    }

    func hitTargetWidth(plotWidth: CGFloat) -> CGFloat {
        let slots = CGFloat(max(slotCount, 1))
        return max(plotWidth / slots, Self.minimumHitTargetWidth)
    }

    func plotLocalX(for location: CGPoint, in plotRect: CGRect) -> CGFloat? {
        guard plotRect.contains(location) else { return nil }
        return location.x - plotRect.minX
    }
}
