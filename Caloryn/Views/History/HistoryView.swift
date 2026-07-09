import SwiftUI
import SwiftData

struct HistoryView: View {
    // Keep newest-first ordering in sync with relevantEntries(startingAt:);
    // that helper early-exits when it reaches entries older than its window.
    @Query(sort: \FoodLogEntry.date, order: .reverse) private var allEntries: [FoodLogEntry]
    @Query(sort: \UserProfile.updatedAt, order: .reverse) private var profiles: [UserProfile]

    @State private var historyState: HistoryViewState
    @State private var navigationPath: [HistoryDrillDownRoute] = []

    init(initialRange: HistoryRange = .week) {
        _historyState = State(
            initialValue: HistoryViewState(
                range: initialRange,
                analytics: HistoryAnalytics(entries: [], profile: nil, range: initialRange)
            )
        )
    }

    private var profile: UserProfile? { profiles.first }

    private func relevantEntries(for range: HistoryRange) -> [FoodLogEntry] {
        relevantEntries(startingAt: analyticsStartDate(for: range))
    }

    private func relevantEntries(startingAt startDate: Date) -> [FoodLogEntry] {
        var entries: [FoodLogEntry] = []
        #if DEBUG
        var previousDate: Date?
        #endif

        for entry in allEntries {
            #if DEBUG
            if let previousDate {
                precondition(
                    previousDate >= entry.date,
                    "History entries must stay sorted newest-first by date."
                )
            }
            previousDate = entry.date
            #endif

            if entry.date >= startDate {
                entries.append(entry)
            } else {
                break
            }
        }

        return entries
    }

    private var widestAnalyticsStartDate: Date {
        analyticsStartDate(for: .quarter)
    }

    private func analyticsStartDate(for range: HistoryRange) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return calendar.date(
            byAdding: .day,
            value: -(range.days * 2 - 1),
            to: today
        ) ?? today
    }

    private var analyticsRefreshID: HistoryAnalyticsRefreshID {
        HistoryAnalyticsRefreshID(
            profile: profile.map { HistoryProfileSignature(profile: $0) },
            entries: relevantEntries(startingAt: widestAnalyticsStartDate)
                .map { HistoryEntrySignature(entry: $0) }
        )
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                let state = historyState
                let history = state.analytics
                let patternDiscovery = HistoryPatternDiscovery(analytics: history)

                VStack(spacing: CalorynTheme.cardSpacing) {
                    rangePicker

                    HistoryCalorieTrendCard(
                        projection: patternDiscovery.calorieTrend,
                        drillDownAction: patternDiscovery.calorieTrend.canDrillDown
                            ? { openCalorieTrendDetail(range: state.range, summary: history.current) }
                            : nil
                    )

                    HistoryGoalSummaryCard(
                        range: state.range,
                        summary: history.current,
                        comparison: history.goalComparison
                    )

                    if state.range.days >= HistoryRange.month.days {
                        HistoryWeeklyRollupCard(projection: patternDiscovery.weeklyConsistency)
                    }

                    if history.macroPatterns.contains(where: { $0.current.loggedDays > 0 }) {
                        HistoryMacroPatternsCard(projection: patternDiscovery.macroPatterns)
                    }
                }
                .padding(.horizontal, CalorynTheme.pagePadding)
                .padding(.bottom, 20)
            }
            .calorynPageCanvas()
            .navigationTitle("History")
            .navigationDestination(for: HistoryDrillDownRoute.self) { route in
                destination(for: route)
            }
        }
        .calorynPageCanvas()
        .task(id: analyticsRefreshID) {
            // Range changes refresh synchronously through selectRange; data/profile
            // changes should recalculate for the range current when this task runs.
            refreshAnalytics(for: historyState.range)
        }
    }

    private func refreshAnalytics(for range: HistoryRange) {
        historyState = HistoryViewState(
            range: range,
            analytics: HistoryAnalytics(
                entries: relevantEntries(for: range),
                profile: profile,
                range: range
            )
        )
    }

    private func selectRange(_ range: HistoryRange) {
        guard range != historyState.range else { return }
        refreshAnalytics(for: range)
    }

    private var rangeSelection: Binding<HistoryRange> {
        Binding(
            get: { historyState.range },
            set: { selectRange($0) }
        )
    }

    private func openCalorieTrendDetail(range: HistoryRange, summary: HistoryPeriodSummary) {
        let snapshot = HistoryCalorieTrendSnapshot(
            range: range,
            summary: summary
        )
        navigationPath.append(.calorieTrend(snapshot))
    }

    @ViewBuilder
    private func destination(for route: HistoryDrillDownRoute) -> some View {
        switch route {
        case .calorieTrend(let snapshot):
            HistoryCalorieTrendDetailView(
                range: snapshot.range,
                summary: snapshot.summary
            )
        }
    }

    private var rangePicker: some View {
        Picker("Range", selection: rangeSelection) {
            ForEach(HistoryRange.allCases) { range in
                Text(range.label).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .padding(.top, 4)
    }
}

private struct HistoryViewState {
    let range: HistoryRange
    let analytics: HistoryAnalytics
}

private enum HistoryDrillDownRoute: Hashable {
    case calorieTrend(HistoryCalorieTrendSnapshot)
}

private struct HistoryCalorieTrendSnapshot: Hashable {
    let id = UUID()
    let range: HistoryRange
    let summary: HistoryPeriodSummary

    static func == (lhs: HistoryCalorieTrendSnapshot, rhs: HistoryCalorieTrendSnapshot) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

private struct HistoryAnalyticsRefreshID: Equatable {
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
    let mealTypeRaw: String
    let snackIndex: Int
    let foodName: String
    let portionGrams: Double
    let calories: Double
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let fiberG: Double
    let sugarsG: Double?
    let addedSugarsG: Double?
    let saturatedFatG: Double?
    let sodiumG: Double?
    let cholesterolG: Double?
    let alcoholG: Double?
    let nutriscoreGrade: String?
    let produceKindRaw: String?

    init(entry: FoodLogEntry) {
        id = entry.id
        date = entry.date
        mealTypeRaw = entry.mealType.rawValue
        snackIndex = entry.snackIndex
        foodName = entry.foodName
        portionGrams = entry.portionGrams
        calories = entry.calories
        proteinG = entry.proteinG
        carbsG = entry.carbsG
        fatG = entry.fatG
        fiberG = entry.fiberG
        sugarsG = entry.sugarsG
        addedSugarsG = entry.addedSugarsG
        saturatedFatG = entry.saturatedFatG
        sodiumG = entry.sodiumG
        cholesterolG = entry.cholesterolG
        alcoholG = entry.alcoholG
        nutriscoreGrade = entry.foodItem?.nutriscoreGrade
        produceKindRaw = entry.foodItem?.produceKind.rawValue
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
