import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query private var allEntries: [FoodLogEntry]
    @Query(sort: \UserProfile.updatedAt, order: .reverse) private var profiles: [UserProfile]

    @State private var selectedRange: HistoryRange = .week
    @State private var analytics: HistoryAnalytics

    init(initialRange: HistoryRange = .week) {
        _selectedRange = State(initialValue: initialRange)
        _analytics = State(initialValue: HistoryAnalytics(entries: [], profile: nil, range: initialRange))
    }

    private var profile: UserProfile? { profiles.first }

    private var relevantEntries: [FoodLogEntry] {
        allEntries.filter { $0.date >= analyticsStartDate }
    }

    private var analyticsStartDate: Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return calendar.date(
            byAdding: .day,
            value: -(selectedRange.days * 2 - 1),
            to: today
        ) ?? today
    }

    private var analyticsRefreshID: HistoryAnalyticsRefreshID {
        HistoryAnalyticsRefreshID(
            range: selectedRange,
            profile: profile.map { HistoryProfileSignature(profile: $0) },
            entries: relevantEntries
                .map { HistoryEntrySignature(entry: $0) }
                .sorted { $0.sortKey < $1.sortKey }
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

                    if history.macroPatterns.contains(where: { $0.current.loggedDays > 0 }) {
                        HistoryMacroPatternsCard(patterns: history.macroPatterns)
                    }
                }
                .padding(.horizontal, CalorynTheme.pagePadding)
                .padding(.bottom, 20)
            }
            .navigationTitle("History")
        }
        .task(id: analyticsRefreshID) {
            refreshAnalytics()
        }
    }

    private func refreshAnalytics() {
        analytics = HistoryAnalytics(
            entries: relevantEntries,
            profile: profile,
            range: selectedRange
        )
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

private struct HistoryAnalyticsRefreshID: Equatable {
    let range: HistoryRange
    let profile: HistoryProfileSignature?
    let entries: [HistoryEntrySignature]
}

private struct HistoryProfileSignature: Equatable {
    let id: UUID
    let updatedAt: Date
    let dailyCalorieTarget: Int
    let proteinTargetG: Double
    let carbTargetG: Double
    let fatTargetG: Double
    let proteinGoalKindRaw: String
    let carbGoalKindRaw: String
    let fatGoalKindRaw: String

    init(profile: UserProfile) {
        id = profile.id
        updatedAt = profile.updatedAt
        dailyCalorieTarget = profile.dailyCalorieTarget
        proteinTargetG = profile.proteinTargetG
        carbTargetG = profile.carbTargetG
        fatTargetG = profile.fatTargetG
        proteinGoalKindRaw = profile.proteinGoalKindRaw
        carbGoalKindRaw = profile.carbGoalKindRaw
        fatGoalKindRaw = profile.fatGoalKindRaw
    }
}

private struct HistoryEntrySignature: Equatable {
    let id: UUID
    let date: Date
    let calories: Double
    let proteinG: Double
    let carbsG: Double
    let fatG: Double

    var sortKey: String {
        id.uuidString
    }

    init(entry: FoodLogEntry) {
        id = entry.id
        date = entry.date
        calories = entry.calories
        proteinG = entry.proteinG
        carbsG = entry.carbsG
        fatG = entry.fatG
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
