import Combine
import SwiftUI
import SwiftData

struct TodayView: View {
    @State private var selectedDate: Date = Date().startOfDay

    var body: some View {
        TodayDayView(day: selectedDate, selectedDate: $selectedDate)
    }
}

private struct TodayDayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(AppRouter.self) private var router
    @Query(sort: \UserProfile.updatedAt, order: .reverse) private var profiles: [UserProfile]
    @Query private var entriesAroundDay: [FoodLogEntry]
    @Query private var goalSnapshots: [DailyGoalSnapshot]
    @Binding private var selectedDate: Date

    private static let minimumHitTarget: CGFloat = 44
    private static let dayButtonSize: CGFloat = 36

    private struct FoodSearchPresentation: Identifiable {
        let id = UUID()
        let mealType: MealType
        let logDate: Date
        let snackIndex: Int
        let startsWithScanner: Bool
    }

    @State private var pageSize: CGSize = .zero

    @State private var lastKnownToday: Date = Date().startOfDay
    @State private var showingNutritionDetails = false
    @State private var foodSearchPresentation: FoodSearchPresentation?
    @State private var entryToEdit: FoodLogEntry?
    @Namespace private var dayButtonGlass

    @AppStorage("showNutriscore") private var showNutriscore = true

    init(day: Date, selectedDate: Binding<Date>) {
        _entriesAroundDay = Query(
            filter: FoodLogEntryWindow.logged(in: FoodLogEntryWindow.days(around: day, calendar: .current))
        )
        _selectedDate = selectedDate
    }

    private var profile: UserProfile? { profiles.first }
    private func calorieBudget(consumed: Double) -> CalorieBudget {
        let current = profile?.calorieBudget(consumed: consumed) ?? CalorieBudget(consumed: consumed, target: 2_000)
        let target = DayCalorieTarget.calories(
            for: selectedDate,
            today: .now,
            currentTarget: current.target,
            savedTargets: HistoryDayTargetResolver(
                fallbackTarget: current.target,
                valuesByDayKey: DailyGoalSnapshotStore.latestValuesByDayKey(goalSnapshots)
            )
        )
        return CalorieBudget(consumed: consumed, target: target, isManualOverride: current.isManualOverride)
    }

    private var dayMeals: [MealType] {
        DayFoodLogSelection.dayMeals
    }

    private var dayProjection: DayFoodLogProjection<FoodLogEntry> {
        DayFoodLogProjection(
            entriesAroundDay,
            on: selectedDate,
            date: \.date,
            mealType: \.mealType,
            createdAt: \.createdAt
        )
    }

    var body: some View {
        let projection = dayProjection
        let nutriscoreGrades = projection.today.map(\.historicalNutriscoreGrade)
        let nutriscoreDistribution = NutriscoreDayDistribution.distribution(of: nutriscoreGrades)
        let hasNutriscoreData = NutriscoreDayDistribution.hasData(nutriscoreGrades)
        let calorieBudget = calorieBudget(
            consumed: projection.today.reduce(0) { $0 + $1.calories }
        )
        let canCopyYesterday = DayFoodLogSelection.canCopyYesterday(
            loggedTodayCount: projection.today.count,
            loggedYesterdayCount: projection.yesterday.count
        )
        let targetRows = horizontalSizeClass == .regular
            ? targetRows(entries: projection.today, calorieTarget: calorieBudget.target)
            : []
        let layout = TodayDashboardLayout(
            isRegularWidth: horizontalSizeClass == .regular,
            isRegularHeight: verticalSizeClass == .regular,
            pageSize: pageSize,
            isLargeText: dynamicTypeSize >= .xxxLarge,
            hasTargets: !targetRows.isEmpty
        )

        let dashboard = DashboardContent(
            entries: projection.today,
            yesterdayEntries: projection.yesterday,
            calorieBudget: calorieBudget,
            nutriscoreDistribution: nutriscoreDistribution,
            showsNutriscore: showNutriscore && hasNutriscoreData,
            canCopyYesterday: canCopyYesterday,
            targetRows: targetRows
        )

        NavigationStack {
            Group {
                if layout.arrangesSplitAroundFold {
                    dashboardAndMeals(dashboard, layout: layout, projection: projection)
                } else if layout.showsMealsBesideDashboard {
                    dashboardBesideMeals(dashboard, layout: layout, projection: projection)
                } else {
                    dashboardOverMeals(dashboard, layout: layout, projection: projection)
                }
            }
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { pageSize = $0 }
            .calorynPageCanvas()
            .todayTitlelessBar()
            .sheet(item: $foodSearchPresentation) { presentation in
                FoodSearchView(
                    mealType: presentation.mealType,
                    logDate: presentation.logDate,
                    snackIndex: presentation.snackIndex,
                    startsWithScanner: presentation.startsWithScanner
                )
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $entryToEdit) { entry in
                if let food = entry.foodItem {
                    NavigationStack {
                        PortionPickerView(
                            foodItem: food,
                            mealType: entry.mealType,
                            logDate: entry.date,
                            isNewFood: false,
                            snackIndex: entry.snackIndex,
                            existingEntry: entry,
                            onDeleted: { deletedEntry in
                                deleteEntry(deletedEntry)
                                entryToEdit = nil
                            }
                        )
                    }
                    .presentationDragIndicator(.visible)
                } else {
                    MissingFoodEntryView(entry: entry) {
                        deleteEntry(entry)
                        entryToEdit = nil
                    }
                    .presentationDragIndicator(.visible)
                }
            }
            .sheet(isPresented: $showingNutritionDetails) {
                nutritionDetailsSheet(
                    entries: projection.today,
                    calorieBudget: calorieBudget
                )
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .calorynPageCanvas()
        .task(id: router.pendingRoute) {
            handlePendingRoute()
        }
        .task(id: calorieBudget) {
            recordDailyGoalSnapshotIfNeeded(calorieBudget: calorieBudget)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            followCalendarRollover()
        }
        // Covers midnight passing while Today stays on screen, when no scene
        // transition ever happens.
        .onReceive(
            NotificationCenter.default
                .publisher(for: .NSCalendarDayChanged)
                .receive(on: RunLoop.main)
        ) { _ in
            followCalendarRollover()
        }
    }

    // MARK: - Layouts

    /// What the top of the page shows above (or beside) the meals, worked out once per body.
    private struct DashboardContent {
        let entries: [FoodLogEntry]
        let yesterdayEntries: [FoodLogEntry]
        let calorieBudget: CalorieBudget
        let nutriscoreDistribution: [(grade: String, count: Int)]
        let showsNutriscore: Bool
        let canCopyYesterday: Bool
        let targetRows: [NutritionDetailsSections.TargetRow]

        var hasCluster: Bool { showsNutriscore || canCopyYesterday }
    }

    /// One list, the dashboard as its first rows so the date scrolls away with the day
    /// instead of staying pinned over it.
    private func dashboardOverMeals(
        _ dashboard: DashboardContent,
        layout: TodayDashboardLayout,
        projection: DayFoodLogProjection<FoodLogEntry>
    ) -> some View {
        List {
            dateNavigator
                .todayPlateRowLayout(top: 4, bottom: 0)
                .calorynClearRowBackground()
                .listRowSeparator(.hidden)

            if layout.breakpoint == .compact {
                dashboardSection(entries: dashboard.entries, calorieBudget: dashboard.calorieBudget)
                    .todayPlateRowLayout(top: 12, bottom: 4)
                    .calorynClearRowBackground()
                    .listRowSeparator(.hidden)

                if dashboard.showsNutriscore {
                    nutriscoreSection(distribution: dashboard.nutriscoreDistribution)
                        .todayPlateRowLayout(top: 10)
                        .calorynClearRowBackground()
                        .listRowSeparator(.hidden)
                } else if dashboard.canCopyYesterday {
                    copyYesterdayButton(yesterdayEntries: dashboard.yesterdayEntries)
                        .todayPlateRowLayout(top: 10)
                        .calorynClearRowBackground()
                        .listRowSeparator(.hidden)
                }
            } else {
                regularBand(dashboard, layout: layout)
                    .todayPlateRowLayout(top: 12, bottom: 12)
                    .calorynClearRowBackground()
                    .listRowSeparator(.hidden)
            }

            mealRows(projection: projection, layout: layout, canCopyYesterday: dashboard.canCopyYesterday)
        }
        .calorynPlainListStyle()
        .environment(\.defaultMinListRowHeight, 0)
        .contentMargins(.top, 0, for: .scrollContent)
        .transaction(value: selectedDate) { $0.animation = nil }
        .animation(.smooth(duration: 0.35), value: dashboard.showsNutriscore)
        .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: projection.today.map(\.id))
    }

    /// Wide-regular: the dashboard is one region and the meals the other. The split
    /// arrangement puts them side by side on the flat display, and rearranges them around
    /// the fold when iPhone Duo is partially open — the axes are left unconstrained so a
    /// horizontal fold (the laptop pose) can stack them instead. Same content, order and
    /// controls as the narrow-regular page; both regions scroll on their own.
    ///
    /// The arrangement view is iOS 27.1; before it the same two regions sit in an `HStack`.
    /// The SDK has to know it too: Swift 6.4 is Xcode 27.1, and CI builds with Xcode 26.6.
    @ViewBuilder
    private func dashboardAndMeals(
        _ dashboard: DashboardContent,
        layout: TodayDashboardLayout,
        projection: DayFoodLogProjection<FoodLogEntry>
    ) -> some View {
        #if compiler(>=6.4)
        if #available(iOS 27.1, *) {
            ArrangementView {
                dashboardColumn(dashboard, layout: layout)
                    // Enough for the hero: a 168pt donut beside its number column needs about
                    // 380pt. The targets panel makes the column taller than a stacked region,
                    // so it scrolls. No maximum, so the divider can still land on the fold in
                    // the book pose.
                    .splitArrangementLayoutRatio(
                        minHorizontal: 0.36,
                        idealHorizontal: TodayDashboardLayout.dashboardColumnFraction,
                        minVertical: 0.38,
                        idealVertical: 0.42
                    )
            } secondary: {
                mealsList(projection: projection, layout: layout, canCopyYesterday: dashboard.canCopyYesterday)
            }
            .arrangementViewStyle(.split)
        } else {
            dashboardBesideMeals(dashboard, layout: layout, projection: projection)
        }
        #else
        dashboardBesideMeals(dashboard, layout: layout, projection: projection)
        #endif
    }

    /// The split without the arrangement view: a fixed 40/60 `HStack`. Also the split of a page
    /// taller than wide, which has no fold to arrange around, and which an arrangement view would
    /// stack instead, clipping the dashboard.
    private func dashboardBesideMeals(
        _ dashboard: DashboardContent,
        layout: TodayDashboardLayout,
        projection: DayFoodLogProjection<FoodLogEntry>
    ) -> some View {
        HStack(alignment: .top, spacing: 0) {
            dashboardColumn(dashboard, layout: layout)
                .containerRelativeFrame(.horizontal) { width, _ in width * TodayDashboardLayout.dashboardColumnFraction }

            mealsList(projection: projection, layout: layout, canCopyYesterday: dashboard.canCopyYesterday)
        }
    }

    /// The dashboard rows as a page of their own, spaced as the list rows are.
    private func dashboardColumn(_ dashboard: DashboardContent, layout: TodayDashboardLayout) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                dateNavigator
                    .padding(.top, 4)

                regularBand(dashboard, layout: layout)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, CalorynTheme.pagePadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.smooth(duration: 0.35), value: dashboard.showsNutriscore)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func regularBand(_ dashboard: DashboardContent, layout: TodayDashboardLayout) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            dashboardSection(
                entries: dashboard.entries,
                calorieBudget: dashboard.calorieBudget,
                columns: layout.heroColumns
            )

            if layout.showsTargetsPanel || dashboard.hasCluster {
                dashboardDetails(dashboard, layout: layout)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func dashboardDetails(_ dashboard: DashboardContent, layout: TodayDashboardLayout) -> some View {
        let isTrailingCluster = layout.detailsPlacement == .besideEachOtherBelowHero && layout.showsTargetsPanel
        let detailsLayout = isTrailingCluster
            ? AnyLayout(HStackLayout(alignment: .top, spacing: TodayDashboardLayout.clusterBesideTargetsSpacing))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 20))

        return detailsLayout {
            if layout.showsTargetsPanel {
                TodayTargetsPanel(rows: dashboard.targetRows, onDetailsRequested: showNutritionDetails)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if dashboard.hasCluster {
                dashboardCluster(dashboard)
                    .frame(width: isTrailingCluster ? TodayDashboardLayout.trailingClusterWidth : nil, alignment: .leading)
                    .padding(.top, isTrailingCluster ? 8 : 0)
            }
        }
    }

    @ViewBuilder
    private func dashboardCluster(_ dashboard: DashboardContent) -> some View {
        if dashboard.showsNutriscore {
            nutriscoreSection(distribution: dashboard.nutriscoreDistribution)
        } else if dashboard.canCopyYesterday {
            copyYesterdayButton(yesterdayEntries: dashboard.yesterdayEntries)
        }
    }

    private func mealsList(
        projection: DayFoodLogProjection<FoodLogEntry>,
        layout: TodayDashboardLayout,
        canCopyYesterday: Bool
    ) -> some View {
        List {
            mealRows(projection: projection, layout: layout, canCopyYesterday: canCopyYesterday)
        }
        .calorynPlainListStyle()
        .environment(\.defaultMinListRowHeight, 0)
        .contentMargins(.top, 0, for: .scrollContent)
        .transaction(value: selectedDate) { $0.animation = nil }
        .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: projection.today.map(\.id))
    }

    private func mealRows(
        projection: DayFoodLogProjection<FoodLogEntry>,
        layout: TodayDashboardLayout,
        canCopyYesterday: Bool
    ) -> some View {
        ForEach(dayMeals) { meal in
            let snackIndex = meal == .snack ? 1 : 0
            MealSectionView(
                mealType: meal,
                entries: projection.entries(for: meal),
                snackIndex: snackIndex,
                titleOverride: meal == .snack ? "Snacks" : nil,
                canCopyYesterday: canCopyYesterday,
                maximumRowWidth: layout.mealRowMaximumWidth,
                onAdd: {
                    presentFoodSearch(mealType: meal, snackIndex: snackIndex)
                },
                onEdit: { entry in
                    entryToEdit = entry
                },
                onDelete: deleteEntry
            )
        }
    }

    private var dateNavigator: some View {
        HStack(spacing: 12) {
            Text(DayTitle.text(for: selectedDate))
                .font(TodayPlateFont.dateTitle)
                .tracking(-0.2)
                .foregroundStyle(CalorynTheme.textPrimary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
                .minimumScaleFactor(0.7)
                .contentTransition(
                    reduceMotion ? .identity : .numericText(value: selectedDate.timeIntervalSinceReferenceDate)
                )
                .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: selectedDate)
                .accessibilityLabel(DayTitle.accessibilityLabel(for: selectedDate))
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 8)

            AdaptiveGlassGroup {
                HStack(spacing: 0) {
                    dayButton(
                        systemImage: "chevron.left",
                        label: "Previous day",
                        identifier: "today.previousDay",
                        isEnabled: true
                    ) {
                        selectedDate = selectedDate.yesterday
                    }

                    dayButton(
                        systemImage: "chevron.right",
                        label: "Next day",
                        identifier: "today.nextDay",
                        isEnabled: !selectedDate.isAtFutureLogLimit
                    ) {
                        selectedDate = selectedDate.tomorrow
                    }
                }
            }
            .padding(.trailing, -(Self.minimumHitTarget - Self.dayButtonSize) / 2)
        }
        .padding(.top, 4)
        .padding(.bottom, 4)
    }

    private func dayButton(
        systemImage: String,
        label: String,
        identifier: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(CalorynTheme.inlineIcon)
                .imageScale(.small)
                .foregroundStyle(isEnabled ? CalorynTheme.accent : CalorynTheme.textTertiary)
                .frame(width: Self.dayButtonSize, height: Self.dayButtonSize)
                .adaptiveUnitedInteractiveGlass(tint: CalorynTheme.backgroundSecondary, id: "dayButtons", in: dayButtonGlass)
                .frame(width: Self.minimumHitTarget, height: Self.minimumHitTarget)
                .contentShape([.interaction, .accessibility], .rect)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }

    private func dashboardSection(
        entries: [FoodLogEntry],
        calorieBudget: CalorieBudget,
        columns: TodayDashboardLayout.HeroColumns = .two
    ) -> some View {
        CalorieHeroView(
            summary: TodayHeroSummary(
                mealTotals: TodayHeroSummary.mealTotals(
                    entries,
                    mealType: \.mealType,
                    calories: \.calories
                ),
                budget: calorieBudget
            ),
            columns: columns,
            onDetailsRequested: showNutritionDetails
        )
        .accessibilityIdentifier("today.calorieRing")
    }

    private func showNutritionDetails() {
        withAnimation(.smooth(duration: 0.2)) {
            showingNutritionDetails = true
        }
    }

    private func targetRows(entries: [FoodLogEntry], calorieTarget: Int) -> [NutritionDetailsSections.TargetRow] {
        NutritionDetailsSections(
            metrics: TrackedNutrientMetric.metrics(
                in: entries,
                targets: profile?.nutrientTargets(forCalorieTarget: calorieTarget) ?? [:],
                goalKinds: profile?.nutrientGoalKinds ?? [:]
            ),
            details: []
        ).targets
    }

    @ViewBuilder
    private func nutritionDetailsSheet(
        entries: [FoodLogEntry],
        calorieBudget: CalorieBudget
    ) -> some View {
        let content = NutritionDetailsView(
            date: selectedDate,
            entries: entries,
            calorieBudget: calorieBudget,
            nutrientTargets: profile?.nutrientTargets(forCalorieTarget: calorieBudget.target) ?? [:],
            nutrientGoalKinds: profile?.nutrientGoalKinds ?? [:]
        )

        if #available(iOS 26.0, *) {
            content
                .presentationBackground(.regularMaterial)
        } else {
            content
                .presentationBackground(CalorynTheme.backgroundSecondary)
        }
    }

    private func nutriscoreSection(distribution: [(grade: String, count: Int)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nutri-Score")
                .font(CalorynTheme.sectionHeaderTitle)
                .foregroundStyle(CalorynTheme.textPrimary)
                .accessibilityHidden(true)

            NutriscoreDaySummary(distribution: distribution)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .leading)))
    }

    private func copyYesterdayButton(yesterdayEntries: [FoodLogEntry]) -> some View {
        Button {
            copyYesterday(yesterdayEntries)
        } label: {
            Text("Copy yesterday's meals")
                .calorynChip(isSelected: false)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("today.copyYesterday")
    }

    private func presentFoodSearch(
        mealType: MealType,
        snackIndex: Int,
        startsWithScanner: Bool = false
    ) {
        foodSearchPresentation = FoodSearchPresentation(
            mealType: mealType,
            logDate: selectedDate,
            snackIndex: snackIndex,
            startsWithScanner: startsWithScanner
        )
    }

    private func copyYesterday(_ yesterdayEntries: [FoodLogEntry]) {
        let orderedEntries = DayFoodLogSelection.copyOrdered(
            yesterdayEntries,
            mealType: \.mealType,
            createdAt: \.createdAt
        )
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.35)) {
            DailyFoodLogCommands.copyLoggedEntries(
                orderedEntries,
                to: selectedDate,
                modelContext: modelContext
            )
            try? modelContext.save()
        }
    }

    private func handlePendingRoute() {
        guard let route = router.consumePendingRoute() else { return }

        selectedDate = Date.now.startOfDay
        switch route {
        case .today:
            break
        case .nutritionDetails:
            showingNutritionDetails = true
        case .addFood(let widgetMeal):
            let mealType = MealType(widgetMeal: widgetMeal)
            presentFoodSearch(
                mealType: mealType,
                snackIndex: mealType == .snack ? 1 : 0
            )
        case .scanFood(let widgetMeal):
            let mealType = MealType(widgetMeal: widgetMeal)
            presentFoodSearch(
                mealType: mealType,
                snackIndex: mealType == .snack ? 1 : 0,
                startsWithScanner: true
            )
        }
    }

    private func followCalendarRollover() {
        selectedDate = SelectedDayRollover.selectedDay(
            selected: selectedDate,
            lastKnownToday: lastKnownToday
        )
        lastKnownToday = Date.now.startOfDay
    }

    private func recordDailyGoalSnapshotIfNeeded(calorieBudget: CalorieBudget) {
        guard let profile else { return }

        DailyGoalSnapshotStore.recordSnapshot(
            values: calorieBudget.goalSnapshotValues,
            for: selectedDate,
            profile: profile,
            in: modelContext
        )
    }

    private func deleteEntry(_ entry: FoodLogEntry) {
        withAnimation(.smooth(duration: 0.3)) {
            modelContext.delete(entry)
            try? modelContext.save()
        }
    }
}

#Preview {
    TodayView()
        .modelContainer(for: [UserProfile.self, FoodItem.self, FoodLogEntry.self, RecipeIngredient.self, MealTemplate.self, MealTemplateItem.self], inMemory: true)
        .environment(AppRouter())
}
