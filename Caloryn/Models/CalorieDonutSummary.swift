import Foundation

/// What the Today donut draws: one sector per meal eaten, then either what is left of the
/// budget or what went past it, plus the legend beside it.
///
/// Takes the facts the rule needs — each meal's kcal, the budget and the budget's own
/// over/under decision — and nothing else. The over/under decision is taken as given rather
/// than re-derived here, so the donut cannot disagree with `CalorieRingSummary`, the caption
/// or Nutrition Details about which side of the budget a day is on.
///
/// The ring's whole is the budget while under it, and everything eaten once over it:
///
/// - **Under**: each meal's sector is its kcal, and one `.remaining` sector holds the rest
///   of the budget. The ring reads as a plate filling up.
/// - **Over**: the ring is everything eaten. The amount past the budget is its own final
///   `.over` sector (eaten − budget), and the meals share the budget in proportion to what
///   each contributed — so every logged meal stays visible and keeps its relative size,
///   and the ink slice is exactly the overshoot's share of the day.
///
///   The `PlateOver` board draws the meals differently: at their full share, with the
///   overshoot cut out of the last meal. That only works in the board's own order (dinner
///   last); in `MealType.sortOrder` the last meal is snack, usually smaller than the
///   overshoot, which would vanish from the ring while the legend still lists it. The
///   ink slice is the same size either way. Recorded in `docs/design/plate-market.md`.
///
/// Sector `kcal` is an angle value for the chart, not a figure to print: when over, a meal
/// sector is scaled down. Print the `legend`, which always carries each meal's own total.
struct CalorieDonutSummary: Equatable {
    enum SectorKind: Hashable {
        case meal(MealType)
        case remaining
        case over
    }

    struct Sector: Equatable, Identifiable {
        let kind: SectorKind
        /// The sector's share of the ring, in kcal. Always finite and positive: a sector
        /// that would be empty is omitted rather than emitted at zero.
        let kcal: Double

        var id: SectorKind { kind }
    }

    struct LegendEntry: Equatable, Identifiable {
        enum Key: Hashable {
            case meal(MealType)
            /// The bold "Over" row with an ink key, last, only when the ring has an over sector.
            case over
        }

        let key: Key
        /// The meal's own total, rounded and never scaled; for `.over`, `overKcal`.
        let kcal: Int
        /// False draws a hollow key and "not yet". Always true for `.over`.
        let isLogged: Bool

        var id: Key { key }

        /// The meal this row is for; nil on the "Over" row.
        var meal: MealType? {
            if case .meal(let meal) = key { meal } else { nil }
        }

        init(meal: MealType, kcal: Int, isLogged: Bool) {
            self.key = .meal(meal)
            self.kcal = kcal
            self.isLogged = isLogged
        }

        /// The "Over" row.
        static func over(kcal: Int) -> LegendEntry {
            LegendEntry(key: .over, kcal: kcal, isLogged: true)
        }

        private init(key: Key, kcal: Int, isLogged: Bool) {
            self.key = key
            self.kcal = kcal
            self.isLogged = isLogged
        }
    }

    /// In `MealType.sortOrder`, then `.remaining` or `.over`. Empty only when there is
    /// nothing to draw at all (no budget and nothing eaten); the view draws a bare track.
    let sectors: [Sector]
    /// Every meal, in `MealType.sortOrder`, logged or not; then, when the ring has an over
    /// sector, one `.over` row carrying `overKcal`. Render it as it comes.
    let legend: [LegendEntry]
    let isOver: Bool
    let eatenKcal: Int
    let budgetKcal: Int
    /// What is left of the budget; 0 when over.
    let remainingKcal: Int
    /// How far past the budget; 0 when not over.
    let overKcal: Int

