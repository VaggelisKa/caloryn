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
        VStack(alignment: .leading, spacing: 14) {
            header
            chart

            if let estimatedTargetNoteText = projection.estimatedTargetNoteText {
                Text(estimatedTargetNoteText)
                    .font(CalorynTheme.microCaption)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .historyCard()
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        let summary = summary

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                Text("Calorie Trend")
                    .font(CalorynTheme.sectionEyebrow)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .textCase(.uppercase)

                Spacer()

                if drillDownAction != nil {
                    Image(systemName: "chevron.right")
                        .font(CalorynTheme.compactIcon)
                        .foregroundStyle(CalorynTheme.textSecondary)
                        .accessibilityHidden(true)
                }
            }

            if summary.showsStatColumns {
                HStack(alignment: .top, spacing: 0) {
                    statColumn(
                        value: summary.averageValueText,
                        unit: "kcal/day avg",
                        detail: projection.averageDifferenceText,
                        detailColor: color(for: summary.averageDifferenceTone)
                    )

                    Spacer(minLength: 16)

                    statColumn(
                        value: summary.totalValueText,
                        unit: "kcal logged",
                        detail: projection.totalDifferenceText,
                        detailColor: color(for: summary.totalDifferenceTone)
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
                    .font(CalorynTheme.compactNumber)
                    .foregroundStyle(CalorynTheme.textPrimary)
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
                .lineStyle(StrokeStyle(lineWidth: 1.8, lineCap: .round))
                .foregroundStyle(CalorynTheme.textPrimary.opacity(0.62))
        }
        .chartXAxis {
            AxisMarks(values: projection.points.map(\.index)) { value in
                AxisValueLabel(centered: false) {
                    if let index = value.as(Double.self),
                       let chartPoint = projection.point(for: index) {
                        Text(chartPoint.xAxisLabel)
                            .font(CalorynTheme.chartAxisLabel)
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
                                .font(CalorynTheme.chartAxisLabel)
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
                    .font(CalorynTheme.chartAxisLabel)
            }
        }
        .chartYScale(domain: 0 ... projection.yAxisUpperBound)
        .chartXScale(domain: layout.xAxisDomain)
        .frame(height: layout.chartHeight)
        .accessibilityLabel(summary.chartAccessibilityLabel)
    }

    private func color(
        for tone: HistoryCalorieTrendCardSummary.DifferenceTone
    ) -> Color {
        switch tone {
        case .neutral:
            CalorynTheme.textSecondary
        case .status(let status):
            status.tint
        }
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
