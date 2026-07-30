import SwiftUI
import Charts

struct HistoryCalorieTrendDetailView: View {
    let range: HistoryRange
    let summary: HistoryPeriodSummary

    @State private var selectedPointID: String?

    var body: some View {
        let projection = HistoryCalorieTrendProjection(
            range: range,
            summary: summary
        )
        let selectedPoint = projection.points.first { $0.id == selectedPointID }

        ScrollView {
            VStack(spacing: CalorynTheme.cardSpacing) {
                HistoryCalorieTrendRangeSummaryCard(
                    projection: projection
                )

                HistoryCalorieTrendInteractiveChart(
                    projection: projection,
                    selectedPointID: $selectedPointID
                )

                if let selectedPoint {
                    HistoryCalorieTrendSelectedAnalysis(
                        projection: projection,
                        point: selectedPoint
                    )
                }
            }
            .padding(.horizontal, CalorynTheme.pagePadding)
            .padding(.bottom, 20)
        }
        .calorynPageCanvas()
        .calorynDrillDownNavigation()
        .navigationTitle("Calorie Trend")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("history.calorieTrend.details")
    }
}

private struct HistoryCalorieTrendRangeSummaryCard: View {
    let projection: HistoryCalorieTrendProjection

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

    var body: some View {
        let summary = summary

        return VStack(alignment: .leading, spacing: 14) {
            Text("Range Summary")
                .font(CalorynTheme.sectionEyebrow)
                .foregroundStyle(CalorynTheme.textSecondary)
                .textCase(.uppercase)

            HStack(alignment: .top, spacing: 12) {
                metric(
                    value: summary.onTrackRatioText,
                    label: "logged days on track"
                )

                Divider()
                    .foregroundStyle(CalorynTheme.stone.opacity(0.3))
                    .frame(height: 42)

                metric(
                    value: summary.averageValueText,
                    label: "kcal/day avg"
                )
            }

            Divider()
                .foregroundStyle(CalorynTheme.stone.opacity(0.3))

            VStack(alignment: .leading, spacing: 8) {
                summaryLine(projection.totalTargetDeltaText)

                if let biggestInconsistencyText = projection.biggestInconsistencyText {
                    summaryLine(biggestInconsistencyText)
                }

                if let estimatedTargetNoteText = projection.estimatedTargetNoteText {
                    summaryLine(estimatedTargetNoteText)
                }
            }
        }
        .historyCard()
        .accessibilityElement(children: .combine)
    }

