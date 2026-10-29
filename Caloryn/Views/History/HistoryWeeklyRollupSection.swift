import SwiftUI
import Charts

struct HistoryWeeklyRollupSection: View {
    let projection: HistoryWeeklyConsistencyProjection

    @ScaledMetric(relativeTo: .caption2) private var countHeadroom: CGFloat = 18

    var body: some View {
        let chart = projection.chart

        return VStack(alignment: .leading, spacing: 10) {
            HistorySectionTitle("Weekly consistency")

            Chart {
                ForEach(chart.weeks) { week in
                    BarMark(
                        x: .value("Week", Double(week.index)),
                        y: .value("On Track", week.onTrackPercentage),
                        width: .fixed(chart.barWidth)
                    )
                    .foregroundStyle(
                        HistoryTheme.color(
                            for: .weeklyConsistency(onTrackDays: week.onTrackDays, loggedDays: week.loggedDays)
                        )
                    )
                    .cornerRadius(4)
                    .accessibilityLabel(week.accessibilityLabel)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                    AxisGridLine()
                        .foregroundStyle(CalorynTheme.separator)
                    AxisValueLabel {
                        if let percentage = value.as(Int.self) {
                            Text("\(percentage)%")
                                .foregroundStyle(CalorynTheme.textSecondary)
                        }
                    }
                    .font(CalorynTheme.chartAxisLabel)
                }
            }
            .chartXAxis {
                AxisMarks(values: chart.indices) { value in
                    AxisValueLabel(centered: false) {
                        if let index = value.as(Double.self),
                           let label = chart.label(forChartValue: index) {
                            Text(label)
                                .font(CalorynTheme.weeklyChartXAxisLabel(isDense: chart.isDense))
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
                        let slotWidth = chart.axis.hitTargetWidth(plotWidth: plotRect.width)

                        ForEach(chart.weeks) { week in
                            if let xPosition = proxy.position(forX: Double(week.index)) {
                                if chart.showsCounts,
                                   let countText = week.countText,
                                   let yPosition = proxy.position(forY: week.onTrackPercentage) {
                                    Text(countText)
                                        .font(CalorynTheme.microCaptionEmphasized.monospacedDigit())
                                        .foregroundStyle(CalorynTheme.textPrimary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                        .frame(width: slotWidth)
                                        .position(
                                            x: plotRect.minX + xPosition,
                                            y: plotRect.minY + yPosition - countHeadroom / 2
                                        )
                                }

                                if let axisLabel = week.axisLabel {
                                    Text(axisLabel)
                                        .font(CalorynTheme.weeklyChartXAxisLabel(isDense: chart.isDense))
                                        .foregroundStyle(CalorynTheme.textSecondary)
                                        .fixedSize()
                                        .position(
                                            x: plotRect.minX + xPosition,
                                            y: plotRect.maxY + 11
                                        )
                                }
                            }
                        }
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .chartYScale(domain: 0 ... 100)
            .chartXScale(domain: chart.xAxisDomain)
            .frame(height: 170)
            .padding(.top, chart.showsCounts ? countHeadroom : 4)
            .accessibilityLabel(
                HistoryWeeklyConsistencyChart.accessibilityLabel(
                    loggedDayCount: projection.loggedDayCount,
                    totalDayCount: projection.totalDayCount
                )
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
