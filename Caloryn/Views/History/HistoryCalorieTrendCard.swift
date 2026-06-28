import SwiftUI
import Charts

struct HistoryCalorieTrendCard: View {
    let range: HistoryRange
    let summary: HistoryPeriodSummary

    private struct ChartDay: Identifiable {
        let index: Double
        let day: HistoryDaySummary

        var id: Date { day.id }
    }

    private var chartDays: [ChartDay] {
        summary.days.enumerated().map { offset, day in
            ChartDay(index: Double(offset), day: day)
        }
    }

    private var loggedDays: [HistoryDaySummary] {
        summary.days.filter(\.isLogged)
    }

    private var hasLoggedData: Bool {
        !loggedDays.isEmpty
    }

    private var totalCalories: Double {
        loggedDays.reduce(0) { $0 + $1.calories }
    }

    private var averageCalories: Double {
        summary.averageCaloriesPerLoggedDay
    }

    private var yAxisUpperBound: Double {
        let largestDay = summary.days.map(\.calories).max() ?? 0
        let largestReference = max(largestDay, Double(summary.dailyCalorieTarget), averageCalories, 1)
        return largestReference * 1.15
    }

    private var barWidth: MarkDimension {
        .fixed(range == .week ? 10 : 6)
    }

    private var xAxisDomain: ClosedRange<Double> {
        guard let firstIndex = chartDays.first?.index,
              let lastIndex = chartDays.last?.index else {
            return 0 ... 1
        }
        return (firstIndex - 0.5) ... (lastIndex + 0.5)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            chart
            legend
        }
        .glassCard()
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Calorie Trend")
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .textCase(.uppercase)
            }

            HStack(alignment: .top, spacing: 0) {
                statColumn(
                    value: hasLoggedData ? Int(averageCalories.rounded()).formatted() : "No data",
                    unit: "kcal/day avg",
                    detail: averageDifferenceText,
                    detailColor: averageDifferenceColor
                )

                Spacer(minLength: 16)

                statColumn(
                    value: hasLoggedData ? Int(totalCalories.rounded()).formatted() : "No data",
                    unit: "kcal logged",
                    detail: totalDifferenceText,
                    detailColor: totalDifferenceColor
                )
            }
        }
    }

    private func statColumn(
        value: String,
        unit: String,
        detail: String,
        detailColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(hasLoggedData ? CalorynTheme.textPrimary : CalorynTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(unit)
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Text(detail)
                .font(CalorynTheme.numericCaption)
                .foregroundStyle(detailColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var chart: some View {
        Chart {
            ForEach(chartDays) { chartDay in
                if chartDay.day.isLogged {
                    BarMark(
                        x: .value("Day", chartDay.index),
                        y: .value("Calories", chartDay.day.calories),
                        width: barWidth
                    )
                    .foregroundStyle(chartDay.day.status.tint)
                    .cornerRadius(4)
                    .accessibilityLabel(chartDay.day.date.shortFormatted)
                    .accessibilityValue("\(Int(chartDay.day.calories.rounded())) calories, \(chartDay.day.status.label)")
                } else {
                    PointMark(
                        x: .value("Day", chartDay.index),
                        y: .value("Calories", 0)
                    )
                    .symbolSize(28)
                    .foregroundStyle(HistoryGoalStatus.notLogged.tint)
                    .accessibilityLabel(chartDay.day.date.shortFormatted)
                    .accessibilityValue("No calories logged")
                }
            }

            RuleMark(y: .value("Target", summary.dailyCalorieTarget))
                .lineStyle(StrokeStyle(lineWidth: 1.8, lineCap: .round))
                .foregroundStyle(CalorynTheme.textPrimary.opacity(0.62))
        }
        .chartXAxis {
            AxisMarks(values: chartDays.map(\.index)) { value in
                AxisValueLabel(centered: false) {
                    if let index = value.as(Double.self),
                       let chartDay = chartDay(for: index) {
                        Text(weekdayInitial(for: chartDay.day.date))
                            .font(.system(size: 10))
                            .foregroundStyle(.clear)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                if let plotFrame = proxy.plotFrame {
                    let plotRect = geometry[plotFrame]

                    ForEach(chartDays) { chartDay in
                        if let xPosition = proxy.position(forX: chartDay.index) {
                            Text(weekdayInitial(for: chartDay.day.date))
                                .font(.system(size: 10))
                                .foregroundStyle(CalorynTheme.textSecondary)
                                .position(
                                    x: plotRect.minX + xPosition,
                                    y: plotRect.maxY + 11
                                )
                        }
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine()
                AxisValueLabel()
                    .font(.system(size: 10))
            }
        }
        .chartYScale(domain: 0 ... yAxisUpperBound)
        .chartXScale(domain: xAxisDomain)
        .frame(height: range == .week ? 160 : 180)
        .accessibilityLabel(accessibilityLabel)
    }

    private var legend: some View {
        HStack(spacing: 12) {
            legendItem("Under", color: HistoryGoalStatus.under.tint)
            legendItem("On track", color: HistoryGoalStatus.onTrack.tint)
            legendItem("Over", color: HistoryGoalStatus.over.tint)
            legendItem("Empty", color: HistoryGoalStatus.notLogged.tint)
        }
        .font(CalorynTheme.caption)
        .foregroundStyle(CalorynTheme.textSecondary)
        .accessibilityElement(children: .combine)
    }

    private func legendItem(_ label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)

            Text(label)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private func weekdayInitial(for date: Date) -> String {
        let weekday = Calendar.current.component(.weekday, from: date)
        return ["S", "M", "T", "W", "T", "F", "S"][max(0, min(weekday - 1, 6))]
    }

    private func chartDay(for index: Double) -> ChartDay? {
        let roundedIndex = Int(index.rounded())
        guard chartDays.indices.contains(roundedIndex) else { return nil }
        return chartDays[roundedIndex]
    }

    private var averageDifferenceText: String {
        guard hasLoggedData else { return "No logged days" }
        return differenceText(Int(averageCalories.rounded()) - summary.dailyCalorieTarget)
    }

    private var averageDifferenceColor: Color {
        guard hasLoggedData else { return CalorynTheme.textSecondary }
        return color(
            forDifference: Double(Int(averageCalories.rounded()) - summary.dailyCalorieTarget),
            target: Double(summary.dailyCalorieTarget)
        )
    }

    private var totalDifferenceText: String {
        guard hasLoggedData else { return "No logged days" }
        let targetTotal = summary.dailyCalorieTarget * loggedDays.count
        return differenceText(Int(totalCalories.rounded()) - targetTotal)
    }

    private var totalDifferenceColor: Color {
        guard hasLoggedData else { return CalorynTheme.textSecondary }
        let targetTotal = summary.dailyCalorieTarget * loggedDays.count
        return color(
            forDifference: Double(Int(totalCalories.rounded()) - targetTotal),
            target: Double(targetTotal)
        )
    }

    private func differenceText(_ difference: Int) -> String {
        if difference > 0 { return "+\(difference.formatted()) over target" }
        if difference < 0 { return "\(abs(difference).formatted()) under target" }
        return "On target"
    }

    private func color(forDifference difference: Double, target: Double) -> Color {
        guard target > 0 else { return CalorynTheme.textSecondary }

        if difference < -(target * HistoryAnalytics.onTrackTolerance) {
            return HistoryGoalStatus.under.tint
        }
        if difference > target * HistoryAnalytics.onTrackTolerance {
            return HistoryGoalStatus.over.tint
        }
        return HistoryGoalStatus.onTrack.tint
    }

    private var accessibilityLabel: String {
        "Calorie trend for \(range.label). \(summary.loggedDayCount) of \(summary.totalDayCount) days logged. Average \(Int(averageCalories.rounded())) calories per logged day. Target \(summary.dailyCalorieTarget) calories."
    }
}

#if DEBUG
#Preview("Calorie Trend - 7 Days") {
    let history = HistoryPreviewFixtures.analytics(for: .mostlyOnTrack)

    return HistoryCalorieTrendCard(
        range: history.range,
        summary: history.current
    )
    .padding()
}

#Preview("Calorie Trend - Empty") {
    let history = HistoryPreviewFixtures.analytics(for: .empty)

    return HistoryCalorieTrendCard(
        range: history.range,
        summary: history.current
    )
    .padding()
}
#endif
