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
            overAngularInset: 3
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
    var plateColor: Color = CalorynTheme.backgroundSecondary
    var fillsPlate: Bool = false

    private static let antialiasedRimBleed: CGFloat = 1

    private var sectors: [CalorieMiniDonutSectors.Sector] {
        CalorieMiniDonutSectors(sectors: summary.sectors, mergesEaten: uniformFill != nil).sectors
    }

    private var plateDiameter: CGFloat { size * 0.9 }
    private var chartDiameter: CGFloat { fillsPlate ? plateDiameter : size * 0.8 }

    var body: some View {
        ZStack {
            Circle()
                .fill(plateColor)
                .frame(width: plateDiameter, height: plateDiameter)

            Canvas { context, _ in
                let pie = CGRect(x: 0, y: 0, width: chartDiameter, height: chartDiameter)
                for sector in sectors {
                    context.fill(
                        PlateSector(sector: sector).path(in: pie),
                        with: .color(color(for: sector.fill))
                    )
                }
            }
            .frame(
                width: chartDiameter + Self.antialiasedRimBleed,
                height: chartDiameter + Self.antialiasedRimBleed
            )
            .frame(width: chartDiameter, height: chartDiameter, alignment: .topLeading)
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
                .stroke(CalorynTheme.separator, lineWidth: CalorynTheme.hairlineWidth)
                .frame(width: plateDiameter, height: plateDiameter)
        case .over:
            Circle()
                .inset(by: 1)
                .stroke(CalorynTheme.dataPrimary, lineWidth: 2)
        case .today:
            Circle()
                .stroke(
                    CalorynTheme.dataPrimary.opacity(0.35),
                    style: StrokeStyle(lineWidth: CalorynTheme.hairlineWidth, dash: [2, 3])
                )
                .frame(width: plateDiameter, height: plateDiameter)
        }
    }

    private func color(for fill: CalorieMiniDonutSectors.Fill) -> Color {
        switch fill {
        case .meal(let meal): uniformFill ?? CalorynTheme.mealFill(meal)
        case .over: uniformFill ?? CalorynTheme.dataPrimary
        case .eaten: uniformFill ?? CalorynTheme.dataSecondary
        }
    }
}

nonisolated private struct PlateSector: Shape {
    private static let inset: Double = 1

    let sector: CalorieMiniDonutSectors.Sector

    func path(in rect: CGRect) -> Path {
        guard !sector.isWholePlate else { return Path(ellipseIn: rect) }

        let radius = Double(min(rect.width, rect.height)) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)

        let start = sector.start * 2 * .pi - .pi / 2
        let end = sector.end * 2 * .pi - .pi / 2
        let span = end - start
        var path = Path()
        if span > .pi {
            path.addArc(
                center: center,
                radius: Self.inset,
                startAngle: .radians(start + .pi / 2),
                endAngle: .radians(end - .pi / 2),
                clockwise: false
            )
        } else {
            let apexDistance = Self.inset / sin(span / 2)
            guard apexDistance < radius else { return path }
            let bisector = (start + end) / 2
            path.move(to: CGPoint(
                x: Double(center.x) + apexDistance * cos(bisector),
                y: Double(center.y) + apexDistance * sin(bisector)
            ))
        }
        let edge = asin(min(1, Self.inset / radius))
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .radians(end - edge),
            endAngle: .radians(start + edge),
            clockwise: true
        )
        path.closeSubpath()
        return path
    }
}

struct CalorieDonutChart: View {
    struct Slice: Equatable, Identifiable {
        let kind: CalorieDonutSummary.SectorKind
        let kcal: Double
        var id: CalorieDonutSummary.SectorKind { kind }
    }

    let slices: [Slice]
    let innerRadius: CGFloat
    let angularInset: CGFloat
    let overAngularInset: CGFloat

    var body: some View {
        Chart(slices) { slice in
            SectorMark(
                angle: .value("kcal", slice.kcal),
                innerRadius: .ratio(innerRadius),
                angularInset: slice.kind == .over ? overAngularInset : angularInset
            )
            .foregroundStyle(color(for: slice.kind))
        }
        .chartLegend(.hidden)
    }

    private func color(for kind: CalorieDonutSummary.SectorKind) -> Color {
        switch kind {
        case .meal(let meal): CalorynTheme.mealFill(meal)
        case .over: CalorynTheme.dataPrimary
        case .remaining: CalorynTheme.fillTrack
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
                uniformFill: CalorynTheme.dataSecondary
            )
            CalorieMiniDonutView(
                summary: CalorieDonutSummary(mealTotals: [.breakfast: 1_690], budget: 2_000, isOver: false),
                uniformFill: CalorynTheme.dataSecondary
            )
            CalorieMiniDonutView(
                summary: CalorieDonutSummary(mealTotals: [.breakfast: 963], budget: 2_000, isOver: false),
                outline: .today,
                uniformFill: CalorynTheme.dataSecondary
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
    .background(CalorynTheme.backgroundPrimary)
}
