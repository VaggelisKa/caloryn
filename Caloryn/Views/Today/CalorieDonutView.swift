import Charts
import SwiftUI

/// The Today hero's donut: one sector per meal in its fill, then the rest of the budget in
/// `hairline`, or the overshoot in ink. Renders `CalorieDonutSummary` and decides nothing.
///
/// The hole is empty by design — the number sits beside the ring, never inside it. The chart
/// is hidden from VoiceOver: the hero that contains it owns the label, value and hint
/// (`CalorieRingSummary`), so the ring is not announced twice.
struct CalorieDonutView: View {
    let summary: CalorieDonutSummary
    var size: CGFloat = 168
    /// False draws the final state on the first frame and never animates — for a snapshot,
    /// or anywhere the ring must not move.
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
            colors: .hero
        )
        .frame(width: size, height: size)
        .animation(animates ? .smooth(duration: 0.55) : nil, value: displayed)
        .accessibilityHidden(true)
        .onAppear {
            guard animates, !isRevealed else { return }
            // One runloop on the empty track first, so the meals visibly grow into place.
            Task { @MainActor in
                await Task.yield()
                isRevealed = true
            }
        }
    }
}

/// A day as a small plate, for History's day strip, the Settings goal row and onboarding:
/// the same chart at 36–44pt with a thinner inset and no legend.
///
/// The mocks draw these as a filled plate (`innerRadiusRatio` 0) on a disk, with the unfilled
/// budget showing the plate. Pass a ratio above 0 for a ring instead.
///
/// Two plates appear in the boards. History's is a `cardBackground` disk with the food inset
/// inside its rim (the defaults). Settings' goal row sits on a white group, so its plate is
/// `pageBackground` and the food runs to the rim: pass `plateColor: CalorynTheme.pageBackground`
/// and `fillsPlate: true`.
struct CalorieMiniDonutView: View {
    enum Outline: Equatable {
        /// A hairline round the plate.
        case standard
        /// A 2pt ink ring: the day went over its goal.
        case over
        /// A dashed ring and a lighter fill: the day is still in progress.
        case today
    }

    let summary: CalorieDonutSummary
    var size: CGFloat = 40
    var outline: Outline = .standard
    /// One fill for everything eaten instead of each meal's own — History passes
    /// `CalorynTheme.historyEaten`. Over-ness is then told by `outline`, not by an ink slice.
    var uniformFill: Color? = nil
    var innerRadiusRatio: CGFloat = 0
    /// The disk under the food. White on the page; paper on a white surface.
    var plateColor: Color = CalorynTheme.cardBackground
    /// True runs the food out to the plate's rim instead of leaving a margin of plate round it.
    var fillsPlate: Bool = false

    /// With one fill for everything eaten, the meals and the overshoot are one slice:
    /// drawn apart, the inset between them would cut a line through a single colour.
    private var slices: [CalorieDonutChart.Slice] {
        let slices = CalorieDonutChart.slices(for: summary, revealed: true)
        guard uniformFill != nil else { return slices }

        let eaten = slices.filter { $0.kind != .remaining }.reduce(0) { $0 + $1.kcal }
        let remaining = slices.first { $0.kind == .remaining }?.kcal ?? 0
        // The meal kind only picks a colour, and under a uniform fill every meal draws it.
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

/// The Swift Charts donut both views draw. Internal so the two cannot drift apart.
struct CalorieDonutChart: View {
    /// A sector as drawn. Every kind the ring can show is always present — at zero when it
    /// has nothing — so a change of day or a reveal animates each sector's angle rather than
    /// inserting and removing marks.
    struct Slice: Equatable, Identifiable {
        let kind: CalorieDonutSummary.SectorKind
        let kcal: Double
        var id: CalorieDonutSummary.SectorKind { kind }
    }

    enum Colors {
        /// Meals in their fill, the rest of the budget in `hairline`, over in ink.
        case hero
        /// On a plate: the rest of the budget is left clear so the plate shows through.
        case plate(uniformFill: Color?)
    }

    let slices: [Slice]
    let innerRadius: CGFloat
    let angularInset: CGFloat
    let colors: Colors

    var body: some View {
        Chart(slices) { slice in
            SectorMark(
                angle: .value("kcal", slice.kcal),
                innerRadius: .ratio(innerRadius),
                angularInset: angularInset
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

    /// The summary's sectors with every kind present, in drawing order. Unrevealed, the meals
    /// and the overshoot sit at zero and the whole ring is track, so revealing grows them.
    /// With nothing at all to draw, the ring is a bare track rather than a blank space.
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
