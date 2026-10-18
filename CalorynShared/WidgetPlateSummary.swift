import Foundation

struct WidgetPlateSummary: Equatable, Sendable {
    enum SectorKind: Hashable, Sendable {
        case meal(WidgetMeal)
        case eaten
        case remaining
        case over
    }

    struct Sector: Equatable, Identifiable, Sendable {
        let kind: SectorKind
        let kcal: Double

        var id: SectorKind { kind }
    }

    let sectors: [Sector]
    let isOver: Bool

    init(calories: WidgetCalorieSummary) {
        let consumed = Double(calories.consumed)
        let budget = Double(calories.target)
        let attributed = calories.meals.reduce(0) { $0 + Double($1.kcal) }
        let roundingTolerance = Double(calories.meals.count) + 0.5
        let isRoundingGap = !calories.meals.isEmpty
            && abs(consumed - attributed) <= roundingTolerance
        let mealScale = isRoundingGap && attributed > 0 ? consumed / attributed : 1
        let unattributed = isRoundingGap ? 0 : max(0, consumed - attributed)
        let eaten = isRoundingGap ? consumed : attributed + unattributed

        var sectors: [Sector] = []
        isOver = calories.isOver

        if isOver {
            let scale = eaten > 0 ? min(1, budget / eaten) : 0
            for meal in calories.meals {
                Self.append(.meal(meal.meal), kcal: Double(meal.kcal) * mealScale * scale, to: &sectors)
            }
            Self.append(.eaten, kcal: unattributed * scale, to: &sectors)
            Self.append(.over, kcal: eaten - budget, to: &sectors)
        } else {
            for meal in calories.meals {
                Self.append(.meal(meal.meal), kcal: Double(meal.kcal) * mealScale, to: &sectors)
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
