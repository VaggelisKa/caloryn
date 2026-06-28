import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query private var allEntries: [FoodLogEntry]
    @Query(sort: \UserProfile.updatedAt, order: .reverse) private var profiles: [UserProfile]

    @State private var selectedRange: HistoryRange = .week

    init(initialRange: HistoryRange = .week) {
        _selectedRange = State(initialValue: initialRange)
    }

    private var profile: UserProfile? { profiles.first }

    private var analytics: HistoryAnalytics {
        HistoryAnalytics(
            entries: allEntries,
            profile: profile,
            range: selectedRange
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                let history = analytics

                VStack(spacing: CalorynTheme.cardSpacing) {
                    rangePicker

                    if selectedRange == .week {
                        HistoryCalorieTrendCard(
                            range: selectedRange,
                            summary: history.current
                        )
                    }

                    HistoryGoalSummaryCard(
                        range: selectedRange,
                        summary: history.current,
                        comparison: history.goalComparison
                    )

                    if selectedRange == .twoWeeks {
                        HistoryCalorieTrendCard(
                            range: selectedRange,
                            summary: history.current
                        )
                    }

                    if selectedRange.days >= HistoryRange.month.days {
                        HistoryWeeklyRollupCard(summary: history.current)
                    }

                    if !history.macroPatterns.isEmpty {
                        HistoryMacroPatternsCard(patterns: history.macroPatterns)
                    }

                    if selectedRange.days <= HistoryRange.twoWeeks.days {
                        dailyRows(summary: history.current)
                    }
                }
                .padding(.horizontal, CalorynTheme.pagePadding)
                .padding(.bottom, 20)
            }
            .navigationTitle("History")
        }
    }

    private var rangePicker: some View {
        Picker("Range", selection: $selectedRange) {
            ForEach(HistoryRange.allCases) { range in
                Text(range.label).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .padding(.top, 4)
    }

    private func dailyRows(summary: HistoryPeriodSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Daily Detail")
                .font(CalorynTheme.caption)
                .foregroundStyle(CalorynTheme.textSecondary)
                .textCase(.uppercase)
                .padding(.horizontal, 2)

            ForEach(summary.days.reversed()) { day in
                DaySummaryRow(
                    date: day.date,
                    totalCalories: day.calories,
                    target: summary.dailyCalorieTarget,
                    entryCount: day.entryCount
                )
            }
        }
    }
}

#if DEBUG
#Preview("History - Empty") {
    HistoryPreviewFixtures.preview(for: .empty)
}

#Preview("History - Low Coverage") {
    HistoryPreviewFixtures.preview(for: .lowCoverage)
}

#Preview("History - Mostly On Track") {
    HistoryPreviewFixtures.preview(for: .mostlyOnTrack)
}

#Preview("History - Mostly Under") {
    HistoryPreviewFixtures.preview(for: .mostlyUnder)
}

#Preview("History - Mostly Over") {
    HistoryPreviewFixtures.preview(for: .mostlyOver)
}

#Preview("History - Macro Misses") {
    HistoryPreviewFixtures.preview(for: .macroMisses)
}

#Preview("History - 90-Day Weekly") {
    HistoryPreviewFixtures.preview(for: .quarterWeekly)
}
#endif
