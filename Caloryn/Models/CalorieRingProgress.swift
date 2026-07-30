import Foundation

/// Where each of the calorie ring's arcs starts and stops, and whether it is
/// drawn at all.
///
/// The ring is three arcs over one track: the base goal, the stretch the
/// auto-adjust added, and the unfilled remainder of that stretch. Which span
/// each covers is a rule about progress, not about drawing, so it lives here;
/// the stroke width, the -90° rotation that puts zero at the top, the colours
/// and the animation stay in the view.
///
/// The progress figures are taken from `ActivityCalorieBudget`, which already
/// owns `displayedRingProgress` and `baseProgressEnd`. Nothing is re-derived
/// from calories here — a second derivation of one quantity is how the ring and
/// the number in its centre would come to disagree.
struct CalorieRingProgress: Equatable {
    /// Progress below this leaves the base arc undrawn.
    ///
    /// A rounded line cap paints a visible dot even at zero length, so an empty
    /// day would otherwise show a stray mark at the top of the ring.
    static let minimumVisibleProgress = 0.01

    /// One arc's span around the ring, as a fraction of a full turn.
    struct Arc: Equatable {
        let start: Double
        let end: Double
        let isVisible: Bool
    }

    /// How far the ring is filled, already clamped to at most a full turn by
    /// the budget.
    let animatedProgress: Double

    /// Where the base goal ends as a fraction of the adjusted target — the
    /// point the auto-adjust stretch begins at.
    let baseProgressEnd: Double

    /// Whether the auto-adjust added calories to today's target.
    let hasDynamicIncrease: Bool

    init(animatedProgress: Double, baseProgressEnd: Double, hasDynamicIncrease: Bool) {
        self.animatedProgress = animatedProgress
        self.baseProgressEnd = baseProgressEnd
        self.hasDynamicIncrease = hasDynamicIncrease
    }

    /// Reads the two progress figures the budget already derived rather than
    /// recomputing either from consumed calories.
    init(budget: ActivityCalorieBudget, animatedProgress: Double) {
        self.init(
            animatedProgress: animatedProgress,
            baseProgressEnd: budget.baseProgressEnd,
            hasDynamicIncrease: budget.hasDynamicIncrease
        )
    }

    /// The faint full-width track over the auto-adjust stretch, showing how much
    /// room the adjustment added before anything is eaten into it. It collapses
    /// to zero length when there is no adjustment, so the arc cannot flash on
    /// while it fades out.
    var dynamicTrack: Arc {
        Arc(
            start: baseProgressEnd,
            end: hasDynamicIncrease ? 1 : baseProgressEnd,
            isVisible: hasDynamicIncrease
        )
    }

    /// Progress against the base goal. Once an auto-adjust stretch exists this
    /// arc stops at the seam and `dynamicArc` carries on, so the two never
    /// overdraw each other.
    var baseArc: Arc {
        Arc(
            start: 0,
            end: hasDynamicIncrease ? min(animatedProgress, baseProgressEnd) : animatedProgress,
            isVisible: isBaseArcVisible
        )
    }

    /// Progress into the auto-adjust stretch, from the seam to wherever the fill
    /// has reached. Drawn only once it has actually passed the seam.
    var dynamicArc: Arc {
        let end = dynamicArcEnd
        return Arc(
            start: baseProgressEnd,
            end: end,
            isVisible: hasDynamicIncrease && end > baseProgressEnd
        )
    }

    /// Stated as "not below the threshold" rather than "at or above" it, so a
    /// progress that is not a number leaves the arc drawn instead of blanking
    /// the ring — the behaviour the view had before this rule moved.
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
