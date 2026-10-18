import Foundation

/// What the Today hero prints beside its donut: the big number, the caption under it, the
/// "eaten" line and the legend's values.
///
/// Takes the two summaries the hero is drawn from rather than the budget again, so the
/// figure, the caption, the ring and VoiceOver all follow one over/under decision —
/// `ActivityCalorieBudget`'s, handed through `CalorieRingSummary` and `CalorieDonutSummary`.
/// Nothing here re-derives remaining, over or eaten.
///
/// Figures are grouped for the reader's locale ("2,000", "2.000"), the way SwiftUI's own
/// `Text` interpolation of the big number groups them, so the caption and the number beside
/// it agree. `locale` exists for tests.
struct TodayHeroSummary: Equatable {
    let ring: CalorieRingSummary
    let donut: CalorieDonutSummary
    let locale: Locale

    init(ring: CalorieRingSummary, donut: CalorieDonutSummary, locale: Locale = .current) {
        self.ring = ring
        self.donut = donut
        self.locale = locale
    }

    /// Feeds both summaries from the same budget, so the donut and the number cannot
    /// disagree about which side of the budget the day is on.
    init(mealTotals: [MealType: Double], budget: ActivityCalorieBudget, locale: Locale = .current) {
        self.init(
            ring: CalorieRingSummary(budget: budget),
            donut: CalorieDonutSummary(mealTotals: mealTotals, budget: budget),
            locale: locale
        )
    }

    var isOver: Bool {
        ring.isOver
    }

    /// The big number: kcal left, or kcal over once past the budget.
    var headline: Int {
        ring.centerValue
    }

    var headlineText: String {
        grouped(headline)
    }

    /// "kcal left of 2,000", or "kcal over".
    var caption: String {
        isOver ? "kcal over" : "kcal left of \(grouped(ring.adjustedTarget))"
    }

    /// "963 of 2,000 eaten" — the same sentence on both sides of the budget, so the line
    /// never has to describe the ring's colours (the overshoot is ink: dark in light mode,
    /// light in dark).
    var eatenLine: String {
        "\(grouped(ring.roundedConsumed)) of \(grouped(ring.adjustedTarget)) eaten"
    }

    /// A legend row's figure: the meal's own kcal, or "not yet" for a meal nothing is
    /// logged in. A meal logged at 0 kcal (black coffee) is logged, so it reads "0".
    func legendValue(for entry: CalorieDonutSummary.LegendEntry) -> String {
        entry.isLogged ? grouped(entry.kcal) : "not yet"
    }

    /// A legend row's name: the meal, or "Over" for the overshoot row.
    func legendName(for entry: CalorieDonutSummary.LegendEntry) -> String {
        entry.meal?.displayName ?? "Over"
    }

    /// kcal per meal for the donut. Only meals with at least one entry get a key — that is
    /// how `CalorieDonutSummary` tells "logged at 0 kcal" from "not yet" — and every snack
    /// slot lands on the one `.snack` key.
    static func mealTotals<Entry>(
        _ entries: [Entry],
        mealType: KeyPath<Entry, MealType>,
        calories: KeyPath<Entry, Double>
    ) -> [MealType: Double] {
        entries.reduce(into: [MealType: Double]()) { totals, entry in
            totals[entry[keyPath: mealType], default: 0] += entry[keyPath: calories]
        }
    }

    private func grouped(_ value: Int) -> String {
        value.formatted(.number.locale(locale))
    }
}
