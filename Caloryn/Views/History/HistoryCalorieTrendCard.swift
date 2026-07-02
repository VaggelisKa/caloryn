import SwiftUI
import Charts

struct HistoryCalorieTrendCard: View {
    let projection: HistoryCalorieTrendProjection
    let drillDownAction: (() -> Void)?

    init(
        projection: HistoryCalorieTrendProjection,
        drillDownAction: (() -> Void)? = nil
    ) {
        self.projection = projection
        self.drillDownAction = drillDownAction
    }

    private var hasLoggedData: Bool {
        projection.hasLoggedData
    }

    private var totalCalories: Double {
        projection.totalCalories
    }

    private var averageCalories: Double {
        projection.averageCaloriesPerLoggedDay
    }

    private var yAxisUpperBound: Double {
        projection.yAxisUpperBound
    }

    private var barWidth: MarkDimension {
        .fixed(projection.range == .week ? 10 : 6)
    }

    private var chartHeight: CGFloat {
        projection.range == .week ? 160 : 180
    }

    private var xAxisDomain: ClosedRange<Double> {
        guard let firstIndex = projection.points.first?.index,
              let lastIndex = projection.points.last?.index else {
            return 0 ... 1
        }
        return (firstIndex - 0.5) ... (lastIndex + 0.5)
    }

    var body: some View {
        if let drillDownAction {
            Button(action: drillDownAction) {
                content
            }
            .buttonStyle(.plain)
            .accessibilityLabel("View calorie trend details")
            .accessibilityValue(accessibilityLabel)
        } else {
            content
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            chart
        }
        .glassCard()
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                Text("Calorie Trend")
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .textCase(.uppercase)

                Spacer()

                if drillDownAction != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(CalorynTheme.textSecondary)
                        .accessibilityHidden(true)
                }
            }

            if hasLoggedData {
                HStack(alignment: .top, spacing: 0) {
                    statColumn(
                        value: Int(averageCalories.rounded()).formatted(),
                        unit: "kcal/day avg",
                        detail: averageDifferenceText,
                        detailColor: averageDifferenceColor
                    )

                    Spacer(minLength: 16)

                    statColumn(
                        value: Int(totalCalories.rounded()).formatted(),
                        unit: "kcal logged",
                        detail: totalDifferenceText,
                        detailColor: totalDifferenceColor
                    )
                }
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
            ForEach(projection.points) { chartPoint in
                if chartPoint.isLogged {
                    BarMark(
                        x: .value("Period", chartPoint.index),
                        y: .value("Calories", chartPoint.value),
                        width: barWidth
                    )
                    .foregroundStyle(chartPoint.status.tint)
                    .cornerRadius(4)
                    .accessibilityLabel(chartPoint.accessibilityLabel)
                    .accessibilityValue(chartPoint.accessibilityValue)
                } else {
                    PointMark(
                        x: .value("Period", chartPoint.index),
                        y: .value("Calories", 0)
                    )
                    .symbolSize(28)
                    .foregroundStyle(HistoryGoalStatus.notLogged.tint)
                    .accessibilityLabel(chartPoint.accessibilityLabel)
                    .accessibilityValue(chartPoint.accessibilityValue)
                }
            }

            RuleMark(y: .value("Target", projection.dailyCalorieTarget))
                .lineStyle(StrokeStyle(lineWidth: 1.8, lineCap: .round))
                .foregroundStyle(CalorynTheme.textPrimary.opacity(0.62))
        }
        .chartXAxis {
            AxisMarks(values: projection.points.map(\.index)) { value in
                AxisValueLabel(centered: false) {
                    if let index = value.as(Double.self),
                       let chartPoint = chartPoint(for: index) {
                        Text(chartPoint.xAxisLabel)
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

                    ForEach(projection.points) { chartPoint in
                        if let xPosition = proxy.position(forX: chartPoint.index) {
                            Text(chartPoint.xAxisLabel)
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
        .frame(height: chartHeight)
        .accessibilityLabel(accessibilityLabel)
    }

    private func chartPoint(for index: Double) -> HistoryCalorieTrendPoint? {
        projection.point(for: index)
    }

    private var averageDifferenceText: String {
        projection.averageDifferenceText
    }

    private var averageDifferenceColor: Color {
        guard hasLoggedData else { return CalorynTheme.textSecondary }
        return color(
            forDifference: Double(Int(averageCalories.rounded()) - projection.dailyCalorieTarget),
            target: Double(projection.dailyCalorieTarget)
        )
    }

    private var totalDifferenceText: String {
        projection.totalDifferenceText
    }

    private var totalDifferenceColor: Color {
        guard hasLoggedData else { return CalorynTheme.textSecondary }
        let targetTotal = projection.dailyCalorieTarget * projection.loggedDayCount
        return color(
            forDifference: Double(Int(totalCalories.rounded()) - targetTotal),
            target: Double(targetTotal)
        )
    }

    private func color(forDifference difference: Double, target: Double) -> Color {
        guard target > 0 else { return CalorynTheme.textSecondary }

        return HistoryGoalStatus.calorieStatus(
            calories: target + difference,
            loggedCount: 1,
            targetCalories: Int(target.rounded())
        )
        .tint
    }

    private var accessibilityLabel: String {
        guard hasLoggedData else {
            return "Calorie trend for \(projection.range.label). 0 of \(projection.totalDayCount) days logged. Target \(projection.dailyCalorieTarget) calories."
        }

        return "Calorie trend for \(projection.range.label). \(projection.loggedDayCount) of \(projection.totalDayCount) days logged. Average \(Int(averageCalories.rounded())) calories per logged day. Target \(projection.dailyCalorieTarget) calories."
    }
}

#if DEBUG
#Preview("Calorie Trend - 7 Days") {
    let history = HistoryPreviewFixtures.analytics(for: .mostlyOnTrack)

    return HistoryCalorieTrendCard(
        projection: HistoryPatternDiscovery(analytics: history).calorieTrend
    )
    .padding()
}

#Preview("Calorie Trend - Empty") {
    let history = HistoryPreviewFixtures.analytics(for: .empty)

    return HistoryCalorieTrendCard(
        projection: HistoryPatternDiscovery(analytics: history).calorieTrend
    )
    .padding()
}
#endif
