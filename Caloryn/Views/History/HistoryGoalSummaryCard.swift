import SwiftUI

struct HistoryGoalSummaryCard: View {
    let range: HistoryRange
    let summary: HistoryPeriodSummary
    let comparison: HistoryGoalComparison

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            statusStrip
            metricRow

            if summary.loggedDayCount > 0, summary.coverageLevel != .high {
                Text("Based on \(summary.loggedDayCount) of \(summary.totalDayCount) days logged.")
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)
            }
        }
        .historyCard()
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Goal Consistency")
                .font(CalorynTheme.sectionEyebrow)
                .foregroundStyle(CalorynTheme.textSecondary)
                .textCase(.uppercase)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(summary.onTrackLoggedDayCount)")
                    .font(CalorynTheme.largeNumber)
                    .foregroundStyle(CalorynTheme.textPrimary)
                    .contentTransition(.numericText())

                Text(summary.onTrackLoggedDayCount == 1 ? "day on track" : "days on track")
                    .font(CalorynTheme.itemTitle)
                    .foregroundStyle(CalorynTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if summary.loggedDayCount > 0 {
                Text(loggedDaySupportText)
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)

                Text(comparisonText)
                    .font(CalorynTheme.numericCaption)
                    .foregroundStyle(comparisonColor)
            }
        }
    }

    @ViewBuilder
    private var statusStrip: some View {
        if range == .quarter {
            WeeklyConsistencyStrip(weeks: summary.weeklyRollups)
        } else {
            DailyConsistencyStrip(days: summary.days)
        }
    }

    private var metricRow: some View {
        HStack(alignment: .top, spacing: 14) {
            compactMetric(
                value: "\(summary.loggedDayCount)/\(summary.totalDayCount)",
                label: "days logged"
            )

            if summary.loggedDayCount > 0 {
                Divider()
                    .frame(height: 34)

                compactMetric(
                    value: "\(summary.averageCaloriesPerLoggedDay.rounded().truncatedSafely)",
                    label: "kcal/day avg"
                )
            }

            if summary.loggedDayCount > 0 {
                Divider()
                    .frame(height: 34)

                compactMetric(
                    value: summary.coverageLevel.label.replacingOccurrences(of: " confidence", with: ""),
                    label: "coverage"
                )
            }
        }
    }

    private var loggedDaySupportText: String {
        let dayLabel = summary.loggedDayCount == 1 ? "day" : "days"
        return "of \(summary.loggedDayCount) logged \(dayLabel)"
    }

    private func compactMetric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(CalorynTheme.numericBody)
                .foregroundStyle(CalorynTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(label)
                .font(CalorynTheme.caption)
                .foregroundStyle(CalorynTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var comparisonText: String {
        if comparison.onTrackDayDelta > 0 {
            return "+\(comparison.onTrackDayDelta) on-track days vs previous \(range.label.lowercased())"
        }
        if comparison.onTrackDayDelta < 0 {
            return "\(abs(comparison.onTrackDayDelta)) fewer on-track days vs previous \(range.label.lowercased())"
        }
        return "Same on-track count as previous \(range.label.lowercased())"
    }

    private var comparisonColor: Color {
        if comparison.onTrackDayDelta > 0 { return CalorynTheme.sage }
        if comparison.onTrackDayDelta < 0 { return CalorynTheme.terracotta }
        return CalorynTheme.textSecondary
    }
}

private struct DailyConsistencyStrip: View {
    let days: [HistoryDaySummary]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(days) { day in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(day.status.tint)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
            }
        }
        .frame(height: 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        // The strip is 14pt tall by design; widening only the accessibility shape clears
        // the minimum hit target without moving anything on screen.
        .contentShape(.accessibility, Rectangle().inset(by: -15))
    }

    private var accessibilityLabel: String {
        let counts = Dictionary(grouping: days, by: \.status).mapValues(\.count)
        return "Goal consistency: \(counts[.under, default: 0]) under, \(counts[.onTrack, default: 0]) on track, \(counts[.over, default: 0]) over, \(counts[.notLogged, default: 0]) not logged."
    }
}

private struct WeeklyConsistencyStrip: View {
    let weeks: [HistoryWeekSummary]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(weeks) { week in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(week.consistencyTint)
                    .opacity(max(0.35, week.coverageRatio))
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
            }
        }
        .frame(height: 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        // The strip is 14pt tall by design; widening only the accessibility shape clears
        // the minimum hit target without moving anything on screen.
        .contentShape(.accessibility, Rectangle().inset(by: -15))
    }

    private var accessibilityLabel: String {
        let weekDescriptions = weeks.map {
            "\(($0.onTrackRatio * 100).rounded().truncatedSafely) percent on track, \($0.loggedDays) of \($0.totalDays) days logged"
        }
        return "Weekly goal consistency: \(weekDescriptions.joined(separator: "; "))."
    }
}
