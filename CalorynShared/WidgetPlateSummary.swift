import Foundation

/// What the widget's plate draws from a `WidgetCalorieSummary`: one sector per logged meal,
/// then either what is left of the budget or what went past it.
///
/// The same rule as the app's `CalorieDonutSummary`, restated here because that struct is
/// built on `MealType` and the app's theme, neither of which the widget target compiles.
/// Keep the two in step:
///
/// - **Under**: each meal's sector is its kcal and one `.remaining` sector holds the rest
///   of the budget, so the ring reads as a plate filling up.
/// - **Over**: the ring is everything eaten. The amount past the budget is its own final
///   `.over` sector and the meals share the budget in proportion to what each contributed,
///   so every logged meal stays visible.
///
/// A snapshot written before meals were recorded has a total but no meals; the difference
/// is drawn as one `.eaten` sector in the neutral History fill, so the plate never disagrees
/// with the number beside it.
///
/// Sector `kcal` is an angle for the chart, not a figure to print: when over, a meal sector
/// is scaled down. Print the summary's own totals.
struct WidgetPlateSummary: Equatable, Sendable {
    enum SectorKind: Hashable, Sendable {
        case meal(WidgetMeal)
        /// Eaten, but not attributed to a meal.
        case eaten
        case remaining
        case over
    }

    struct Sector: Equatable, Identifiable, Sendable {
        let kind: SectorKind
        /// The sector's share of the ring, in kcal. Always positive: a sector that would be
        /// empty is omitted rather than emitted at zero.
        let kcal: Double

        var id: SectorKind { kind }
    }

    /// In `WidgetMeal.allCases` order, then `.eaten` if any, then `.remaining` or `.over`.
    /// With nothing eaten and no budget the ring is one full `.remaining` track.
    let sectors: [Sector]
    let isOver: Bool

    init(calories: WidgetCalorieSummary) {
        let consumed = Double(calories.consumed)
        let budget = Double(calories.target)
        let attributed = calories.meals.reduce(0) { $0 + Double($1.kcal) }
        let unattributed = max(0, consumed - attributed)
        let eaten = attributed + unattributed

        var sectors: [Sector] = []
        isOver = calories.isOver

        if isOver {
            let scale = eaten > 0 ? min(1, budget / eaten) : 0
            for meal in calories.meals {
                Self.append(.meal(meal.meal), kcal: Double(meal.kcal) * scale, to: &sectors)
            }
            Self.append(.eaten, kcal: unattributed * scale, to: &sectors)
            Self.append(.over, kcal: eaten - budget, to: &sectors)
        } else {
            for meal in calories.meals {
                Self.append(.meal(meal.meal), kcal: Double(meal.kcal), to: &sectors)
            }
            Self.append(.eaten, kcal: unattributed, to: &sectors)
            Self.append(.remaining, kcal: budget - eaten, to: &sectors)
        }

        self.sectors = sectors.isEmpty ? [Sector(kind: .remaining, kcal: 1)] : sectors
    }

    private static func append(_ kind: SectorKind, kcal: Double, to sectors: inout [Sector]) {
        guard kcal.isFinite, kcal > 0 else { return }
        sectors.append(Sector(kind: kind, kcal: kcal))
    }
}
