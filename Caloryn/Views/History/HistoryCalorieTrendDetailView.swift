import SwiftUI
import Charts

struct HistoryCalorieTrendDetailView: View {
    let range: HistoryRange
    let summary: HistoryPeriodSummary

    @State private var selectedPointID: String?

    private var chartPoints: [HistoryCalorieTrendDetailPoint] {
        HistoryCalorieTrendDetailPoint.points(
            range: range,
            summary: summary
        )
    }

    private var selectedPoint: HistoryCalorieTrendDetailPoint? {
        chartPoints.first { $0.id == selectedPointID }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: CalorynTheme.cardSpacing) {
                HistoryCalorieTrendRangeSummaryCard(
                    range: range,
                    summary: summary
                )

                HistoryCalorieTrendInteractiveChart(
                    range: range,
                    summary: summary,
                    points: chartPoints,
                    selectedPointID: $selectedPointID
                )

                if let selectedPoint {
                    HistoryCalorieTrendSelectedAnalysis(
                        range: range,
                        summary: summary,
                        selection: selectedPoint.selection
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

private struct HistoryCalorieTrendDetailPoint: Identifiable {
    let id: String
    let index: Double
    let value: Double
    let targetDelta: Int
    let status: HistoryGoalStatus
    let isLogged: Bool
    let xAxisLabel: String
    let accessibilityLabel: String
    let accessibilityValue: String
    let selection: HistoryCalorieTrendSelection

    static func points(
        range: HistoryRange,
        summary: HistoryPeriodSummary
    ) -> [HistoryCalorieTrendDetailPoint] {
        if range == .quarter {
            return summary.weeklyRollups.enumerated().map { offset, week in
                let averageCalories = week.averageCaloriesPerLoggedDay
                let status = weeklyStatus(
                    averageCalories: averageCalories,
                    loggedDayCount: week.loggedDays,
                    dailyCalorieTarget: summary.dailyCalorieTarget
                )
                let label = "W\(offset + 1)"

                return HistoryCalorieTrendDetailPoint(
                    id: "week-\(week.id.ISO8601Format())",
                    index: Double(offset),
                    value: averageCalories,
                    targetDelta: Int(averageCalories.rounded()) - summary.dailyCalorieTarget,
                    status: status,
                    isLogged: week.loggedDays > 0,
                    xAxisLabel: label,
                    accessibilityLabel: "\(label), week of \(week.startDate.dayMonthFormatted)",
                    accessibilityValue: week.loggedDays == 0
                        ? "No calories logged"
                        : "\(Int(averageCalories.rounded())) average calories per logged day, \(status.label)",
                    selection: .week(week)
                )
            }
        }

        return summary.days.enumerated().map { offset, day in
            HistoryCalorieTrendDetailPoint(
                id: "day-\(day.id.ISO8601Format())",
                index: Double(offset),
                value: day.calories,
                targetDelta: day.detail.calorieDifference,
                status: day.status,
                isLogged: day.isLogged,
                xAxisLabel: weekdayInitial(for: day.date),
                accessibilityLabel: day.date.shortFormatted,
                accessibilityValue: day.isLogged
                    ? "\(Int(day.calories.rounded())) calories, \(day.status.label)"
                    : "No calories logged",
                selection: .day(day.detail)
            )
        }
    }

    private static func weekdayInitial(for date: Date) -> String {
        let weekday = Calendar.current.component(.weekday, from: date)
        return ["S", "M", "T", "W", "T", "F", "S"][max(0, min(weekday - 1, 6))]
    }

    private static func weeklyStatus(
        averageCalories: Double,
        loggedDayCount: Int,
        dailyCalorieTarget: Int
    ) -> HistoryGoalStatus {
        guard loggedDayCount > 0 else { return .notLogged }
        guard dailyCalorieTarget > 0 else { return .onTrack }

        let target = Double(dailyCalorieTarget)
        if averageCalories < target * (1 - HistoryAnalytics.onTrackTolerance) {
            return .under
        }
        if averageCalories > target * (1 + HistoryAnalytics.onTrackTolerance) {
            return .over
        }
        return .onTrack
    }
}

private struct HistoryCalorieTrendRangeSummaryCard: View {
    let range: HistoryRange
    let summary: HistoryPeriodSummary

    private var loggedDays: [HistoryDaySummary] {
        summary.days.filter(\.isLogged)
    }

    private var totalCalories: Double {
        loggedDays.reduce(0) { $0 + $1.calories }
    }

    private var totalTargetDelta: Int {
        Int(totalCalories.rounded()) - summary.dailyCalorieTarget * loggedDays.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Range Summary")
                .font(CalorynTheme.caption)
                .foregroundStyle(CalorynTheme.textSecondary)
                .textCase(.uppercase)

            HStack(alignment: .top, spacing: 12) {
                metric(
                    value: "\(summary.onTrackLoggedDayCount)/\(summary.loggedDayCount)",
                    label: "logged days on track"
                )

                Divider()
                    .foregroundStyle(CalorynTheme.stone.opacity(0.3))
                    .frame(height: 42)

                metric(
                    value: Int(summary.averageCaloriesPerLoggedDay.rounded()).formatted(),
                    label: "kcal/day avg"
                )
            }

            Divider()
                .foregroundStyle(CalorynTheme.stone.opacity(0.3))

            VStack(alignment: .leading, spacing: 8) {
                summaryLine(totalDeltaText)

                if let biggestInconsistencyText {
                    summaryLine(biggestInconsistencyText)
                }
            }
        }
        .glassCard()
        .accessibilityElement(children: .combine)
    }

    private var totalDeltaText: String {
        if totalTargetDelta == 0 { return "On target total" }
        return "\(HistoryCalorieTrendText.delta(totalTargetDelta, unit: "kcal")) target total"
    }

    private var biggestInconsistencyText: String? {
        switch range {
        case .quarter:
            let loggedWeeks = summary.weeklyRollups.filter { $0.loggedDays > 0 }
            guard let week = loggedWeeks.max(by: { lhs, rhs in
                abs(weeklyDelta(lhs)) < abs(weeklyDelta(rhs))
            }) else {
                return nil
            }

            if loggedWeeks.allSatisfy({ weeklyStatus(for: $0) == .onTrack }) {
                return "Most stable: logged weeks stayed near target"
            }

            return "Biggest swing: week of \(week.startDate.dayMonthFormatted), \(HistoryCalorieTrendText.delta(weeklyDelta(week), unit: "kcal/day"))"

        case .week, .twoWeeks, .month:
            guard let day = loggedDays.max(by: { lhs, rhs in
                abs(lhs.detail.calorieDifference) < abs(rhs.detail.calorieDifference)
            }) else {
                return nil
            }

            if loggedDays.allSatisfy({ $0.status == .onTrack }) {
                return "Most stable: logged days stayed near target"
            }

            return "Biggest swing: \(day.date.shortFormatted), \(HistoryCalorieTrendText.delta(day.detail.calorieDifference, unit: "kcal"))"
        }
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

    private func weeklyDelta(_ week: HistoryWeekSummary) -> Int {
        Int(week.averageCaloriesPerLoggedDay.rounded()) - summary.dailyCalorieTarget
    }

    private func weeklyStatus(for week: HistoryWeekSummary) -> HistoryGoalStatus {
        guard week.loggedDays > 0 else { return .notLogged }
        guard summary.dailyCalorieTarget > 0 else { return .onTrack }

        let target = Double(summary.dailyCalorieTarget)
        if week.averageCaloriesPerLoggedDay < target * (1 - HistoryAnalytics.onTrackTolerance) {
            return .under
        }
        if week.averageCaloriesPerLoggedDay > target * (1 + HistoryAnalytics.onTrackTolerance) {
            return .over
        }
        return .onTrack
    }
}

private struct HistoryCalorieTrendInteractiveChart: View {
    let range: HistoryRange
    let summary: HistoryPeriodSummary
    let points: [HistoryCalorieTrendDetailPoint]

    @Binding var selectedPointID: String?

    private var yAxisUpperBound: Double {
        let largestChartValue = points.map(\.value).max() ?? 0
        let largestReference = max(largestChartValue, Double(summary.dailyCalorieTarget), summary.averageCaloriesPerLoggedDay, 1)
        return largestReference * 1.15
    }

    private var barWidth: MarkDimension {
        .fixed(range == .week ? 14 : 10)
    }

    private var xAxisDomain: ClosedRange<Double> {
        guard let firstIndex = points.first?.index,
              let lastIndex = points.last?.index else {
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
                ForEach(points) { point in
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

                RuleMark(y: .value("Target", summary.dailyCalorieTarget))
                    .lineStyle(StrokeStyle(lineWidth: 1.8, lineCap: .round))
                    .foregroundStyle(CalorynTheme.textPrimary.opacity(0.62))
            }
            .chartXAxis {
                AxisMarks(values: points.map(\.index)) { value in
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

                            ForEach(points) { point in
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
            .frame(height: range == .week ? 220 : 240)
            .accessibilityLabel(accessibilityLabel)
        }
        .glassCard()
    }

    private func pointColor(_ point: HistoryCalorieTrendDetailPoint) -> Color {
        if let selectedPointID, selectedPointID != point.id {
            return point.status.tint.opacity(0.48)
        }
        return point.status.tint
    }

    private func chartPoint(for index: Double) -> HistoryCalorieTrendDetailPoint? {
        let roundedIndex = Int(index.rounded())
        guard points.indices.contains(roundedIndex) else { return nil }
        return points[roundedIndex]
    }

    private func chartHitTargetWidth(in plotRect: CGRect) -> CGFloat {
        let count = max(points.count, 1)
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
        "Detailed calorie trend for \(range.label). \(summary.loggedDayCount) of \(summary.totalDayCount) days logged."
    }
}

private struct HistoryCalorieTrendSelectedAnalysis: View {
    let range: HistoryRange
    let summary: HistoryPeriodSummary
    let selection: HistoryCalorieTrendSelection

    var body: some View {
        switch selection {
        case .day(let detail):
            HistoryCalorieTrendSelectedDayCard(
                range: range,
                summary: summary,
                detail: detail
            )
        case .week(let week):
            HistoryCalorieTrendSelectedWeekCard(
                range: range,
                summary: summary,
                week: week
            )
        }
    }
}

private struct HistoryCalorieTrendSelectedDayCard: View {
    let range: HistoryRange
    let summary: HistoryPeriodSummary
    let detail: HistoryDayDetail

    private var visibleFoods: [HistoryFoodSummary] {
        Array(detail.topFoods.prefix(3))
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
            Text(HistoryCalorieTrendText.targetDelta(detail.calorieDifference, unit: "kcal"))
                .font(CalorynTheme.numericBody)
                .foregroundStyle(detail.status.tint)

            if let averageDeltaText = HistoryCalorieTrendText.averageDelta(
                value: detail.calories,
                average: summary.averageCaloriesPerLoggedDay,
                range: range,
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

                if detail.topFoods.count > visibleFoods.count {
                    Text("+ \(detail.topFoods.count - visibleFoods.count) more")
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
    let range: HistoryRange
    let summary: HistoryPeriodSummary
    let week: HistoryWeekSummary

    private var weeklyDelta: Int {
        Int(week.averageCaloriesPerLoggedDay.rounded()) - summary.dailyCalorieTarget
    }

    private var biggestDay: HistoryDaySummary? {
        week.days.filter(\.isLogged).max {
            abs($0.detail.calorieDifference) < abs($1.detail.calorieDifference)
        }
    }

    private var visibleFoods: [HistoryFoodSummary] {
        Array(weekTopFoods.prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if week.loggedDays > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    Text(HistoryCalorieTrendText.targetDelta(weeklyDelta, unit: "kcal/day"))
                        .font(CalorynTheme.numericBody)
                        .foregroundStyle(statusTint)

                    if let averageDeltaText = HistoryCalorieTrendText.averageDelta(
                        value: week.averageCaloriesPerLoggedDay,
                        average: summary.averageCaloriesPerLoggedDay,
                        range: range,
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

                    Text("Biggest swing: \(biggestDay.date.shortFormatted), \(HistoryCalorieTrendText.delta(biggestDay.detail.calorieDifference, unit: "kcal"))")
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

    private var statusTint: Color {
        guard week.loggedDays > 0 else { return CalorynTheme.textSecondary }
        guard summary.dailyCalorieTarget > 0 else { return CalorynTheme.sage }

        let target = Double(summary.dailyCalorieTarget)
        if week.averageCaloriesPerLoggedDay < target * (1 - HistoryAnalytics.onTrackTolerance) {
            return HistoryGoalStatus.under.tint
        }
        if week.averageCaloriesPerLoggedDay > target * (1 + HistoryAnalytics.onTrackTolerance) {
            return HistoryGoalStatus.over.tint
        }
        return HistoryGoalStatus.onTrack.tint
    }

    private var weekTopFoods: [HistoryFoodSummary] {
        var foods: [String: HistoryCalorieTrendFoodAccumulator] = [:]

        for day in week.days where day.isLogged {
            for food in day.detail.topFoods {
                var accumulator = foods[food.id] ?? HistoryCalorieTrendFoodAccumulator(id: food.id, name: food.name)
                accumulator.entryCount += food.entryCount
                accumulator.portionGrams += food.portionGrams
                accumulator.calories += food.calories
                foods[food.id] = accumulator
            }
        }

        return foods.values
            .map(\.summary)
            .sorted {
                if $0.calories == $1.calories {
                    return $0.name.localizedStandardCompare($1.name) == .orderedAscending
                }
                return $0.calories > $1.calories
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

private struct HistoryCalorieTrendFoodAccumulator {
    let id: String
    let name: String
    var entryCount = 0
    var portionGrams: Double = 0
    var calories: Double = 0

    var summary: HistoryFoodSummary {
        HistoryFoodSummary(
            id: id,
            name: name,
            entryCount: entryCount,
            portionGrams: portionGrams,
            calories: calories
        )
    }
}

private enum HistoryCalorieTrendText {
    static func targetDelta(_ difference: Int, unit: String) -> String {
        if difference == 0 { return "On target" }
        return "\(delta(difference, unit: unit)) target"
    }

    static func delta(_ difference: Int, unit: String) -> String {
        if difference == 0 { return "On target" }
        return "\(abs(difference).formatted()) \(unit) \(difference > 0 ? "over" : "under")"
    }

    static func averageDelta(
        value: Double,
        average: Double,
        range: HistoryRange,
        unit: String
    ) -> String? {
        guard average > 0 else { return nil }

        let difference = Int((value - average).rounded())
        if difference == 0 {
            return "Matches \(averageLabel(for: range)) average"
        }

        return "\(abs(difference).formatted()) \(unit) \(difference > 0 ? "above" : "below") \(averageLabel(for: range)) average"
    }

    private static func averageLabel(for range: HistoryRange) -> String {
        switch range {
        case .week:
            "7-day"
        case .twoWeeks:
            "14-day"
        case .month:
            "30-day"
        case .quarter:
            "90-day"
        }
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
