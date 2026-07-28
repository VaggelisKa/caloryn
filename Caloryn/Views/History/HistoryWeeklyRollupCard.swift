import SwiftUI
import Charts

struct HistoryWeeklyRollupCard: View {
    let projection: HistoryWeeklyConsistencyProjection

    private struct ChartWeek: Identifiable {
        let index: Double
        let label: String
        let week: HistoryWeekSummary

        var id: Date { week.id }
    }

    private var layout: HistoryWeeklyConsistencyChart {
        HistoryWeeklyConsistencyChart(weekCount: projection.weeks.count)
    }

    private var chartWeeks: [ChartWeek] {
        projection.weeks.enumerated().map { offset, week in
            ChartWeek(
                index: Double(offset),
                label: HistoryWeeklyConsistencyChart.label(forOffset: offset),
                week: week
            )
        }
    }

    var body: some View {
        let layout = layout

        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Weekly Consistency")
                    .font(CalorynTheme.sectionEyebrow)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .textCase(.uppercase)

                if let headlineText = projection.headlineText {
                    Text(headlineText)
                        .font(CalorynTheme.cardSubtitle)
                        .foregroundStyle(CalorynTheme.textSecondary)
                }
            }

            Chart {
                ForEach(chartWeeks) { chartWeek in
                    BarMark(
                        x: .value("Week", chartWeek.index),
                        y: .value("On Track", chartWeek.week.onTrackRatio * 100),
                        width: .fixed(layout.barWidth)
                    )
                    .foregroundStyle(chartWeek.week.consistencyTint)
                    .cornerRadius(4)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let percentage = value.as(Int.self) {
                            Text("\(percentage)%")
                        }
                    }
                    .font(CalorynTheme.chartAxisLabel)
                }
            }
            .chartXAxis {
                AxisMarks(values: layout.indices) { value in
                    AxisValueLabel(centered: false) {
                        if let index = value.as(Double.self),
                           let label = layout.label(forChartValue: index) {
                            Text(label)
                                .font(CalorynTheme.weeklyChartXAxisLabel(isDense: layout.isDense))
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

                        ForEach(chartWeeks) { chartWeek in
                            if let xPosition = proxy.position(forX: chartWeek.index) {
                                Text(chartWeek.label)
                                    .font(CalorynTheme.weeklyChartXAxisLabel(isDense: layout.isDense))
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
            .chartYScale(domain: 0 ... 100)
            .chartXScale(domain: layout.xAxisDomain)
            .frame(height: 170)
            .accessibilityLabel(
                HistoryWeeklyConsistencyChart.accessibilityLabel(
                    loggedDayCount: projection.loggedDayCount,
                    totalDayCount: projection.totalDayCount
                )
            )
        }
        .historyCard()
    }
}
