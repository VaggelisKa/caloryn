import SwiftUI
import Charts

struct HistoryCalorieTrendSection: View {
    let projection: HistoryCalorieTrendProjection

    private var summary: HistoryCalorieTrendCardSummary {
        projection.cardSummary
    }

    private var layout: HistoryCalorieTrendChartLayout {
        HistoryCalorieTrendChartLayout(range: projection.range, pointCount: projection.points.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HistorySectionTitle("Calorie trend")
            chart
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
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

            RuleMark(y: .value("Goal", projection.dailyCalorieTarget))
                .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [4, 3]))
                .foregroundStyle(CalorynTheme.dataReference)
        }
        .chartXAxis {
            AxisMarks(values: projection.points.map(\.index)) { value in
                AxisValueLabel(centered: false) {
                    if let index = value.as(Double.self),
                       let chartPoint = projection.point(for: index) {
                        Text(chartPoint.xAxisLabel)
                            .font(CalorynTheme.weeklyChartXAxisLabel(isDense: layout.usesDenseAxisLabels))
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
                                .font(CalorynTheme.weeklyChartXAxisLabel(isDense: layout.usesDenseAxisLabels))
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
                    .foregroundStyle(CalorynTheme.separator)
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
        projection: HistoryPatternDiscovery(analytics: history, today: .now).calorieTrend
    )
    .padding()
    .calorynPageCanvas()
}

#Preview("Calorie Trend - Empty") {
    let history = HistoryPreviewFixtures.analytics(for: .empty)

    return HistoryCalorieTrendSection(
        projection: HistoryPatternDiscovery(analytics: history, today: .now).calorieTrend
    )
    .padding()
    .calorynPageCanvas()
}
#endif
