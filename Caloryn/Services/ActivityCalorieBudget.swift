import Foundation

struct ActivityCalorieBudget: Equatable {
    let consumed: Double
    let baseTarget: Int
    let activeEnergyKcal: Double
    let isActivityAdjustmentEnabled: Bool
    let isActivityLoading: Bool
    let activityMessage: String?

    static var activeEnergyCreditPolicyText: String {
        "Apple Health Active Energy"
    }

    static var activeEnergyCreditShortText: String {
        "Active Energy credit"
    }

    var activityCredit: Int {
        Self.creditedCalories(from: activeEnergyKcal)
    }

    var adjustedTarget: Int {
        guard isActivityAdjustmentEnabled else { return baseTarget }
        return baseTarget + activityCredit
    }

    var roundedConsumed: Int {
        Int(consumed.rounded())
    }

    var remaining: Int {
        max(0, adjustedTarget - roundedConsumed)
    }

    var overAmount: Int {
        max(0, roundedConsumed - adjustedTarget)
    }

    var isOver: Bool {
        consumed > Double(adjustedTarget)
    }

    var hasActivityCredit: Bool {
        isActivityAdjustmentEnabled && activityCredit > 0 && adjustedTarget > baseTarget
    }

    var progress: Double {
        guard adjustedTarget > 0 else { return 0 }
        return min(consumed / Double(adjustedTarget), 1.5)
    }

    var displayedRingProgress: Double {
        min(progress, 1.0)
    }

    var baseProgressEnd: Double {
        guard adjustedTarget > 0 else { return 1 }
        return min(max(Double(baseTarget) / Double(adjustedTarget), 0), 1)
    }

    private static func creditedCalories(from activeEnergyKcal: Double) -> Int {
        max(0, Int(activeEnergyKcal.rounded()))
    }
}
