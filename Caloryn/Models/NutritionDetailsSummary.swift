import Foundation

/// Every rule the Nutrition Details sheet applies to a day's log.
///
/// The sheet's totals fall out of two facts per entry — what it contained and
/// how much of it there was — so those are what this takes, rather than the log
/// entries themselves. The calorie figures are deliberately absent: the day's
/// `ActivityCalorieBudget` already owns remaining, over and rounded-consumed,
/// and deriving them a second time here is exactly how two copies drift apart.
struct NutritionDetailsSummary: Equatable {
    /// The facts about one logged entry that the totals depend on.
    struct Entry: Equatable {
        let nutrition: NutritionValues
        let portionGrams: Double

        init(nutrition: NutritionValues, portionGrams: Double) {
            self.nutrition = nutrition
            self.portionGrams = portionGrams
        }
    }

    /// Which treatment the calorie figures take.
    ///
    /// A semantic case rather than a `Color`: the decision is a rule and belongs
    /// here, while the mapping onto `CalorynTheme` stays the view's business.
    enum CalorieAccent: Equatable {
        case withinBudget
        case overBudget
    }

    /// How loudly the auto-adjust status line reads.
    enum StatusNoticeStyle: Equatable {
        /// Auto-adjust cannot run at all.
        case warning
        /// Auto-adjust is on and still learning.
        case informational
        /// Nothing is wrong; the line is a plain remark.
        case neutral
    }

    let totalNutrition: NutritionValues
    let totalPortionGrams: Double
    let loggedItemCount: Int

    init(entries: [Entry]) {
        totalNutrition = entries.reduce(.zero) { $0 + $1.nutrition }
        totalPortionGrams = entries.reduce(0) { $0 + $1.portionGrams }
        loggedItemCount = entries.count
    }

    var totalCalories: Double {
        totalNutrition.calories
    }

    var totalPortionGramsText: String {
        totalPortionGrams.macroFormatted
    }

    /// "1 item", but "0 items" and "2 items".
    var loggedItemsUnitText: String {
        loggedItemCount == 1 ? "item" : "items"
    }

    // MARK: - Calories

    /// Taken from the budget's own over/under decision, so the colour, the label
    /// and the number can never disagree.
    static func calorieAccent(isOver: Bool) -> CalorieAccent {
        isOver ? .overBudget : .withinBudget
    }

    static func calorieSummaryLabel(isOver: Bool) -> String {
        isOver ? "Over" : "Remaining"
    }

    /// How far along a progress bar runs, clamped so neither a missing target
    /// nor an overshoot can draw outside the track.
    static func progressFraction(current: Double, target: Double) -> Double {
        guard target > 0 else { return 0 }
        return min(max(current / target, 0), 1)
    }

    // MARK: - Auto-adjusted calories

    /// Whether the auto-adjust card appears at all.
    ///
    /// Not simply "is the mode on": a day that was recorded with activity, or
    /// that has something to say about why activity is missing, still has to
    /// explain itself after the mode has been turned back off.
    static func showsDynamicTDEE(
        isDynamicModeRequested: Bool,
        activeEnergyKcal: Double,
        dynamicAdjustment: Int,
        hasActivityMessage: Bool
    ) -> Bool {
        isDynamicModeRequested
            || activeEnergyKcal > 0
            || dynamicAdjustment != 0
            || hasActivityMessage
    }

    /// A dash until enough valid days exist for a baseline to mean anything.
    ///
    /// Both this and `activeEnergyText` come from Apple Health, so `Int(_:)`
    /// cannot be used to round them: it terminates the process on a NaN, an
    /// infinity or anything past `Int.max` rather than throwing.
    /// `truncatedSafely`, via `Double.kcalFormatted`, renders those as text
    /// instead — the same reasoning `SettingsCalorieEstimate` already applies to
    /// the identical pair of figures in Settings.
    static func baselineText(activityBaselineKcal: Double?) -> String {
        guard let activityBaselineKcal else {
            return "-"
        }

        return activityBaselineKcal.rounded().kcalFormatted
    }

    /// Today's Active Energy, as read from Apple Health.
    static func activeEnergyText(activeEnergyKcal: Double) -> String {
        activeEnergyKcal.rounded().kcalFormatted
    }

    /// Always signed, so "+180 kcal" and "-90 kcal" read as the change they are
    /// rather than as a target.
    static func dynamicAdjustmentText(_ adjustment: Int) -> String {
        if adjustment > 0 {
            return "+\(adjustment.kcalFormatted)"
        }
        if adjustment < 0 {
            return "-\(abs(adjustment).kcalFormatted)"
        }
        return "0 kcal"
    }

    /// A reduction is stated plainly; anything else is the feature working.
    static func isDynamicAdjustmentMuted(_ adjustment: Int) -> Bool {
        adjustment < 0
    }

    static func statusNoticeStyle(for status: ActivityCalorieBudget.DynamicStatus) -> StatusNoticeStyle {
        switch status {
        case .unavailable:
            .warning
        case .learning:
            .informational
        case .staticEstimate, .ready:
            .neutral
        }
    }
}
