import Foundation

struct HistoryChartIndexAxis: Equatable {
    static let edgePadding = 0.5

    let slotCount: Int

    init(slotCount: Int) {
        self.slotCount = max(slotCount, 0)
    }

    var domain: ClosedRange<Double> {
        guard slotCount > 0 else { return 0 ... 1 }
        return (0 - Self.edgePadding) ... (Double(slotCount - 1) + Self.edgePadding)
    }
}
