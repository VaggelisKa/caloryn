import Charts
import SwiftUI
import WidgetKit

/// Accentable as a whole: in the tinted rendering mode the meals and the overshoot take the
/// accent at full strength and the track keeps the hairline's own alpha, so the ring still
/// reads as a plate filling up.
struct WidgetPlateView: View {
    let summary: WidgetPlateSummary
    let size: CGFloat

    private var angularInset: CGFloat { size < 72 ? 1 : 1.5 }

    var body: some View {
        Chart(summary.sectors) { sector in
            SectorMark(
                angle: .value("kcal", sector.kcal),
                innerRadius: .ratio(0.7),
                angularInset: sector.kind == .over ? angularInset * 2 : angularInset
            )
            .foregroundStyle(color(for: sector.kind))
        }
        .chartLegend(.hidden)
        .frame(width: size, height: size)
        .widgetAccentable()
        .accessibilityHidden(true)
    }

    private func color(for kind: WidgetPlateSummary.SectorKind) -> Color {
        switch kind {
        case .meal(let meal): WidgetTheme.mealFill(meal)
        case .eaten: CalorynTheme.dataSecondary
        case .over: CalorynTheme.dataPrimary
        case .remaining: CalorynTheme.fillTrack
        }
    }
}

struct WidgetPlateFigures: View {
    let calories: WidgetCalorieSummary
    var numberFont: Font = .title.weight(.heavy)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(primaryValue.formatted())
                .font(numberFont.monospacedDigit())
                .tracking(-0.5)
                .foregroundStyle(CalorynTheme.textPrimary)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(calories.isOver ? "kcal over" : "kcal left")
                .font(.caption.weight(.medium))
                .foregroundStyle(CalorynTheme.textSecondary)
        }
    }

    private var primaryValue: Int {
        calories.isOver ? calories.overAmount : calories.remaining
    }
}

struct WidgetEatenLine: View {
    let calories: WidgetCalorieSummary

    var body: some View {
        Text("\(calories.consumed.formatted()) of \(calories.target.formatted()) eaten")
            .font(.caption.weight(.medium).monospacedDigit())
            .foregroundStyle(CalorynTheme.textSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

struct WidgetPlateLegend: View {
    let calories: WidgetCalorieSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(WidgetMeal.allCases) { meal in
                row(key: key(for: meal), name: meal.displayName, kcal: calories.kcal(for: meal))
            }
            if calories.isOver {
                row(key: overKey, name: "Over", kcal: calories.overAmount)
            }
        }
    }

    private func row(key: some View, name: String, kcal: Int?) -> some View {
        HStack(spacing: 6) {
            key
                .frame(width: 10, height: 10)
            Text(name)
                .font(.caption2.weight(.medium))
                .foregroundStyle(CalorynTheme.textSecondary)
            Spacer(minLength: 6)
            if let kcal {
                Text(kcal.formatted())
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(CalorynTheme.textPrimary)
            } else {
                Text("not yet")
                    .font(.caption2)
                    .foregroundStyle(CalorynTheme.textTertiary)
            }
        }
        .lineLimit(1)
    }

    @ViewBuilder
    private func key(for meal: WidgetMeal) -> some View {
        if calories.kcal(for: meal) != nil {
            Circle()
                .fill(WidgetTheme.mealFill(meal))
                .widgetAccentable()
        } else {
            Circle()
                .stroke(WidgetTheme.mealFill(meal), lineWidth: 1.5)
                .widgetAccentable()
        }
    }

    private var overKey: some View {
        Circle()
            .stroke(CalorynTheme.dataPrimary, lineWidth: 2)
    }
}

struct WidgetQuickLogRows: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(WidgetMeal.allCases.enumerated()), id: \.element) { index, meal in
                if index > 0 {
                    Rectangle()
                        .fill(CalorynTheme.separator)
                        .frame(height: 1)
                }
                WidgetQuickLogRow(meal: meal)
            }
        }
    }
}

private struct WidgetQuickLogRow: View {
    let meal: WidgetMeal

    var body: some View {
        Link(destination: AppRoute.addFood(meal: meal).url) {
            HStack(spacing: 6) {
                Text(meal.displayName)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(WidgetTheme.mealInk(meal))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 4)

                Image(systemName: "plus")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(WidgetTheme.mealInk(meal))
                    .frame(width: 20, height: 20)
                    .background(WidgetTheme.mealWash(meal), in: Circle())
                    .widgetAccentable()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(.rect)
        }
        .accessibilityLabel("Log \(meal.displayName)")
    }
}

struct WidgetSectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline.weight(.bold))
            .foregroundStyle(CalorynTheme.textPrimary)
            .lineLimit(1)
    }
}
