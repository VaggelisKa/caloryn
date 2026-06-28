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

                    HistoryCalorieTrendCard(
                        range: selectedRange,
                        summary: history.current
                    )

                    HistoryGoalSummaryCard(
                        range: selectedRange,
                        summary: history.current,
                        comparison: history.goalComparison
                    )

                    if selectedRange.days >= HistoryRange.month.days {
                        HistoryWeeklyRollupCard(summary: history.current)
                    }

                    if !history.macroPatterns.isEmpty {
                        HistoryMacroPatternsCard(patterns: history.macroPatterns)
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