    /// - Parameters:
    ///   - mealTotals: kcal eaten per meal. A meal counts as logged when it has a key, so
    ///     pass only meals with entries: a meal logged at 0 kcal (water, black coffee) is
    ///     logged, but draws no sector. Non-finite or negative totals count as 0.
    ///     Snack slots share one key: sum them before passing.
    ///   - budget: today's budget — `ActivityCalorieBudget.adjustedTarget`. A non-finite,
    ///     negative or zero budget counts as 0, so everything eaten is past it.
    ///   - isOver: the budget's own over/under decision (`ActivityCalorieBudget.isOver`).
    ///   - consumed: the day's total as the budget summed it, when there is one. The eaten
    ///     and over figures are rounded from this rather than from the meals re-summed:
    ///     adding the same entries in a different order can land either side of a .5.
    init(mealTotals: [MealType: Double], budget: Double, isOver: Bool, consumed: Double? = nil) {
        let meals = MealType.allCases.sorted { $0.sortOrder < $1.sortOrder }
        let totals = meals.map { meal in
            (meal: meal, kcal: Self.sanitized(mealTotals[meal] ?? 0), isLogged: mealTotals[meal] != nil)
        }
        let eaten = totals.reduce(0) { $0 + $1.kcal }
        let safeBudget = Self.sanitized(budget)

        var sectors: [Sector] = []
        if isOver {
            // The meals share the budget; the rest of what was eaten is the ink slice.
            let scale = eaten > 0 ? min(1, safeBudget / eaten) : 0
            for total in totals {
                Self.append(.meal(total.meal), kcal: total.kcal * scale, to: &sectors)
            }
            Self.append(.over, kcal: eaten - safeBudget, to: &sectors)
        } else {
            for total in totals {
                Self.append(.meal(total.meal), kcal: total.kcal, to: &sectors)
            }
            Self.append(.remaining, kcal: safeBudget - eaten, to: &sectors)
        }

        // Rounded the way `ActivityCalorieBudget` rounds — each figure first, then the
        // difference — so these agree with the number the hero prints from the budget.
        let roundedEaten = consumed.map(Self.sanitized).map(\.roundedCalories) ?? eaten.roundedCalories
        let roundedBudget = safeBudget.roundedCalories

        let overKcal = isOver ? max(0, roundedEaten - roundedBudget) : 0
        var legend = totals.map {
            LegendEntry(meal: $0.meal, kcal: $0.kcal.roundedCalories, isLogged: $0.isLogged)
        }
        if sectors.contains(where: { $0.kind == .over }) {
            legend.append(.over(kcal: overKcal))
        }

        self.sectors = sectors
        self.legend = legend
        self.isOver = isOver
        self.eatenKcal = roundedEaten
        self.budgetKcal = roundedBudget
        self.remainingKcal = isOver ? 0 : max(0, roundedBudget - roundedEaten)
        self.overKcal = overKcal
    }

    /// Reads the budget and its over/under decision straight off `ActivityCalorieBudget`,
    /// so the donut and `CalorieRingSummary(budget:)` are fed the same answer.
    init(mealTotals: [MealType: Double], budget: ActivityCalorieBudget) {
        self.init(
            mealTotals: mealTotals,
            budget: Double(budget.adjustedTarget),
            isOver: budget.isOver,
            consumed: budget.consumed
        )
    }

    /// True when the ring carries an ink "over" sector, and so the legend its "Over" row.
    var hasOverSector: Bool {
        sectors.contains { $0.kind == .over }
    }

    /// Non-finite and negative figures count as nothing, and every figure is held inside
    /// `CalorieDomain` so four meals summed can never overflow to infinity.
    private static func sanitized(_ value: Double) -> Double {
        guard value.isFinite, value > 0 else { return 0 }
        return min(value, Double(CalorieDomain.maximum))
    }

    private static func append(_ kind: SectorKind, kcal: Double, to sectors: inout [Sector]) {
        guard kcal.isFinite, kcal > 0 else { return }
        sectors.append(Sector(kind: kind, kcal: kcal))
    }
}