    private func metric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(CalorynTheme.numericBody)
                .foregroundStyle(CalorynTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(label)
                .font(CalorynTheme.caption)
                .foregroundStyle(CalorynTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func summaryLine(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle()
                .fill(CalorynTheme.textSecondary.opacity(0.45))
                .frame(width: 5, height: 5)
                .accessibilityHidden(true)

            Text(text)
                .font(CalorynTheme.caption)
                .foregroundStyle(CalorynTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

}

private struct HistoryCalorieTrendInteractiveChart: View {
    let projection: HistoryCalorieTrendProjection

    @Binding var selectedPointID: String?

    private var layout: HistoryCalorieTrendChartLayout {
        HistoryCalorieTrendChartLayout(
            range: projection.range,
            surface: .detail,
            pointCount: projection.points.count
        )
    }

    var body: some View {
        let layout = layout

        return VStack(alignment: .leading, spacing: 14) {
            Text("Calories")
                .font(CalorynTheme.sectionEyebrow)
                .foregroundStyle(CalorynTheme.textSecondary)
                .textCase(.uppercase)

            Chart {
                ForEach(projection.points) { point in
                    if point.isLogged {
                        BarMark(
                            x: .value("Period", point.index),
                            y: .value("Calories", point.value),
                            width: .fixed(layout.barWidth)
                        )
                        .foregroundStyle(barColor(point))
                        .cornerRadius(4)
                        .accessibilityLabel(point.accessibilityLabel)
                        .accessibilityValue(point.accessibilityValue)

                        if emphasis(point) == .selected {
                            PointMark(
                                x: .value("Period", point.index),
                                y: .value("Calories", point.value)
                            )
                            .symbol {
                                Circle()
                                    .stroke(point.status.tint, lineWidth: 2)
                                    .background(Circle().fill(CalorynTheme.surface))
                                    .frame(width: 12, height: 12)
                            }
                            .accessibilityHidden(true)
                        }
                    } else {
                        PointMark(
                            x: .value("Period", point.index),
                            y: .value("Calories", 0)
                        )
                        .symbolSize(28)
                        .foregroundStyle(HistoryGoalStatus.notLogged.tint)
                        .accessibilityLabel(point.accessibilityLabel)
                        .accessibilityValue(point.accessibilityValue)
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
                           let point = projection.point(for: index) {
                            Text(point.xAxisLabel)
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

                        ZStack {
                            Rectangle()
                                .fill(.clear)
                                .contentShape(Rectangle())
                                .accessibilityHidden(true)
                                .gesture(
                                    SpatialTapGesture()
                                        .onEnded { value in
                                            selectPoint(
                                                at: value.location,
                                                plotRect: plotRect,
                                                proxy: proxy
                                            )
                                        }
                                )

                            ForEach(projection.points) { point in
                                if let xPosition = proxy.position(forX: point.index) {
                                    Text(point.xAxisLabel)
                                        .font(CalorynTheme.chartAxisLabel)
                                        .foregroundStyle(CalorynTheme.textSecondary)
                                        .position(
                                            x: plotRect.minX + xPosition,
                                            y: plotRect.maxY + 11
                                        )
                                        .accessibilityHidden(true)
                                        .allowsHitTesting(false)

                                    Button {
                                        selectedPointID = point.id
                                    } label: {
                                        Rectangle()
                                            .fill(.clear)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .frame(
                                        width: layout.hitTargetWidth(plotWidth: plotRect.width),
                                        height: plotRect.height + 26
                                    )
                                    .position(
                                        x: plotRect.minX + xPosition,
                                        y: plotRect.midY + 13
                                    )
                                    .accessibilityLabel("Inspect \(point.accessibilityLabel)")
                                    .accessibilityValue(point.accessibilityValue)
                                }
                            }
                        }
                    }
                }
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
            .accessibilityLabel(
                HistoryCalorieTrendCardSummary.detailChartAccessibilityLabel(
                    range: projection.range,
                    loggedDayCount: projection.loggedDayCount,
                    totalDayCount: projection.totalDayCount
                )
            )
        }
        .historyCard()
    }

    private func emphasis(
        _ point: HistoryCalorieTrendPoint
    ) -> HistoryCalorieTrendChartLayout.BarEmphasis {
        HistoryCalorieTrendChartLayout.barEmphasis(
            pointID: point.id,
            selectedPointID: selectedPointID
        )
    }

    private func barColor(_ point: HistoryCalorieTrendPoint) -> Color {
        switch emphasis(point) {
        case .normal, .selected:
            point.status.tint
        case .muted:
            point.status.tint.opacity(0.48)
        }
    }

    private func selectPoint(
        at location: CGPoint,
        plotRect: CGRect,
        proxy: ChartProxy
    ) {
        let layout = layout
        guard let localX = layout.axis.plotLocalX(for: location, in: plotRect),
              let slot = layout.selectedSlot(
                chartValue: proxy.value(atX: localX, as: Double.self)
              ),
              projection.points.indices.contains(slot) else {
            return
        }

        selectedPointID = projection.points[slot].id
    }
}

private struct HistoryCalorieTrendSelectedAnalysis: View {
    let projection: HistoryCalorieTrendProjection
    let point: HistoryCalorieTrendPoint

    var body: some View {
        switch point.selection {
        case .day(let day):
            let detail = day.makeDetail()
            HistoryCalorieTrendSelectedDayCard(
                projection: projection,
                detail: detail
            )
        case .week(let week):
            HistoryCalorieTrendSelectedWeekCard(
                projection: projection,
                week: week,
                point: point,
                topFoods: projection.topFoods(for: point.selection)
            )
        }
    }
}

private struct HistoryCalorieTrendSelectedDayCard: View {
    let projection: HistoryCalorieTrendProjection
    let detail: HistoryDayDetail

    private var breakdown: HistoryCalorieTrendDayBreakdown {
        HistoryCalorieTrendDayBreakdown(
            isLogged: detail.isLogged,
            calorieDifference: detail.calorieDifference,
            dailyCalorieTarget: detail.dailyCalorieTarget,
            mealCalories: Dictionary(
                detail.mealSummaries.map { ($0.mealType, $0.calories) },
                uniquingKeysWith: { $1 }
            ),
            foods: detail.topFoods
        )
    }

    var body: some View {
        let breakdown = breakdown

        return VStack(alignment: .leading, spacing: 14) {
            header

            if breakdown.isLogged {
                metricStack
                Divider()
                    .foregroundStyle(CalorynTheme.stone.opacity(0.3))
                mealSplit(breakdown)

                if breakdown.showsFoodSection {
                    Divider()
                        .foregroundStyle(CalorynTheme.stone.opacity(0.3))
                    foodDrivers(breakdown)
                }
            } else {
                unloggedState(breakdown)
            }
        }
        .historyCard()
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(detail.date.shortFormatted)
                    .font(CalorynTheme.itemTitle)
                    .foregroundStyle(CalorynTheme.textPrimary)

                Text("Selected day")
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)
            }

            Spacer()

            statusBadge(detail.status)
        }
    }

    private var metricStack: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(projection.targetDeltaText(detail.calorieDifference, unit: "kcal"))
                .font(CalorynTheme.numericBody)
                .foregroundStyle(detail.status.tint)

            if let averageDeltaText = projection.averageDeltaText(
                value: detail.calories,
                unit: "kcal"
            ) {
                Text(averageDeltaText)
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)
            }

            if detail.isTargetEstimated {
                Text("Compared with your current target — no saved goal for this day.")
                    .font(CalorynTheme.microCaption)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func mealSplit(_ breakdown: HistoryCalorieTrendDayBreakdown) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Meal Split")
                .font(CalorynTheme.sectionEyebrow)
                .foregroundStyle(CalorynTheme.textSecondary)
                .textCase(.uppercase)

            VStack(spacing: 8) {
                ForEach(breakdown.mealRows) { row in
                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: row.iconName)
                            .font(CalorynTheme.compactIcon)
                            .foregroundStyle(row.hasCalories ? CalorynTheme.sage : CalorynTheme.textSecondary)
                            .frame(width: 20)
                            .accessibilityHidden(true)

                        Text(row.title)
                            .font(CalorynTheme.caption)
                            .foregroundStyle(CalorynTheme.textPrimary)

                        Spacer()

                        Text(row.caloriesText)
                            .font(CalorynTheme.numericCaption)
                            .foregroundStyle(row.hasCalories ? CalorynTheme.textPrimary : CalorynTheme.textSecondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func foodDrivers(_ breakdown: HistoryCalorieTrendDayBreakdown) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(breakdown.foodSectionTitle)
                .font(CalorynTheme.sectionEyebrow)
                .foregroundStyle(CalorynTheme.textSecondary)
                .textCase(.uppercase)

            VStack(spacing: 8) {
                ForEach(breakdown.visibleFoods) { food in
                    foodRow(food)
                }

                if let overflowText = breakdown.overflowText {
                    Text(overflowText)
                        .font(CalorynTheme.caption)
                        .foregroundStyle(CalorynTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func unloggedState(_ breakdown: HistoryCalorieTrendDayBreakdown) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "calendar")
                .font(CalorynTheme.inlineIcon)
                .foregroundStyle(CalorynTheme.textSecondary)
                .frame(width: 28)
                .accessibilityHidden(true)

            Text(breakdown.unloggedText)
                .font(CalorynTheme.caption)
                .foregroundStyle(CalorynTheme.textSecondary)
        }
    }

    private func statusBadge(_ status: HistoryGoalStatus) -> some View {
        Text(status.label)
            .font(CalorynTheme.microCaptionEmphasized)
            .foregroundStyle(status.tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.tint.opacity(0.12), in: Capsule())
            .accessibilityLabel(status.label)
    }

    private func foodRow(_ food: HistoryFoodSummary) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(food.name)
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(HistoryCalorieTrendDayBreakdown.entryCountText(food.entryCount))
                    .font(CalorynTheme.microCaption)
                    .foregroundStyle(CalorynTheme.textSecondary)
            }

            Spacer(minLength: 8)

            Text(food.calories.rounded().truncatedSafely.kcalFormatted)
                .font(CalorynTheme.numericCaption)
                .foregroundStyle(CalorynTheme.textPrimary)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct HistoryCalorieTrendSelectedWeekCard: View {
    let projection: HistoryCalorieTrendProjection
    let week: HistoryWeekSummary
    let point: HistoryCalorieTrendPoint
    let topFoods: [HistoryFoodSummary]

    private var breakdown: HistoryCalorieTrendWeekBreakdown {
        HistoryCalorieTrendWeekBreakdown(
            weekStartText: week.startDate.dayMonthFormatted,
            loggedDays: week.loggedDays,
            totalDays: week.totalDays,
            onTrackDays: week.onTrackDays,
            loggedDaySwings: week.days.filter(\.isLogged).map {
                HistoryCalorieTrendWeekBreakdown.DaySwing(
                    dateText: $0.date.shortFormatted,
                    calorieDifference: $0.calorieDifference
                )
            },
            foods: topFoods
        )
    }

    var body: some View {
        let breakdown = breakdown

        return VStack(alignment: .leading, spacing: 14) {
            header(breakdown)

            if breakdown.hasLoggedDays {
                VStack(alignment: .leading, spacing: 6) {
                    Text(projection.targetDeltaText(point.targetDelta, unit: "kcal/day"))
                        .font(CalorynTheme.numericBody)
                        .foregroundStyle(point.status.tint)

                    if let averageDeltaText = projection.averageDeltaText(
                        value: week.averageCaloriesPerLoggedDay,
                        unit: "kcal/day"
                    ) {
                        Text(averageDeltaText)
                            .font(CalorynTheme.caption)
                            .foregroundStyle(CalorynTheme.textSecondary)
                    }
                }

                Divider()
                    .foregroundStyle(CalorynTheme.stone.opacity(0.3))

                HStack(alignment: .top, spacing: 12) {
                    compactMetric(
                        value: breakdown.onTrackRatioText,
                        label: "logged days on track",
                        color: week.consistencyTint
                    )

                    Divider()
                        .foregroundStyle(CalorynTheme.stone.opacity(0.3))
                        .frame(height: 38)

                    compactMetric(
                        value: breakdown.coverageRatioText,
                        label: "days logged"
                    )
                }

                if let biggestSwingText = breakdown.biggestSwingText {
                    Divider()
                        .foregroundStyle(CalorynTheme.stone.opacity(0.3))

                    Text(biggestSwingText)
                        .font(CalorynTheme.caption)
                        .foregroundStyle(CalorynTheme.textSecondary)
                }

                if breakdown.showsFoodSection {
                    Divider()
                        .foregroundStyle(CalorynTheme.stone.opacity(0.3))

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Top Foods")
                            .font(CalorynTheme.sectionEyebrow)
                            .foregroundStyle(CalorynTheme.textSecondary)
                            .textCase(.uppercase)

                        ForEach(breakdown.visibleFoods) { food in
                            foodRow(food)
                        }
                    }
                }
            } else {
                Text(breakdown.emptyText)
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)
            }
        }
        .historyCard()
        .accessibilityElement(children: .contain)
    }

    private func header(_ breakdown: HistoryCalorieTrendWeekBreakdown) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(breakdown.headerText)
                .font(CalorynTheme.itemTitle)
                .foregroundStyle(CalorynTheme.textPrimary)

            Text("Selected week")
                .font(CalorynTheme.caption)
                .foregroundStyle(CalorynTheme.textSecondary)
        }
    }

    private func compactMetric(
        value: String,
        label: String,
        color: Color = CalorynTheme.textPrimary
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(CalorynTheme.numericBody)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(label)
                .font(CalorynTheme.caption)
                .foregroundStyle(CalorynTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func foodRow(_ food: HistoryFoodSummary) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(food.name)
                .font(CalorynTheme.caption)
                .foregroundStyle(CalorynTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 8)

            Text(food.calories.rounded().truncatedSafely.kcalFormatted)
                .font(CalorynTheme.numericCaption)
                .foregroundStyle(CalorynTheme.textPrimary)
        }
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview("Calorie Trend Detail - 7 Days") {
    let history = HistoryPreviewFixtures.analytics(for: .mostlyOnTrack)

    return NavigationStack {
        HistoryCalorieTrendDetailView(
            range: history.range,
            summary: history.current
        )
    }
}

#Preview("Calorie Trend Detail - 90 Days") {
    let history = HistoryPreviewFixtures.analytics(for: .quarterWeekly)

    return NavigationStack {
        HistoryCalorieTrendDetailView(
            range: history.range,
            summary: history.current
        )
    }
}
#endif
