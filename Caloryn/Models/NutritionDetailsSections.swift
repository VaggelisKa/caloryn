import Foundation

/// How the Nutrition Details sheet sorts a day's figures into its sections: the nutrients
/// with a target ("Against your targets", one bar each), everything else as plain amounts
/// ("Also in today's food"), and the sub-nutrient breakdowns that have data.
///
/// Takes the metrics and populated groups the sheet already builds (`TrackedNutrientMetric`,
/// `NutrientDetailGroup.populatedGroups`) and moves nothing out of them: which nutrients have
/// a target, which lines exist and how each figure is formatted stay those types' rules.
/// What is decided here is only where each one is shown and in what words.
struct NutritionDetailsSections: Equatable {
    struct TargetRow: Identifiable, Equatable {
        let nutrient: TrackedNutrient
        let name: String
        /// The amount eaten, "46 g".
        let valueText: String
        /// "of 150 g min" — the goal kind stays on the line, so a maximum does not read as a
        /// target to reach.
        let targetText: String
        /// "14.8 g over" once a maximum is passed, nil otherwise. The bar is ink and stops at
        /// full either way, so the overshoot has to be said, as the calorie line says it.
        let overText: String?
        /// How far along the bar runs, clamped to 0...1.
        let progress: Double
        let accessibilityLabel: String

        var id: TrackedNutrient { nutrient }

        var isOverMaximum: Bool { overText != nil }
    }

    struct AmountRow: Identifiable, Equatable {
        let id: String
        let label: String
        let valueText: String
    }

    struct Breakdown: Identifiable, Equatable {
        let id: String
        let title: String
        let rows: [AmountRow]
    }

    let targets: [TargetRow]
    /// Tracked nutrients without a target, in `TrackedNutrient` order, then salt.
    let amounts: [AmountRow]
    /// Protein, carb and fat breakdowns, each only when it has a line.
    let breakdowns: [Breakdown]

    /// Every figure is written in `locale`, which exists for tests.
    init(
        metrics: [TrackedNutrientMetric],
        details: [PopulatedNutrientDetailGroup],
        locale: Locale = .current
    ) {
        var targets: [TargetRow] = []
        var amounts: [AmountRow] = []

        for metric in metrics {
            if let target = metric.target, target > 0,
               let formattedTarget = metric.formattedTarget(locale: locale) {
                let overText = Self.overMaximumText(
                    value: metric.value,
                    target: target,
                    goalKind: metric.goalKind,
                    unit: metric.nutrient.unit,
                    locale: locale
                )
                targets.append(
                    TargetRow(
                        nutrient: metric.nutrient,
                        name: metric.nutrient.displayName.sentenceCased,
                        valueText: metric.formattedValue(locale: locale),
                        targetText: "of \(formattedTarget)",
                        overText: overText,
                        progress: NutritionDetailsSummary.progressFraction(current: metric.value, target: target),
                        accessibilityLabel: overText.map { "\(metric.accessibilityLabel), \($0)" }
                            ?? metric.accessibilityLabel
                    )
                )
            } else {
                amounts.append(
                    AmountRow(
                        id: metric.nutrient.rawValue,
                        label: metric.nutrient.displayName.sentenceCased,
                        valueText: metric.formattedValue(locale: locale)
                    )
                )
            }
        }

        var breakdowns: [Breakdown] = []
        for populated in details {
            let rows = populated.items.map {
                AmountRow(id: $0.id, label: $0.label, valueText: $0.spacedFormattedValue(locale: locale))
            }
            switch populated.group {
            case .salt:
                // A single line, so it joins the amounts rather than heading a section of one.
                amounts.append(contentsOf: rows)
            case .protein:
                breakdowns.append(Breakdown(id: populated.id, title: "Protein breakdown", rows: rows))
            case .carbs:
                breakdowns.append(Breakdown(id: populated.id, title: "Carb breakdown", rows: rows))
            case .fat:
                breakdowns.append(Breakdown(id: populated.id, title: "Fat breakdown", rows: rows))
            }
        }

        self.targets = targets
        self.amounts = amounts
        self.breakdowns = breakdowns
    }

    // MARK: - Calories

    /// The line beside the big number: "of 2,000 kcal", and how far over once past it —
    /// the number itself is ink either way, so the overshoot has to be said.
    static func calorieTargetText(
        adjustedTarget: Int,
        isOver: Bool,
        overAmount: Int,
        locale: Locale = .current
    ) -> String {
        let target = "of \(adjustedTarget.formatted(.number.locale(locale))) kcal"
        guard isOver else { return target }
        return "\(target), \(overAmount.formatted(.number.locale(locale))) over"
    }

    /// "14.8 g over" when a maximum has been passed. Only a maximum: going past a minimum is
    /// the point, and the sheet has never flagged a plain goal. An overshoot too small to show
    /// in the figures ("20 g of 20 g max") gets no words.
    static func overMaximumText(
        value: Double,
        target: Double,
        goalKind: NutrientGoalKind?,
        unit: TrackedNutrientUnit,
        locale: Locale = .current
    ) -> String? {
        guard goalKind == .maximum, value > target else { return nil }
        let over = unit.formatted(value - target, locale: locale)
        guard over != unit.formatted(0, locale: locale) else { return nil }
        return "\(over) over"
    }

    /// "7 items, 760 g of food", "11 items, 1.450 g of food".
    static func foodAmountText(summary: NutritionDetailsSummary, locale: Locale = .current) -> String {
        let grams = summary.totalPortionGrams.spacedMacroFormatted(locale: locale)
        return "\(summary.loggedItemCount) \(summary.loggedItemsUnitText), \(grams) of food"
    }

    // MARK: - Fruit and veg

    /// Kinds of fruit and veg a day is nudged towards. "Five a day" is the familiar figure,
    /// and the sheet only ever counts it down — it never marks a day as failed.
    static let varietyGoal = 5

    /// "3 kinds today", or "none yet".
    static func produceCountText(_ count: Int) -> String {
        switch count {
        case ..<1: "none yet"
        case 1: "1 kind today"
        default: "\(count) kinds today"
        }
    }

    /// The dashed chip after the logged kinds: "2 more for variety", or nothing once the
    /// goal is reached.
    static func produceRemainingText(_ count: Int) -> String? {
        let remaining = varietyGoal - max(0, count)
        return remaining > 0 ? "\(remaining) more for variety" : nil
    }

    // MARK: - Nutri-Score

    /// "6 of 7 items graded". The rest had no grade, which is not the same as a bad one.
    static func nutriscoreGradedText(graded: Int, total: Int) -> String {
        "\(graded) of \(total) \(total == 1 ? "item" : "items") graded"
    }
}
