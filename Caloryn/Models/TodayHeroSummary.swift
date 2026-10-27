import Foundation

struct TodayHeroSummary: Equatable {
    let ring: CalorieRingSummary
    let donut: CalorieDonutSummary
    let locale: Locale

    init(ring: CalorieRingSummary, donut: CalorieDonutSummary, locale: Locale = .current) {
        self.ring = ring
        self.donut = donut
        self.locale = locale
    }

    init(mealTotals: [MealType: Double], budget: CalorieBudget, locale: Locale = .current) {
        self.init(
            ring: CalorieRingSummary(budget: budget),
            donut: CalorieDonutSummary(mealTotals: mealTotals, budget: budget),
            locale: locale
        )
    }

    var isOver: Bool {
        ring.isOver
    }

    var unrevealed: TodayHeroSummary {
        let target = ring.target
        let emptyRing = CalorieRingSummary(
            isOver: false,
            remaining: target,
            overAmount: 0,
            roundedConsumed: 0,
            target: target
        )
        let loggedMeals = donut.legend.compactMap { $0.isLogged ? $0.meal : nil }
        let emptyDonut = CalorieDonutSummary(
            mealTotals: Dictionary(uniqueKeysWithValues: loggedMeals.map { ($0, 0) }),
            budget: Double(target),
            isOver: false
        )
        return TodayHeroSummary(ring: emptyRing, donut: emptyDonut, locale: locale)
    }

    var headline: Int {
        ring.centerValue
    }

    var headlineText: String {
        isOver ? headline.formatted(.number.locale(locale).sign(strategy: .always())) : grouped(headline)
    }

    var caption: String {
        isOver ? "kcal over \(grouped(ring.target))" : "kcal left of \(grouped(ring.target))"
    }

    var eatenLine: String {
        "\(grouped(ring.roundedConsumed)) eaten"
    }

    func legendValue(for entry: CalorieDonutSummary.LegendEntry) -> String {
        entry.isLogged ? grouped(entry.kcal) : "not yet"
    }

    func legendName(for entry: CalorieDonutSummary.LegendEntry) -> String {
        entry.meal?.displayName ?? "Over"
    }

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
