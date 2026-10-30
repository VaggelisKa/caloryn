import Foundation

nonisolated struct CalorieBudget: Equatable {
    let consumed: Double
    let target: Int
    let isManualOverride: Bool

    init(consumed: Double, target: Int, isManualOverride: Bool = false) {
        self.consumed = consumed
        self.target = CalorieDomain.clamped(target)
        self.isManualOverride = isManualOverride
    }

    var roundedConsumed: Int {
        consumed.roundedCalories
    }

    var remaining: Int {
        max(0, target - roundedConsumed)
    }

    var overAmount: Int {
        max(0, roundedConsumed - target)
    }

    var isOver: Bool {
        roundedConsumed > target
    }
}
