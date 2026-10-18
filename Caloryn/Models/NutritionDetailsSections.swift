import Foundation

struct NutritionDetailsSections: Equatable {
    struct TargetRow: Identifiable, Equatable {
        let nutrient: TrackedNutrient
        let name: String
        let valueText: String
        let targetText: String
        let overText: String?
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
    let amounts: [AmountRow]
    let breakdowns: [Breakdown]

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

    static func foodAmountText(summary: NutritionDetailsSummary, locale: Locale = .current) -> String {
        let grams = summary.totalPortionGrams.spacedMacroFormatted(locale: locale)
        return "\(summary.loggedItemCount) \(summary.loggedItemsUnitText), \(grams) of food"
    }

    static let varietyGoal = 5

    static func produceCountText(_ count: Int) -> String {
        switch count {
        case ..<1: "none yet"
        case 1: "1 kind today"
        default: "\(count) kinds today"
        }
    }

    static func produceRemainingText(_ count: Int) -> String? {
        let remaining = varietyGoal - max(0, count)
        return remaining > 0 ? "\(remaining) more for variety" : nil
    }

    static func nutriscoreGradedText(graded: Int, total: Int) -> String {
        "\(graded) of \(total) \(total == 1 ? "item" : "items") graded"
    }
}
