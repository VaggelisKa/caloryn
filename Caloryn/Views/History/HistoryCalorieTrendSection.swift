import SwiftUI
import Charts

/// "Calorie trend": the range's logged total and one bar per day (per week at 90 days) —
/// over days in ink, on track in `historyEaten`, under a step lighter — against the goal line.
/// The whole section opens the drill-down once there is enough logged to inspect.
struct HistoryCalorieTrendSection: View {
    let projection: HistoryCalorieTrendProjection
    let drillDownAction: (() -> Void)?

    init(
        projection: HistoryCalorieTrendProjection,
        drillDownAction: (() -> Void)? = nil
    ) {
        self.projection = projection
        self.drillDownAction = drillDownAction
    }

    private var summary: HistoryCalorieTrendCardSummary {
        HistoryCalorieTrendCardSummary(
            range: projection.range,
            dailyCalorieTarget: projection.dailyCalorieTarget,
            totalDayCount: projection.totalDayCount,
            loggedDayCount: projection.loggedDayCount,
            onTrackLoggedDayCount: projection.onTrackLoggedDayCount,
            hasLoggedData: projection.hasLoggedData,
            averageCaloriesPerLoggedDay: projection.averageCaloriesPerLoggedDay,
            averageTargetPerLoggedDay: projection.averageTargetPerLoggedDay,
            totalCalories: projection.totalCalories,
            loggedDayTargetTotal: projection.loggedDayTargetTotal
        )
    }

    private var layout: HistoryCalorieTrendChartLayout {
        HistoryCalorieTrendChartLayout(
            range: projection.range,
            surface: .card,
            pointCount: projection.points.count
        )
    }

    var body: some View {
        if let drillDownAction {
            Button(action: drillDownAction) {
                content
            }
            .buttonStyle(.plain)
            .accessibilityLabel("View calorie trend details")
            .accessibilityValue(summary.chartAccessibilityLabel)
            .accessibilityIdentifier("history.calorieTrend.card")
        } else {
            content
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            chart
                .padding(.top, 4)

            if let estimatedTargetNoteText = projection.estimatedTargetNoteText {
                Text(estimatedTargetNoteText)
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                HistorySectionTitle("Calorie trend")

                Spacer(minLength: 8)

                if drillDownAction != nil {
                    Image(systemName: "chevron.right")
                        .font(CalorynTheme.compactIcon)
                        .foregroundStyle(CalorynTheme.textSecondary)
                        .accessibilityHidden(true)
                }
            }

            if let totalSupportText = summary.totalSupportText {
                Text(totalSupportText)
                    .font(CalorynTheme.cardSubtitle.monospacedDigit())
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var chart: some View {
        let layout = layout

        return Chart {
            ForEach(projection.points) { chartPoint in
                if chartPoint.isLogged {
                    BarMark(
                        x: .value("Period", chartPoint.index),
                        y: .value("Calories", chartPoint.value),
                        width: .fixed(layout.barWidth)
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
                .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [4, 3]))
                .foregroundStyle(CalorynTheme.textSecondary)
        }
        .chartXAxis {
            AxisMarks(values: projection.points.map(\.index)) { value in
                AxisValueLabel(centered: false) {
                    if let index = value.as(Double.self),
                       let chartPoint = projection.point(for: index) {
                        Text(chartPoint.xAxisLabel)
                            .font(CalorynTheme.trendChartXAxisLabel(pointCount: projection.points.count))
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
                                .font(CalorynTheme.trendChartXAxisLabel(pointCount: projection.points.count))
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
                    .foregroundStyle(CalorynTheme.hairline)
                AxisValueLabel()
                    .font(CalorynTheme.chartAxisLabel)
                    .foregroundStyle(CalorynTheme.textSecondary)
            }
        }
        .chartYScale(domain: 0 ... projection.yAxisUpperBound)
        .chartXScale(domain: layout.xAxisDomain)
        .frame(height: layout.chartHeight)
        .accessibilityLabel(summary.chartAccessibilityLabel)
    }
}

#if DEBUG
#Preview("Calorie Trend - 7 Days") {
    let history = HistoryPreviewFixtures.analytics(for: .mostlyOnTrack)

    return HistoryCalorieTrendSection(
        projection: HistoryPatternDiscovery(analytics: history).calorieTrend
    )
    .padding()
    .calorynPageCanvas()
}

#Preview("Calorie Trend - Empty") {
    let history = HistoryPreviewFixtures.analytics(for: .empty)

    return HistoryCalorieTrendSection(
        projection: HistoryPatternDiscovery(analytics: history).calorieTrend
    )
    .padding()
    .calorynPageCanvas()
}
#endif
