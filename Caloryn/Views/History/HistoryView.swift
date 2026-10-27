import Combine
import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @Query(sort: \FoodLogEntry.date, order: .reverse) private var allEntries: [FoodLogEntry]
    @Query(sort: \UserProfile.updatedAt, order: .reverse) private var profiles: [UserProfile]
    @Query private var goalSnapshots: [DailyGoalSnapshot]

    @State private var historyState: HistoryViewState
    @State private var navigationPath: [HistoryDrillDownRoute] = []
    @State private var analyticsDayStart = Calendar.current.startOfDay(for: .now)
    @State private var hasLoadedAnalytics = false
    @State private var isContentVisible = false
    @State private var pageSize: CGSize = .zero
    @State private var detailSelection = HistoryDetailSelection()
    @State private var inlineDetailSeed: HistoryDrillDownRoute?

    #if DEBUG
    @State private var debugLaunch = HistoryDebugLaunch.current
    #endif

    init(initialRange: HistoryRange = .week) {
        var range = initialRange
        #if DEBUG
        range = HistoryDebugLaunch.current.range ?? range
        #endif
        _historyState = State(
            initialValue: HistoryViewState(
                range: range,
                analytics: HistoryAnalytics(entries: [], profile: nil, range: range),
                recurringPattern: nil
            )
        )
    }

    private var profile: UserProfile? { profiles.first }

    private var isSelectedTab: Bool { router.selectedTab == .history }

    private func relevantEntries(for range: HistoryRange) -> [FoodLogEntry] {
        relevantEntries(
            startingAt: HistoryEntryWindow.analyticsStart(
                for: range,
                now: .now,
                calendar: .current
            )
        )
    }

    private func relevantEntries(startingAt startDate: Date) -> [FoodLogEntry] {
        HistoryEntryWindow.entries(allEntries, newestFirstFrom: startDate, date: \.date)
    }

    private var widestAnalyticsStartDate: Date {
        HistoryEntryWindow.widestAnalyticsStart(now: .now, calendar: .current)
    }

    private var recurringPatternStartDate: Date {
        HistoryEntryWindow.recurringPatternStart(now: .now, calendar: .current)
    }

    private var analyticsRefreshID: HistoryAnalyticsRefreshID {
        HistoryAnalyticsRefreshID(
            dayStart: analyticsDayStart,
            profile: profile.map { HistoryProfileSignature(profile: $0) },
            entries: relevantEntries(startingAt: widestAnalyticsStartDate)
                .map { HistoryEntrySignature(entry: $0) },
            goalSnapshots: goalSnapshots
                .map { HistoryGoalSnapshotSignature(snapshot: $0) }
        )
    }

    private var targetResolver: HistoryDayTargetResolver {
        HistoryDayTargetResolver(
            fallbackTarget: profile?.dailyCalorieTarget ?? 2_000,
            valuesByDayKey: DailyGoalSnapshotStore.latestValuesByDayKey(goalSnapshots)
        )
    }

    private var split: RegularWidthSplit {
        RegularWidthSplit(
            isRegularWidth: horizontalSizeClass == .regular,
            isRegularHeight: verticalSizeClass == .regular,
            pageSize: pageSize
        )
    }

    var body: some View {
        let split = split

        NavigationStack(path: $navigationPath) {
            Group {
                if split.showsColumns {
                    SplitColumns(split: split) {
                        historyPage(showsDetailInline: true)
                    } secondary: {
                        inlineDetailPane
                    }
                } else {
                    historyPage(showsDetailInline: false)
                }
            }
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { pageSize = $0 }
            .calorynLargeTitle("History")
            .navigationDestination(for: HistoryDrillDownRoute.self) { route in
                destination(for: route)
            }
        }
        .calorynPageCanvas()
        .onChange(of: split.showsColumns) { _, showsColumns in
            guard showsColumns, let route = navigationPath.last else { return }
            showInline(route)
            navigationPath = []
        }
        .task(id: isSelectedTab ? analyticsRefreshID : nil) {
            guard isSelectedTab else { return }
            refreshAnalytics(for: historyState.range)
            if !hasLoadedAnalytics {
                hasLoadedAnalytics = true
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
                    isContentVisible = true
                }
            }
            #if DEBUG
            openDebugDrillDownIfRequested()
            #endif
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            followCalendarRollover()
        }
        .onReceive(
            NotificationCenter.default
                .publisher(for: .NSCalendarDayChanged)
                .receive(on: RunLoop.main)
        ) { _ in
            followCalendarRollover()
        }
    }

    private func historyPage(showsDetailInline: Bool) -> some View {
        ScrollView {
            let state = historyState
            let history = state.analytics
            let patternDiscovery = HistoryPatternDiscovery(analytics: history)
            let overview = HistoryOverviewSummary(
                range: state.range,
                loggedDayCount: history.current.loggedDayCount,
                totalDayCount: history.current.totalDayCount,
                averageCaloriesPerLoggedDay: history.current.averageCaloriesPerLoggedDay,
                averageTargetPerLoggedDay: history.current.averageTargetPerLoggedDay,
                onTrackLoggedDayCount: history.current.onTrackLoggedDayCount,
                onTrackDayDelta: history.goalComparison.onTrackDayDelta
            )
            let selectedDetail = showsDetailInline ? currentPane.detail : nil

            VStack(alignment: .leading, spacing: 26) {
                if hasLoadedAnalytics {
                    VStack(alignment: .leading, spacing: 22) {
                        rangePicker

                        crossfading(on: state.range) {
                            VStack(alignment: .leading, spacing: 26) {
                                HistoryOverviewSection(
                                    range: state.range,
                                    summary: history.current,
                                    overview: overview,
                                    today: analyticsDayStart
                                )

                                if let recurringPattern = state.recurringPattern {
                                    HistoryRecurringCaloriePatternCard(
                                        pattern: recurringPattern,
                                        action: { openPatternDetails(recurringPattern) }
                                    )
                                    .historyDetailSource(
                                        isSelected: selectedDetail == .recurringPattern,
                                        outset: 0
                                    )
                                }

                                if overview.hasLoggedDays {
                                    HistoryOnTrackSection(overview: overview)
                                }

                                if state.range.days >= HistoryRange.month.days {
                                    HistoryWeeklyRollupSection(projection: patternDiscovery.weeklyConsistency)
                                }

                                HistoryCalorieTrendSection(
                                    projection: patternDiscovery.calorieTrend,
                                    drillDownAction: patternDiscovery.calorieTrend.canDrillDown
                                        ? { openCalorieTrendDetail(range: state.range, summary: history.current) }
                                        : nil
                                )
                                .historyDetailSource(
                                    isSelected: selectedDetail == .calorieTrend,
                                    outset: 12
                                )

                                if history.macroPatterns.contains(where: { $0.current.loggedDays > 0 }) {
                                    HistoryMacroPatternsSection(
                                        range: state.range,
                                        projection: patternDiscovery.macroPatterns
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .opacity(isContentVisible ? 1 : 0)
            .padding(.horizontal, CalorynTheme.pagePadding)
            .padding(.top, 4)
            .padding(.bottom, 28)
        }
        .historyDebugScrollAnchor()
        .calorynPageCanvas()
    }

    private var currentPane: HistoryDetailSelection.Pane {
        let state = historyState
        return detailSelection.pane(
            range: state.range,
            canDrillIntoCalorieTrend: HistoryPatternDiscovery(analytics: state.analytics).calorieTrend.canDrillDown,
            hasRecurringPattern: state.recurringPattern != nil
        )
    }

    private var inlineDetailPane: some View {
        let state = historyState
        let pane = currentPane

        return ZStack(alignment: .topLeading) {
            if hasLoadedAnalytics {
                switch pane {
                case .calorieTrend(let range):
                    HistoryCalorieTrendDetailView(
                        range: range,
                        summary: state.analytics.current,
                        initialSelectedPointID: inlineTrendSeed(for: range)?.initialSelectedPointID,
                        presentation: .inline
                    )
                case .recurringPattern:
                    if let pattern = state.recurringPattern {
                        HistoryRecurringCaloriePatternDetailView(
                            pattern: pattern,
                            initiallyExpandedDayIDs: inlinePatternSeed?.initiallyExpandedDayIDs ?? [],
                            presentation: .inline
                        )
                    }
                case .empty:
                    HistoryDetailEmptyPane()
                }
            }
        }
        .id(pane)
        .transition(.opacity)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .opacity(isContentVisible ? 1 : 0)
    }

    private func inlineTrendSeed(for range: HistoryRange) -> HistoryCalorieTrendSnapshot? {
        guard case .calorieTrend(let snapshot) = inlineDetailSeed, snapshot.range == range else { return nil }
        return snapshot
    }

    private var inlinePatternSeed: HistoryRecurringCaloriePatternSnapshot? {
        guard case .recurringPattern(let snapshot) = inlineDetailSeed else { return nil }
        return snapshot
    }

    private func followCalendarRollover() {
        let dayStart = Calendar.current.startOfDay(for: .now)
        guard dayStart != analyticsDayStart else { return }
        analyticsDayStart = dayStart
    }

    private func refreshAnalytics(for range: HistoryRange) {
        let resolver = targetResolver
        historyState = HistoryViewState(
            range: range,
            analytics: HistoryAnalytics(
                entries: relevantEntries(for: range),
                profile: profile,
                range: range,
                targetResolver: resolver
            ),
            recurringPattern: HistoryRecurringCaloriePatternEngine().discover(
                entries: relevantEntries(startingAt: recurringPatternStartDate),
                targetResolver: resolver
            )
        )
    }

    private var changeAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.2)
    }

    private func crossfading(
        on range: HistoryRange,
        @ViewBuilder content: () -> some View
    ) -> some View {
        ZStack(alignment: .topLeading) {
            content()
                .id(range)
                .transition(.opacity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func selectRange(_ range: HistoryRange) {
        guard range != historyState.range else { return }
        inlineDetailSeed = nil
        withAnimation(changeAnimation) {
            refreshAnalytics(for: range)
        }
    }

    private func openCalorieTrendDetail(range: HistoryRange, summary: HistoryPeriodSummary) {
        let snapshot = HistoryCalorieTrendSnapshot(
            range: range,
            summary: summary
        )
        open(.calorieTrend(snapshot))
    }

    private func openPatternDetails(_ pattern: HistoryRecurringCaloriePattern) {
        open(
            .recurringPattern(
                HistoryRecurringCaloriePatternSnapshot(pattern: pattern)
            )
        )
    }

    private func open(_ route: HistoryDrillDownRoute) {
        if split.showsColumns {
            withAnimation(changeAnimation) {
                showInline(route)
            }
        } else {
            navigationPath.append(route)
        }
    }

    private func showInline(_ route: HistoryDrillDownRoute) {
        inlineDetailSeed = route
        switch route {
        case .calorieTrend:
            detailSelection.choose(.calorieTrend)
        case .recurringPattern:
            detailSelection.choose(.recurringPattern)
        }
    }

    #if DEBUG
    private func openDebugDrillDownIfRequested() {
        guard let drillDown = debugLaunch.drillDown else { return }
        debugLaunch.drillDown = nil

        let state = historyState
        switch drillDown {
        case .calorieTrend, .calorieTrendSelected:
            var snapshot = HistoryCalorieTrendSnapshot(
                range: state.range,
                summary: state.analytics.current
            )
            if drillDown == .calorieTrendSelected {
                let projection = HistoryCalorieTrendProjection(
                    range: state.range,
                    summary: state.analytics.current
                )
                snapshot.initialSelectedPointID = projection.points.last(where: \.isLogged)?.id
            }
            open(.calorieTrend(snapshot))
        case .recurringPattern, .recurringPatternExpanded:
            guard let pattern = state.recurringPattern else { return }
            var snapshot = HistoryRecurringCaloriePatternSnapshot(pattern: pattern)
            if drillDown == .recurringPatternExpanded, let first = pattern.supportingDays.first {
                snapshot.initiallyExpandedDayIDs = [first.id]
            }
            open(.recurringPattern(snapshot))
        }
    }
    #endif

    @ViewBuilder
    private func destination(for route: HistoryDrillDownRoute) -> some View {
        switch route {
        case .calorieTrend(let snapshot):
            HistoryCalorieTrendDetailView(
                range: snapshot.range,
                summary: snapshot.summary,
                initialSelectedPointID: snapshot.initialSelectedPointID
            )
        case .recurringPattern(let snapshot):
            HistoryRecurringCaloriePatternDetailView(
                pattern: snapshot.pattern,
                initiallyExpandedDayIDs: snapshot.initiallyExpandedDayIDs
            )
        }
    }

    private var rangePicker: some View {
        let ranges = HistoryRange.allCases
        let half = (ranges.count + 1) / 2

        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                ForEach(ranges) { rangeChip($0) }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    ForEach(ranges.prefix(half)) { rangeChip($0) }
                }
                HStack(spacing: 6) {
                    ForEach(ranges.dropFirst(half)) { rangeChip($0) }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(ranges) { rangeChip($0) }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Range")
        .accessibilityIdentifier("history.rangePicker")
    }

    private func rangeChip(_ range: HistoryRange) -> some View {
        let isSelected = range == historyState.range

        return Button {
            selectRange(range)
        } label: {
            Text(range.chipTitle)
                .calorynChip(isSelected: isSelected)
                .fixedSize()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(range.label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct HistoryViewState {
    let range: HistoryRange
    let analytics: HistoryAnalytics
    let recurringPattern: HistoryRecurringCaloriePattern?
}

private enum HistoryDrillDownRoute: Hashable {
    case calorieTrend(HistoryCalorieTrendSnapshot)
    case recurringPattern(HistoryRecurringCaloriePatternSnapshot)
}

private struct HistoryCalorieTrendSnapshot: Hashable {
    let id = UUID()
    let range: HistoryRange
    let summary: HistoryPeriodSummary
    var initialSelectedPointID: String?

    static func == (lhs: HistoryCalorieTrendSnapshot, rhs: HistoryCalorieTrendSnapshot) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

private struct HistoryRecurringCaloriePatternSnapshot: Hashable {
    let id = UUID()
    let pattern: HistoryRecurringCaloriePattern
    var initiallyExpandedDayIDs: Set<Date> = []

    static func == (
        lhs: HistoryRecurringCaloriePatternSnapshot,
        rhs: HistoryRecurringCaloriePatternSnapshot
    ) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

#if DEBUG
struct HistoryDebugLaunch {
    enum DrillDown: String {
        case calorieTrend
        case calorieTrendSelected
        case recurringPattern
        case recurringPatternExpanded
    }

    var range: HistoryRange?
    var drillDown: DrillDown?
    var scrollsToBottom = false

    static var current: HistoryDebugLaunch {
        HistoryDebugLaunch(
            range: value(after: "-CalorynHistoryRange").flatMap(HistoryRange.init(rawValue:)),
            drillDown: value(after: "-CalorynHistoryDrillDown").flatMap(DrillDown.init(rawValue:)),
            scrollsToBottom: ProcessInfo.processInfo.arguments.contains("-CalorynHistoryScrolledToBottom")
        )
    }

    private static func value(after flag: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }
}

#endif

extension View {
    @ViewBuilder
    func historyDebugScrollAnchor() -> some View {
        #if DEBUG
        if HistoryDebugLaunch.current.scrollsToBottom {
            defaultScrollAnchor(.bottom)
        } else {
            self
        }
        #else
        self
        #endif
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

#Preview("History - Recurring Insight") {
    HistoryPreviewFixtures.preview(for: .recurringInsight)
}

#Preview("History - No Recurring Insight") {
    HistoryPreviewFixtures.preview(for: .noRecurringInsight)
}
#endif
