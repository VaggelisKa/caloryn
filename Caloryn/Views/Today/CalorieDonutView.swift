import Charts
import SwiftUI

struct CalorieDonutView: View {
    let summary: CalorieDonutSummary
    var size: CGFloat = 168
    var animated: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isRevealed = false

    private var animates: Bool {
        animated && !reduceMotion
    }

    private var displayed: [CalorieDonutChart.Slice] {
        CalorieDonutChart.slices(for: summary, revealed: isRevealed || !animates)
    }

    var body: some View {
        CalorieDonutChart(
            slices: displayed,
            innerRadius: 0.7,
            angularInset: 1.5,
            overAngularInset: 3,
            colors: .hero
        )
        .frame(width: size, height: size)
        .animation(animates ? .calorynReveal : nil, value: displayed)
        .accessibilityHidden(true)
        .revealOnAppear($isRevealed)
    }
}

struct CalorieMiniDonutView: View {
    enum Outline: Equatable {
        case standard
        case over
        case today
    }

    let summary: CalorieDonutSummary
    var size: CGFloat = 40
    var outline: Outline = .standard
    var uniformFill: Color? = nil
    var innerRadiusRatio: CGFloat = 0
    var plateColor: Color = CalorynTheme.cardBackground
    var fillsPlate: Bool = false

    private var slices: [CalorieDonutChart.Slice] {
        let slices = CalorieDonutChart.slices(for: summary, revealed: true)
        guard uniformFill != nil else { return slices }

        let eaten = slices.filter { $0.kind != .remaining }.reduce(0) { $0 + $1.kcal }
        let remaining = slices.first { $0.kind == .remaining }?.kcal ?? 0
        return [
            CalorieDonutChart.Slice(kind: .meal(.breakfast), kcal: eaten),
            CalorieDonutChart.Slice(kind: .remaining, kcal: remaining),
        ]
    }

    private var plateDiameter: CGFloat { size * 0.9 }
    private var chartDiameter: CGFloat { fillsPlate ? plateDiameter : size * 0.8 }

    var body: some View {
        ZStack {
            Circle()
                .fill(plateColor)
                .frame(width: plateDiameter, height: plateDiameter)

            CalorieDonutChart(
                slices: slices,
                innerRadius: innerRadiusRatio,
                angularInset: 1,
                colors: .plate(uniformFill: uniformFill)
            )
            .frame(width: chartDiameter, height: chartDiameter)
            .opacity(outline == .today ? 0.55 : 1)

            outlineRing
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var outlineRing: some View {
        switch outline {
        case .standard:
            Circle()
                .stroke(CalorynTheme.hairline, lineWidth: CalorynTheme.hairlineWidth)
                .frame(width: plateDiameter, height: plateDiameter)
        case .over:
            Circle()
                .inset(by: 1)
                .stroke(CalorynTheme.textPrimary, lineWidth: 2)
        case .today:
            Circle()
                .stroke(
                    CalorynTheme.textPrimary.opacity(0.35),
                    style: StrokeStyle(lineWidth: CalorynTheme.hairlineWidth, dash: [2, 3])
                )
                .frame(width: plateDiameter, height: plateDiameter)
        }
    }
}

struct CalorieDonutChart: View {
    struct Slice: Equatable, Identifiable {
        let kind: CalorieDonutSummary.SectorKind
        let kcal: Double
        var id: CalorieDonutSummary.SectorKind { kind }
    }

    enum Colors {
        case hero
        case plate(uniformFill: Color?)
    }

    let slices: [Slice]
    let innerRadius: CGFloat
    let angularInset: CGFloat
    let overAngularInset: CGFloat?
    let colors: Colors

    init(
        slices: [Slice],
        innerRadius: CGFloat,
        angularInset: CGFloat,
        overAngularInset: CGFloat? = nil,
        colors: Colors
    ) {
        self.slices = slices
        self.innerRadius = innerRadius
        self.angularInset = angularInset
        self.overAngularInset = overAngularInset
        self.colors = colors
    }

    var body: some View {
        Chart(slices) { slice in
            SectorMark(
                angle: .value("kcal", slice.kcal),
                innerRadius: .ratio(innerRadius),
                angularInset: slice.kind == .over ? overAngularInset ?? angularInset : angularInset
            )
            .foregroundStyle(color(for: slice.kind))
        }
        .chartLegend(.hidden)
    }

    private func color(for kind: CalorieDonutSummary.SectorKind) -> Color {
        switch (kind, colors) {
        case (.meal(let meal), .hero), (.meal(let meal), .plate(uniformFill: nil)):
            CalorynTheme.mealFill(meal)
        case (.meal, .plate(uniformFill: let fill?)), (.over, .plate(uniformFill: let fill?)):
            fill
        case (.over, _):
            CalorynTheme.textPrimary
        case (.remaining, .hero):
            CalorynTheme.hairline
        case (.remaining, .plate):
            Color.clear
        }
    }

    static func slices(for summary: CalorieDonutSummary, revealed: Bool) -> [Slice] {
        let meals = MealType.allCases.sorted { $0.sortOrder < $1.sortOrder }
        let kinds = meals.map(CalorieDonutSummary.SectorKind.meal) + [.over, .remaining]
        let total = summary.sectors.reduce(0) { $0 + $1.kcal }

        guard total > 0 else {
            return kinds.map { Slice(kind: $0, kcal: $0 == .remaining ? 1 : 0) }
        }

        return kinds.map { kind in
            guard revealed else {
                return Slice(kind: kind, kcal: kind == .remaining ? total : 0)
            }
            let kcal = summary.sectors.first { $0.kind == kind }?.kcal ?? 0
            return Slice(kind: kind, kcal: kcal)
        }
    }
}

#Preview("Donuts") {
    VStack(spacing: 24) {
        HStack(spacing: 18) {
            CalorieDonutView(
                summary: CalorieDonutSummary(
                    mealTotals: [.breakfast: 382, .lunch: 463, .snack: 118],
                    budget: 2_000,
                    isOver: false
                )
            )
            CalorieDonutView(
                summary: CalorieDonutSummary(
                    mealTotals: [.breakfast: 382, .lunch: 463, .dinner: 1_377, .snack: 118],
                    budget: 2_000,
                    isOver: true
                ),
                size: 120
            )
        }
        HStack(spacing: 8) {
            CalorieMiniDonutView(
                summary: CalorieDonutSummary(mealTotals: [.breakfast: 2_300], budget: 2_000, isOver: true),
                outline: .over,
                uniformFill: CalorynTheme.historyEaten
            )
            CalorieMiniDonutView(
                summary: CalorieDonutSummary(mealTotals: [.breakfast: 1_690], budget: 2_000, isOver: false),
                uniformFill: CalorynTheme.historyEaten
            )
            CalorieMiniDonutView(
                summary: CalorieDonutSummary(mealTotals: [.breakfast: 963], budget: 2_000, isOver: false),
                outline: .today,
                uniformFill: CalorynTheme.historyEaten
            )
            CalorieMiniDonutView(
                summary: CalorieDonutSummary(
                    mealTotals: [.breakfast: 500, .lunch: 600, .dinner: 700, .snack: 200],
                    budget: 2_000,
                    isOver: false
                ),
                size: 36
            )
        }
    }
    .padding()
    .background(CalorynTheme.pageBackground)
}
