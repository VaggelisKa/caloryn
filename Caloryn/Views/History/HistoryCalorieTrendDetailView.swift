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
        .navigationTitle("Calorie Trend")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct HistoryCalorieTrendRangeSummaryCard: View {
    let projection: HistoryCalorieTrendProjection

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Range Summary")
                .font(CalorynTheme.caption)
                .foregroundStyle(CalorynTheme.textSecondary)
                .textCase(.uppercase)

            HStack(alignment: .top, spacing: 12) {
                metric(
                    value: "\(projection.onTrackLoggedDayCount)/\(projection.loggedDayCount)",
                    label: "logged days on track"
                )

                Divider()
                    .foregroundStyle(CalorynTheme.stone.opacity(0.3))
                    .frame(height: 42)

                metric(
                    value: Int(projection.averageCaloriesPerLoggedDay.rounded()).formatted(),
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
            }
        }
        .glassCard()
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

    private var yAxisUpperBound: Double {
        projection.yAxisUpperBound
    }

    private var barWidth: MarkDimension {
        .fixed(projection.range == .week ? 14 : 10)
    }

    private var xAxisDomain: ClosedRange<Double> {
        guard let firstIndex = projection.points.first?.index,
              let lastIndex = projection.points.last?.index else {
            return 0 ... 1
        }
        return (firstIndex - 0.5) ... (lastIndex + 0.5)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Calories")
                .font(CalorynTheme.caption)
                .foregroundStyle(CalorynTheme.textSecondary)
                .textCase(.uppercase)

            Chart {
                ForEach(projection.points) { point in
                    if point.isLogged {
                        BarMark(
                            x: .value("Period", point.index),
                            y: .value("Calories", point.value),
                            width: barWidth
                        )
                        .foregroundStyle(pointColor(point))
                        .cornerRadius(4)
                        .accessibilityLabel(point.accessibilityLabel)
                        .accessibilityValue(point.accessibilityValue)

                        if selectedPointID == point.id {
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
                           let point = chartPoint(for: index) {
                            Text(point.xAxisLabel)
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
                                        .font(.system(size: 10))
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
                                        width: chartHitTargetWidth(in: plotRect),
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
                        .font(.system(size: 10))
                }
            }
            .chartYScale(domain: 0 ... yAxisUpperBound)
            .chartXScale(domain: xAxisDomain)
            .frame(height: projection.range == .week ? 220 : 240)
            .accessibilityLabel(accessibilityLabel)
        }
        .glassCard()
    }

    private func pointColor(_ point: HistoryCalorieTrendPoint) -> Color {
        if let selectedPointID, selectedPointID != point.id {
            return point.status.tint.opacity(0.48)
        }
        return point.status.tint
    }

    private func chartPoint(for index: Double) -> HistoryCalorieTrendPoint? {
        projection.point(for: index)
    }

    private func chartHitTargetWidth(in plotRect: CGRect) -> CGFloat {
        let count = max(projection.points.count, 1)
        return max(plotRect.width / CGFloat(count), 18)
    }

    private func selectPoint(
        at location: CGPoint,
        plotRect: CGRect,
        proxy: ChartProxy
    ) {
        guard plotRect.contains(location) else { return }

        let localX = location.x - plotRect.minX
        guard let index = proxy.value(atX: localX, as: Double.self),
              let point = chartPoint(for: index) else { return }

        selectedPointID = point.id
    }

    private var accessibilityLabel: String {
        "Detailed calorie trend for \(projection.range.label). \(projection.loggedDayCount) of \(projection.totalDayCount) days logged."
    }
}

private struct HistoryCalorieTrendSelectedAnalysis: View {
    let projection: HistoryCalorieTrendProjection
    let point: HistoryCalorieTrendPoint

    var body: some View {
        switch point.selection {
        case .day(let day):
            HistoryCalorieTrendSelectedDayCard(
                projection: projection,
                detail: day.makeDetail(),
                topFoods: projection.topFoods(for: point.selection)
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
    let topFoods: [HistoryFoodSummary]

    private var visibleFoods: [HistoryFoodSummary] {
        Array(topFoods.prefix(3))
    }

    private var mealRows: [HistoryCalorieTrendMealRow] {
        MealType.allCases.map { mealType in
            let meal = detail.mealSummaries.first { $0.mealType == mealType }
            return HistoryCalorieTrendMealRow(
                id: mealType.id,
                title: mealType == .snack ? "Snacks" : mealType.displayName,
                iconName: mealType.iconName,
                calories: meal?.calories ?? 0
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if detail.isLogged {
                metricStack
                Divider()
                    .foregroundStyle(CalorynTheme.stone.opacity(0.3))
                mealSplit

                if !visibleFoods.isEmpty {
                    Divider()
                        .foregroundStyle(CalorynTheme.stone.opacity(0.3))
                    foodDrivers
                }
            } else {
                unloggedState
            }
        }
        .glassCard()
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
        }
    }

    private var mealSplit: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Meal Split")
                .font(CalorynTheme.caption)
                .foregroundStyle(CalorynTheme.textSecondary)
                .textCase(.uppercase)

            VStack(spacing: 8) {
                ForEach(mealRows) { row in
                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: row.iconName)
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(row.calories > 0 ? CalorynTheme.sage : CalorynTheme.textSecondary)
                            .frame(width: 20)
                            .accessibilityHidden(true)

                        Text(row.title)
                            .font(CalorynTheme.caption)
                            .foregroundStyle(CalorynTheme.textPrimary)

                        Spacer()

                        Text(row.calories > 0 ? Int(row.calories.rounded()).kcalFormatted : "none")
                            .font(CalorynTheme.numericCaption)
                            .foregroundStyle(row.calories > 0 ? CalorynTheme.textPrimary : CalorynTheme.textSecondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private var foodDrivers: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(detail.calorieDifference > 0 ? "Top Contributors" : "Foods Logged")
                .font(CalorynTheme.caption)
                .foregroundStyle(CalorynTheme.textSecondary)
                .textCase(.uppercase)

            VStack(spacing: 8) {
                ForEach(visibleFoods) { food in
                    foodRow(food)
                }

                if topFoods.count > visibleFoods.count {
                    Text("+ \(topFoods.count - visibleFoods.count) more")
                        .font(CalorynTheme.caption)
                        .foregroundStyle(CalorynTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var unloggedState: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(CalorynTheme.textSecondary)
                .frame(width: 28)
                .accessibilityHidden(true)

            Text("No food logged. Target was \(detail.dailyCalorieTarget.formatted()) kcal.")
                .font(CalorynTheme.caption)
                .foregroundStyle(CalorynTheme.textSecondary)
        }
    }

    private func statusBadge(_ status: HistoryGoalStatus) -> some View {
        Text(status.label)
            .font(.system(.caption2, design: .rounded, weight: .semibold))
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

                Text("\(food.entryCount) \(food.entryCount == 1 ? "entry" : "entries")")
                    .font(.system(.caption2))
                    .foregroundStyle(CalorynTheme.textSecondary)
            }

            Spacer(minLength: 8)

            Text(Int(food.calories.rounded()).kcalFormatted)
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

    private var biggestDay: HistoryDaySummary? {
        week.days.filter(\.isLogged).max {
            abs($0.calorieDifference) < abs($1.calorieDifference)
        }
    }

    private var visibleFoods: [HistoryFoodSummary] {
        Array(topFoods.prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if week.loggedDays > 0 {
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
                        value: "\(week.onTrackDays)/\(week.loggedDays)",
                        label: "logged days on track",
                        color: week.consistencyTint
                    )

                    Divider()
                        .foregroundStyle(CalorynTheme.stone.opacity(0.3))
                        .frame(height: 38)

                    compactMetric(
                        value: "\(week.loggedDays)/\(week.totalDays)",
                        label: "days logged"
                    )
                }

                if let biggestDay {
                    Divider()
                        .foregroundStyle(CalorynTheme.stone.opacity(0.3))

                    Text("Biggest swing: \(biggestDay.date.shortFormatted), \(HistoryCalorieTrendProjection.deltaText(biggestDay.calorieDifference, unit: "kcal"))")
                        .font(CalorynTheme.caption)
                        .foregroundStyle(CalorynTheme.textSecondary)
                }

                if !visibleFoods.isEmpty {
                    Divider()
                        .foregroundStyle(CalorynTheme.stone.opacity(0.3))

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Top Foods")
                            .font(CalorynTheme.caption)
                            .foregroundStyle(CalorynTheme.textSecondary)
                            .textCase(.uppercase)

                        ForEach(visibleFoods) { food in
                            foodRow(food)
                        }
                    }
                }
            } else {
                Text("No food logged in this week.")
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)
            }
        }
        .glassCard()
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Week of \(week.startDate.dayMonthFormatted)")
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

            Text(Int(food.calories.rounded()).kcalFormatted)
                .font(CalorynTheme.numericCaption)
                .foregroundStyle(CalorynTheme.textPrimary)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct HistoryCalorieTrendMealRow: Identifiable {
    let id: String
    let title: String
    let iconName: String
    let calories: Double
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
