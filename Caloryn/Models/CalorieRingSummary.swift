import Foundation

/// What the calorie ring says: the figure in its centre, the auto-adjust cue
/// beneath it, and how VoiceOver reads the whole thing.
///
/// Every number here is taken from `ActivityCalorieBudget`, which already owns
/// remaining, over, rounded-consumed and the adjusted target. None of them is
/// recomputed — the ring's colour, its caption and its number all follow the
/// budget's single over/under decision, so they cannot contradict each other.
struct CalorieRingSummary: Equatable {
    /// The one line of auto-adjust status the ring has room for.
    ///
    /// Loading wins over a result: while Apple Health is still being read, the
    /// figures on screen are the previous day's answer and must not be
    /// announced as this one's.
    enum Cue: Equatable {
        case none
        /// Activity is still being read.
        case updating
        /// The auto-adjust added calories to today's target.
        case increase(Int)
        /// The auto-adjust took calories off today's target.
        case reduction(Int)

        /// The cue as it is shown. A reduction carries its own minus sign,
        /// since the adjustment it reports is negative.
        var text: String? {
            switch self {
            case .none:
                nil
            case .updating:
                "updating"
            case .increase(let increase):
                "+\(increase) dynamic"
            case .reduction(let adjustment):
                "\(adjustment) dynamic"
            }
        }

        /// "dynamic" next to a signed number is too terse to read aloud, so the
        /// two results spell themselves out. The loading cue keeps the
        /// `ProgressView`'s own announcement.
        var accessibilityLabel: String? {
            switch self {
            case .none, .updating:
                nil
            case .increase(let increase):
                "\(increase) calorie auto-adjust increase"
            case .reduction(let adjustment):
                "\(abs(adjustment)) calorie auto-adjust reduction"
            }
        }
    }

    let isOver: Bool
    let remaining: Int
    let overAmount: Int
    let roundedConsumed: Int
    let adjustedTarget: Int
    let dynamicIncrease: Int
    let dynamicAdjustment: Int
    let hasDynamicIncrease: Bool
    let hasDynamicReduction: Bool
    let isActivityLoading: Bool

    init(
        isOver: Bool,
        remaining: Int,
        overAmount: Int,
        roundedConsumed: Int,
        adjustedTarget: Int,
        dynamicIncrease: Int = 0,
        dynamicAdjustment: Int = 0,
        hasDynamicIncrease: Bool = false,
        hasDynamicReduction: Bool = false,
        isActivityLoading: Bool = false
    ) {
        self.isOver = isOver
        self.remaining = remaining
        self.overAmount = overAmount
        self.roundedConsumed = roundedConsumed
        self.adjustedTarget = adjustedTarget
        self.dynamicIncrease = dynamicIncrease
        self.dynamicAdjustment = dynamicAdjustment
        self.hasDynamicIncrease = hasDynamicIncrease
        self.hasDynamicReduction = hasDynamicReduction
        self.isActivityLoading = isActivityLoading
    }

    /// Takes the budget's answers as given rather than deriving a second set.
    init(budget: ActivityCalorieBudget) {
        self.init(
            isOver: budget.isOver,
            remaining: budget.remaining,
            overAmount: budget.overAmount,
            roundedConsumed: budget.roundedConsumed,
            adjustedTarget: budget.adjustedTarget,
            dynamicIncrease: budget.dynamicIncrease,
            dynamicAdjustment: budget.dynamicAdjustment,
            hasDynamicIncrease: budget.hasDynamicIncrease,
            hasDynamicReduction: budget.hasDynamicReduction,
            isActivityLoading: budget.isActivityLoading
        )
    }

    // MARK: - Centre

    /// The same accent the Nutrition Details sheet uses, from the same
    /// over/under decision, so the ring and the sheet always agree. A semantic
    /// case: mapping it onto `CalorynTheme` is the view's business.
    var accent: NutritionDetailsSummary.CalorieAccent {
        NutritionDetailsSummary.calorieAccent(isOver: isOver)
    }

    /// The large figure: how far over when over, how much is left otherwise.
    var centerValue: Int {
        isOver ? overAmount : remaining
    }

    var centerCaption: String {
        isOver ? "over" : "remaining"
    }

    var eatenText: String {
        "\(roundedConsumed) eaten"
    }

    // MARK: - Auto-adjust cue

    var cue: Cue {
        if isActivityLoading {
            return .updating
        }
        if hasDynamicIncrease {
            return .increase(dynamicIncrease)
        }
        if hasDynamicReduction {
            return .reduction(dynamicAdjustment)
        }
        return .none
    }

    // MARK: - VoiceOver

    /// The ring is read as one element, so the label has to carry everything the
    /// centre shows — a caption alone would leave the number unexplained.
    var accessibilityLabel: String {
        let activityDescription = hasDynamicIncrease
            ? ", includes \(dynamicIncrease) calorie auto-adjust increase"
            : ""

        if isOver {
            return "Calorie ring, \(roundedConsumed) eaten, \(overAmount) calories over a \(adjustedTarget) calorie goal\(activityDescription)"
        }

        return "Calorie ring, \(remaining) remaining of \(adjustedTarget) calories, \(roundedConsumed) eaten\(activityDescription)"
    }

    var accessibilityValue: String {
        if isOver {
            return "\(roundedConsumed) eaten, \(overAmount) calories over target of \(adjustedTarget)"
        }

        return "\(roundedConsumed) eaten, \(remaining) remaining of \(adjustedTarget)"
    }

    /// Silent when the ring is decoration: a hint that promises a tap does
    /// nothing is worse than no hint.
    static func accessibilityHint(isInteractive: Bool) -> String {
        isInteractive ? "Tap or long press to show nutrition details." : ""
    }
}
