import SwiftUI
import Charts

struct HistoryWeeklyRollupCard: View {
    let projection: HistoryWeeklyConsistencyProjection

    private struct ChartWeek: Identifiable {
        let index: Double
        let week: HistoryWeekSummary

        var id: Date { week.id }
    }

    private var chartWeeks: [ChartWeek] {
        projection.weeks.enumerated().map { offset, week in
            ChartWeek(index: Double(offset), week: week)
        }
    }

    private var xAxisDomain: ClosedRange<Double> {
        guard let firstIndex = chartWeeks.first?.index,
              let lastIndex = chartWeeks.last?.index else {
            return 0 ... 1
        }

        return (firstIndex - 0.5) ... (lastIndex + 0.5)
    }

    private var barWidth: MarkDimension {
        .fixed(chartWeeks.count > 10 ? 12 : 16)
    }

    private var xAxisLabelFontSize: CGFloat {
        chartWeeks.count > 10 ? 8 : 10
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Weekly Consistency")
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .textCase(.uppercase)

                if let headlineText = projection.headlineText {
                    Text(headlineText)
                        .font(.system(.subheadline))
                        .foregroundStyle(CalorynTheme.textSecondary)
                }
            }

            Chart {
                ForEach(chartWeeks) { chartWeek in
                    BarMark(
                        x: .value("Week", chartWeek.index),
                        y: .value("On Track", chartWeek.week.onTrackRatio * 100),
                        width: barWidth
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
                    .font(.system(size: 10))
                }
            }
            .chartXAxis {
                AxisMarks(values: chartWeeks.map(\.index)) { value in
                    AxisValueLabel(centered: false) {
                        if let index = value.as(Double.self),
                           let chartWeek = chartWeek(for: index) {
                            Text(weekLabel(for: chartWeek))
                                .font(.system(size: xAxisLabelFontSize))
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
                                Text(weekLabel(for: chartWeek))
                                    .font(.system(size: xAxisLabelFontSize))
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
            .chartXScale(domain: xAxisDomain)
            .frame(height: 170)
            .accessibilityLabel(accessibilityLabel)
        }
        .glassCard()
    }

    private var accessibilityLabel: String {
        "Weekly consistency of on-track days. \(projection.loggedDayCount) of \(projection.totalDayCount) days logged."
    }

    private func weekLabel(for chartWeek: ChartWeek) -> String {
        "W\(Int(chartWeek.index) + 1)"
    }

    private func chartWeek(for index: Double) -> ChartWeek? {
        let roundedIndex = Int(index.rounded())
        guard chartWeeks.indices.contains(roundedIndex) else { return nil }
        return chartWeeks[roundedIndex]
    }
}
