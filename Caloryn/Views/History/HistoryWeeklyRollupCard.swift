import SwiftUI
import Charts

struct HistoryWeeklyRollupCard: View {
    let summary: HistoryPeriodSummary

    private struct ChartWeek: Identifiable {
        let index: Double
        let week: HistoryWeekSummary

        var id: Date { week.id }
    }

    private var chartWeeks: [ChartWeek] {
        summary.weeklyRollups.enumerated().map { offset, week in
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

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Weekly Consistency")
                    .font(CalorynTheme.sectionEyebrow)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .textCase(.uppercase)

                if let bestWeek {
                    Text("Best week had \(bestWeek.onTrackDays) of \(bestWeek.loggedDays) logged \(dayLabel(for: bestWeek.loggedDays)) on track.")
                        .font(CalorynTheme.cardSubtitle)
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
                    .font(CalorynTheme.chartAxisLabel)
                }
            }
            .chartXAxis {
                AxisMarks(values: chartWeeks.map(\.index)) { value in
                    AxisValueLabel(centered: false) {
                        if let index = value.as(Double.self),
                           let chartWeek = chartWeek(for: index) {
                            Text(weekLabel(for: chartWeek))
                                .font(CalorynTheme.weeklyChartXAxisLabel(isDense: chartWeeks.count > 10))
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
                                    .font(CalorynTheme.weeklyChartXAxisLabel(isDense: chartWeeks.count > 10))
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

    private var bestWeek: HistoryWeekSummary? {
        summary.weeklyRollups
            .filter { $0.loggedDays > 0 }
            .max {
                if $0.onTrackRatio == $1.onTrackRatio {
                    return $0.loggedDays < $1.loggedDays
                }
                return $0.onTrackRatio < $1.onTrackRatio
            }
    }

    private var accessibilityLabel: String {
        "Weekly consistency of on-track days. \(summary.loggedDayCount) of \(summary.totalDayCount) days logged."
    }

    private func weekLabel(for chartWeek: ChartWeek) -> String {
        "W\(Int(chartWeek.index) + 1)"
    }

    private func dayLabel(for count: Int) -> String {
        count == 1 ? "day" : "days"
    }

    private func chartWeek(for index: Double) -> ChartWeek? {
        let roundedIndex = Int(index.rounded())
        guard chartWeeks.indices.contains(roundedIndex) else { return nil }
        return chartWeeks[roundedIndex]
    }
}
