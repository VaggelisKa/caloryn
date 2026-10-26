import SwiftUI
import Charts

struct HistoryCalorieTrendDetailView: View {
    let range: HistoryRange
    let summary: HistoryPeriodSummary

    @State private var selectedPointID: String?

    init(
        range: HistoryRange,
        summary: HistoryPeriodSummary,
        initialSelectedPointID: String? = nil
    ) {
        self.range = range
        self.summary = summary
        _selectedPointID = State(initialValue: initialSelectedPointID)
    }

    var body: some View {
        let projection = HistoryCalorieTrendProjection(
            range: range,
            summary: summary
        )
        let selectedPoint = projection.points.first { $0.id == selectedPointID }

        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                HistoryCalorieTrendRangeSummary(
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
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .historyDebugScrollAnchor()
        .calorynPageCanvas()
        .calorynDrillDownNavigation()
        .calorynInlineTitle("Calorie trend")
        .accessibilityIdentifier("history.calorieTrend.details")
    }
}

private struct HistoryCalorieTrendRangeSummary: View {
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

        return VStack(alignment: .leading, spacing: 12) {
            HistorySectionTitle("Range summary")

            HStack(alignment: .top, spacing: 16) {
                HistoryDetailMetric(
                    value: summary.onTrackRatioText,
                    label: "logged days on track"
                )

                HistoryDetailMetric(
                    value: summary.averageValueText,
                    label: "kcal a day on average"
                )
            }

            HistoryHairline()

            VStack(alignment: .leading, spacing: 6) {
                summaryLine(projection.totalTargetDeltaText)

                if let biggestInconsistencyText = projection.biggestInconsistencyText {
                    summaryLine(biggestInconsistencyText)
                }

                if let estimatedTargetNoteText = projection.estimatedTargetNoteText {
                    summaryLine(estimatedTargetNoteText)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func summaryLine(_ text: String) -> some View {
        Text(text)
            .font(CalorynTheme.cardSubtitle)
            .foregroundStyle(CalorynTheme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct HistoryDetailMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(CalorynTheme.compactNumber)
                .foregroundStyle(CalorynTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(label)
                .font(CalorynTheme.caption)
                .foregroundStyle(CalorynTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            HistorySectionTitle("Calories")

            Chart {
                ForEach(projection.points) { point in
                    if point.isLogged {
                        BarMark(
                            x: .value("Period", point.index),
                            y: .value("Calories", point.value),
                            width: .fixed(layout.barWidth)
                        )
                        .foregroundStyle(point.status.tint)
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
                                    .stroke(CalorynTheme.accent, lineWidth: 2)
                                    .background(Circle().fill(CalorynTheme.backgroundPrimary))
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
                    .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [4, 3]))
                    .foregroundStyle(CalorynTheme.dataReference)
            }
            .chartXAxis {
                AxisMarks(values: projection.points.map(\.index)) { value in
                    AxisValueLabel(centered: false) {
                        if let index = value.as(Double.self),
                           let point = projection.point(for: index) {
                            Text(point.xAxisLabel)
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
                                        .font(CalorynTheme.trendChartXAxisLabel(pointCount: projection.points.count))
                                        .foregroundStyle(
                                            point.id == selectedPointID
                                                ? CalorynTheme.textPrimary
                                                : CalorynTheme.textSecondary
                                        )
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
                        .foregroundStyle(CalorynTheme.separator)
                    AxisValueLabel()
                        .font(CalorynTheme.chartAxisLabel)
                        .foregroundStyle(CalorynTheme.textSecondary)
                }
            }
            .chartYScale(domain: 0 ... projection.yAxisUpperBound)
            .chartXScale(domain: layout.xAxisDomain)
            .frame(height: layout.chartHeight)
            .padding(.bottom, 8)
            .accessibilityLabel(
                HistoryCalorieTrendCardSummary.detailChartAccessibilityLabel(
                    range: projection.range,
                    loggedDayCount: projection.loggedDayCount,
                    totalDayCount: projection.totalDayCount
                )
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func emphasis(
        _ point: HistoryCalorieTrendPoint
    ) -> HistoryCalorieTrendChartLayout.BarEmphasis {
        HistoryCalorieTrendChartLayout.barEmphasis(
            pointID: point.id,
            selectedPointID: selectedPointID
        )
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
            HistoryCalorieTrendSelectedDay(
                projection: projection,
                detail: detail
            )
        case .week(let week):
            HistoryCalorieTrendSelectedWeek(
                projection: projection,
                week: week,
                point: point,
                topFoods: projection.topFoods(for: point.selection)
            )
        }
    }
}

private struct HistorySelectionHeader: View {
    let title: String
    let caption: String
    let status: HistoryGoalStatus?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HistorySectionTitle(title)

                Text(caption)
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)
            }

            Spacer(minLength: 8)

            if let status {
                HistoryStatusBadge(status: status)
            }
        }
    }
}

private struct HistoryDetailRow: View {
    let title: String
    var titleColor: Color = CalorynTheme.textPrimary
    var titleFont: Font = CalorynTheme.cardSubtitle
    var caption: String?
    let value: String
    var valueColor: Color = CalorynTheme.textPrimary

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(titleFont)
                    .foregroundStyle(titleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if let caption {
                    Text(caption)
                        .font(CalorynTheme.caption)
                        .foregroundStyle(CalorynTheme.textSecondary)
                }
            }

            Spacer(minLength: 8)

            Text(value)
                .font(CalorynTheme.cardSubtitle.weight(.semibold).monospacedDigit())
                .foregroundStyle(valueColor)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}

private struct HistoryHairlineRows<Item: Identifiable, Row: View>: View {
    let items: [Item]
    @ViewBuilder let row: (Item) -> Row

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(items) { item in
                row(item)

                if item.id != items.last?.id {
                    HistoryHairline()
                }
            }
        }
    }
}

private struct HistoryCalorieTrendSelectedDay: View {
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
            HistorySelectionHeader(
                title: projection.dayText(for: detail.date),
                caption: "Selected day",
                status: detail.status
            )

            if breakdown.isLogged {
                metricStack
                mealSplit(breakdown)

                if breakdown.showsFoodSection {
                    foodDrivers(breakdown)
                }
            } else {
                Text(breakdown.unloggedText)
                    .font(CalorynTheme.cardSubtitle)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    private var metricStack: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(projection.targetDeltaText(detail.calorieDifference, unit: "kcal"))
                .font(CalorynTheme.compactNumber)
                .foregroundStyle(CalorynTheme.textPrimary)

            if let averageDeltaText = projection.averageDeltaText(
                value: detail.calories,
                unit: "kcal"
            ) {
                Text(averageDeltaText)
                    .font(CalorynTheme.cardSubtitle)
                    .foregroundStyle(CalorynTheme.textSecondary)
            }

            if detail.isTargetEstimated {
                Text("Compared with the goal in effect around this day — none was saved for it.")
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func mealSplit(_ breakdown: HistoryCalorieTrendDayBreakdown) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Meal split")
                .font(CalorynTheme.cardSubtitle.weight(.bold))
                .foregroundStyle(CalorynTheme.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 6)

            HistoryHairlineRows(items: breakdown.mealRows) { row in
                HistoryDetailRow(
                    title: row.title,
                    titleColor: row.mealType.ink,
                    titleFont: CalorynTheme.cardSubtitle.weight(.semibold),
                    value: row.caloriesText,
                    valueColor: row.hasCalories ? CalorynTheme.textPrimary : CalorynTheme.textTertiary
                )
            }
        }
    }

    private func foodDrivers(_ breakdown: HistoryCalorieTrendDayBreakdown) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(breakdown.foodSectionTitle)
                .font(CalorynTheme.cardSubtitle.weight(.bold))
                .foregroundStyle(CalorynTheme.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 6)

            HistoryHairlineRows(items: breakdown.visibleFoods) { food in
                HistoryDetailRow(
                    title: food.name,
                    caption: HistoryCalorieTrendDayBreakdown.entryCountText(food.entryCount),
                    value: food.calories.rounded().truncatedSafely.kcalFormatted
                )
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

private struct HistoryCalorieTrendSelectedWeek: View {
    let projection: HistoryCalorieTrendProjection
    let week: HistoryWeekSummary
    let point: HistoryCalorieTrendPoint
    let topFoods: [HistoryFoodSummary]

    private var breakdown: HistoryCalorieTrendWeekBreakdown {
        HistoryCalorieTrendWeekBreakdown(
            weekStartText: projection.weekStartText(for: week.startDate),
            loggedDays: week.loggedDays,
            totalDays: week.totalDays,
            onTrackDays: week.onTrackDays,
            loggedDaySwings: week.days.filter(\.isLogged).map {
                HistoryCalorieTrendWeekBreakdown.DaySwing(
                    dateText: projection.dayText(for: $0.date),
                    calorieDifference: $0.calorieDifference
                )
            },
            foods: topFoods
        )
    }

    var body: some View {
        let breakdown = breakdown

        return VStack(alignment: .leading, spacing: 14) {
            HistorySelectionHeader(
                title: breakdown.headerText,
                caption: "Selected week",
                status: breakdown.hasLoggedDays ? point.status : nil
            )

            if breakdown.hasLoggedDays {
                VStack(alignment: .leading, spacing: 4) {
                    Text(projection.targetDeltaText(point.targetDelta, unit: "kcal/day"))
                        .font(CalorynTheme.compactNumber)
                        .foregroundStyle(CalorynTheme.textPrimary)

                    if let averageDeltaText = projection.averageDeltaText(
                        value: week.averageCaloriesPerLoggedDay,
                        unit: "kcal/day"
                    ) {
                        Text(averageDeltaText)
                            .font(CalorynTheme.cardSubtitle)
                            .foregroundStyle(CalorynTheme.textSecondary)
                    }
                }

                HStack(alignment: .top, spacing: 16) {
                    HistoryDetailMetric(
                        value: breakdown.onTrackRatioText,
                        label: "logged days on track"
                    )

                    HistoryDetailMetric(
                        value: breakdown.coverageRatioText,
                        label: "days logged"
                    )
                }

                if let biggestSwingText = breakdown.biggestSwingText {
                    Text(biggestSwingText)
                        .font(CalorynTheme.cardSubtitle)
                        .foregroundStyle(CalorynTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if breakdown.showsFoodSection {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Top foods")
                            .font(CalorynTheme.cardSubtitle.weight(.bold))
                            .foregroundStyle(CalorynTheme.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                            .padding(.top, 6)

                        HistoryHairlineRows(items: breakdown.visibleFoods) { food in
                            HistoryDetailRow(
                                title: food.name,
                                value: food.calories.rounded().truncatedSafely.kcalFormatted
                            )
                        }
                    }
                }
            } else {
                Text(breakdown.emptyText)
                    .font(CalorynTheme.cardSubtitle)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
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
