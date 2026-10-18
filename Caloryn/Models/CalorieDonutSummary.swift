import Foundation

struct CalorieDonutSummary: Equatable {
    enum SectorKind: Hashable {
        case meal(MealType)
        case remaining
        case over
    }

    struct Sector: Equatable, Identifiable {
        let kind: SectorKind
        let kcal: Double

        var id: SectorKind { kind }
    }

    struct LegendEntry: Equatable, Identifiable {
        enum Key: Hashable {
            case meal(MealType)
            case over
        }

        let key: Key
        let kcal: Int
        let isLogged: Bool

        var id: Key { key }

        var meal: MealType? {
            if case .meal(let meal) = key { meal } else { nil }
        }

        init(meal: MealType, kcal: Int, isLogged: Bool) {
            self.key = .meal(meal)
            self.kcal = kcal
            self.isLogged = isLogged
        }

        static func over(kcal: Int) -> LegendEntry {
            LegendEntry(key: .over, kcal: kcal, isLogged: true)
        }

        private init(key: Key, kcal: Int, isLogged: Bool) {
            self.key = key
            self.kcal = kcal
            self.isLogged = isLogged
        }
    }

    let sectors: [Sector]
    let legend: [LegendEntry]
    let isOver: Bool
    let eatenKcal: Int
    let budgetKcal: Int
    let remainingKcal: Int
    let overKcal: Int

    init(mealTotals: [MealType: Double], budget: Double, isOver: Bool, consumed: Double? = nil) {
        let meals = MealType.allCases.sorted { $0.sortOrder < $1.sortOrder }
        let totals = meals.map { meal in
            (meal: meal, kcal: Self.sanitized(mealTotals[meal] ?? 0), isLogged: mealTotals[meal] != nil)
        }
        let eaten = totals.reduce(0) { $0 + $1.kcal }
        let safeBudget = Self.sanitized(budget)

        var sectors: [Sector] = []
        if isOver {
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

    init(mealTotals: [MealType: Double], budget: ActivityCalorieBudget) {
        self.init(
            mealTotals: mealTotals,
            budget: Double(budget.adjustedTarget),
            isOver: budget.isOver,
            consumed: budget.consumed
        )
    }

    var hasOverSector: Bool {
        sectors.contains { $0.kind == .over }
    }

    private static func sanitized(_ value: Double) -> Double {
        guard value.isFinite, value > 0 else { return 0 }
        return min(value, Double(CalorieDomain.maximum))
    }

    private static func append(_ kind: SectorKind, kcal: Double, to sectors: inout [Sector]) {
        guard kcal.isFinite, kcal > 0 else { return }
        sectors.append(Sector(kind: kind, kcal: kcal))
    }
}
