import Foundation

struct CalorieMiniDonutSectors: Equatable {
    enum Fill: Hashable {
        case meal(MealType)
        case over
        case eaten
    }

    struct Sector: Equatable {
        let fill: Fill
        let start: Double
        let end: Double

        var isWholePlate: Bool { start == 0 && end == 1 }
    }

    let sectors: [Sector]

    init(sectors summarySectors: [CalorieDonutSummary.Sector], mergesEaten: Bool) {
        let amounts = mergesEaten ? Self.merged(summarySectors) : summarySectors.map(Self.amount(of:))
        let total = amounts.reduce(0) { $0 + $1.kcal }

        var cursor = 0.0
        var sectors: [Sector] = []
        for amount in amounts {
            let start = cursor
            cursor += amount.kcal
            guard let fill = amount.fill, amount.kcal > 0 else { continue }
            sectors.append(
                amount.kcal == total
                    ? Sector(fill: fill, start: 0, end: 1)
                    : Sector(fill: fill, start: start / total, end: cursor / total)
            )
        }
        self.sectors = sectors
    }

    private static func amount(of sector: CalorieDonutSummary.Sector) -> (fill: Fill?, kcal: Double) {
        switch sector.kind {
        case .meal(let meal): (.meal(meal), sector.kcal)
        case .over: (.over, sector.kcal)
        case .remaining: (nil, sector.kcal)
        }
    }

    private static func merged(_ sectors: [CalorieDonutSummary.Sector]) -> [(fill: Fill?, kcal: Double)] {
        let eaten = sectors.filter { $0.kind != .remaining }.reduce(0) { $0 + $1.kcal }
        let remaining = sectors.filter { $0.kind == .remaining }.reduce(0) { $0 + $1.kcal }
        return [(.eaten, eaten), (nil, remaining)]
    }
}
