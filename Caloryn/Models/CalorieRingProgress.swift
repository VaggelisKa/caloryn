import Foundation

struct CalorieRingProgress: Equatable {
    static let minimumVisibleProgress = 0.01

    struct Arc: Equatable {
        let start: Double
        let end: Double
        let isVisible: Bool
    }

    let animatedProgress: Double

    let baseProgressEnd: Double

    let hasDynamicIncrease: Bool

    init(animatedProgress: Double, baseProgressEnd: Double, hasDynamicIncrease: Bool) {
        self.animatedProgress = animatedProgress
        self.baseProgressEnd = baseProgressEnd
        self.hasDynamicIncrease = hasDynamicIncrease
    }

    init(budget: ActivityCalorieBudget, animatedProgress: Double) {
        self.init(
            animatedProgress: animatedProgress,
            baseProgressEnd: budget.baseProgressEnd,
            hasDynamicIncrease: budget.hasDynamicIncrease
        )
    }

    var dynamicTrack: Arc {
        Arc(
            start: baseProgressEnd,
            end: hasDynamicIncrease ? 1 : baseProgressEnd,
            isVisible: hasDynamicIncrease
        )
    }

    var baseArc: Arc {
        Arc(
            start: 0,
            end: hasDynamicIncrease ? min(animatedProgress, baseProgressEnd) : animatedProgress,
            isVisible: isBaseArcVisible
        )
    }

    var dynamicArc: Arc {
        let end = dynamicArcEnd
        return Arc(
            start: baseProgressEnd,
            end: end,
            isVisible: hasDynamicIncrease && end > baseProgressEnd
        )
    }

    private var isBaseArcVisible: Bool {
        !(animatedProgress < Self.minimumVisibleProgress)
    }

    private var dynamicArcEnd: Double {
        guard hasDynamicIncrease, animatedProgress > baseProgressEnd else {
            return baseProgressEnd
        }
        return min(animatedProgress, 1)
    }
}
