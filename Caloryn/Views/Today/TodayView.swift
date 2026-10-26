import Combine
import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(AppRouter.self) private var router
    @Query(sort: \UserProfile.updatedAt, order: .reverse) private var profiles: [UserProfile]
    @Query private var allEntries: [FoodLogEntry]

    /// Apple's minimum touch target; a bare chevron glyph is smaller than this and the
    /// accessibility audit reports "Hit area is too small".
    private static let minimumHitTarget: CGFloat = 44
    /// The glass circle drawn inside each day button's hit target.
    private static let dayButtonSize: CGFloat = 36

    private struct FoodSearchPresentation: Identifiable {
        let id = UUID()
        let mealType: MealType
        let logDate: Date
        let snackIndex: Int
        let startsWithScanner: Bool
    }

    /// Whether the page is offered more width than height, read from its own proposal. The
    /// split needs regular width *and* a landscape proposal: in portrait the open inner
    /// display is 669×951pt, and a dashboard-over-meals split there clipped the Nutri-Score
    /// chips under the top region while the single list had room for everything.
    @State private var isWiderThanTall = false

    @State private var selectedDate: Date = Date().startOfDay
    @State private var lastKnownToday: Date = Date().startOfDay
    @State private var showingNutritionDetails = false
    @State private var foodSearchPresentation: FoodSearchPresentation?
    @State private var entryToEdit: FoodLogEntry?

    @AppStorage("showNutriscore") private var showNutriscore = true
    @State private var activeEnergyTracker = ActiveEnergyDayTracker()

    private var profile: UserProfile? { profiles.first }
    private func calorieBudget(consumed: Double) -> ActivityCalorieBudget {
        guard let profile else {
            return ActivityCalorieBudget(
                consumed: consumed,
                staticTarget: 2_000,
                bmr: 1_700,
                calorieDeficit: 0,
                activeEnergyKcal: 0,
                recentActiveEnergySamples: [],
                calculationMode: .lifestyleEstimate,
                isManualOverride: false,
                isActivityLoading: false,
                activityMessage: nil,
                date: selectedDate
            )
        }

        return profile.activityBudget(
            consumed: consumed,
            activeEnergyKcal: activeEnergyTracker.activeEnergyKcal,
            recentActiveEnergySamples: activeEnergyTracker.recentActiveEnergySamples,
            isActivityLoading: activeEnergyTracker.isLoading,
            activityMessage: activeEnergyTracker.message,
            date: selectedDate
        )
    }
    private var healthRefreshKey: String {
        "\(selectedDate.timeIntervalSinceReferenceDate)-\(profile?.effectiveEnergyCalculationMode.rawValue ?? EnergyCalculationMode.lifestyleEstimate.rawValue)"
    }

    private var coreMeals: [MealType] {
        DayFoodLogSelection.coreMeals
    }

    private var dayProjection: DayFoodLogProjection<FoodLogEntry> {
        DayFoodLogProjection(
            allEntries,
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

        let dashboard = DashboardContent(
            entries: projection.today,
            yesterdayEntries: projection.yesterday,
            calorieBudget: calorieBudget,
            nutriscoreDistribution: nutriscoreDistribution,
            showsNutriscore: showNutriscore && hasNutriscoreData,
            canCopyYesterday: canCopyYesterday
        )

        NavigationStack {
            Group {
                // Regular width *and* height is the open inner display of iPhone Duo (and
                // nothing else on iPhone). Held landscape — flat, or partially folded like a
                // book or a laptop — there is room for the dashboard beside the meals.
                // Everything else keeps the single scrolling page: portrait on the inner
                // display, every other iPhone, the closed Duo, and Split View on the open one.
                if horizontalSizeClass == .regular, verticalSizeClass == .regular, isWiderThanTall {
                    dashboardAndMeals(dashboard, projection: projection)
                } else {
                    dashboardOverMeals(dashboard, projection: projection)
                }
            }
            .onGeometryChange(for: Bool.self) { proxy in
                proxy.size.width > proxy.size.height
            } action: { isWiderThanTall = $0 }
            .calorynPageCanvas()
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
        .task(id: healthRefreshKey) {
            await activeEnergyTracker.configure(
                date: selectedDate,
                isEnabled: profile?.effectiveEnergyCalculationMode == .dynamicHealth
            )
        }
        .task(id: router.pendingRoute) {
            handlePendingRoute()
        }
        .task(id: calorieBudget) {
            recordDailyGoalSnapshotIfNeeded(calorieBudget: calorieBudget)
        }
        .onDisappear {
            activeEnergyTracker.stopObserving()
        }
        .onChange(of: activeEnergyTracker.message) { _, message in
            guard message != nil, profile?.energyCalculationMode == .dynamicHealth else { return }
            profile?.energyCalculationMode = .lifestyleEstimate
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            followCalendarRollover()
            activeEnergyTracker.refreshWhenActive()
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
        let calorieBudget: ActivityCalorieBudget
        let nutriscoreDistribution: [(grade: String, count: Int)]
        let showsNutriscore: Bool
        let canCopyYesterday: Bool
    }

    /// Compact width: one list, the dashboard as its first rows so the date scrolls away
    /// with the day instead of staying pinned over it.
    private func dashboardOverMeals(
        _ dashboard: DashboardContent,
        projection: DayFoodLogProjection<FoodLogEntry>
    ) -> some View {
        List {
            dateNavigator
                .todayPlateRowLayout(top: 4, bottom: 0)
                .calorynClearRowBackground()
                .listRowSeparator(.hidden)

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

            mealRows(projection: projection, canCopyYesterday: dashboard.canCopyYesterday)
        }
        .calorynPlainListStyle()
        // Rows size to the board's 41pt rather than the system's 44pt minimum; each
        // is still a full-width tap target.
        .environment(\.defaultMinListRowHeight, 0)
        .contentMargins(.top, 0, for: .scrollContent)
        .id(selectedDate)
        .animation(.smooth(duration: 0.35), value: dashboard.showsNutriscore)
    }

    /// Regular width and height, landscape: the dashboard is one region and the meals the
    /// other. The split arrangement puts them side by side on the flat display, and
    /// rearranges them around the fold when iPhone Duo is partially open — the axes are left
    /// unconstrained so a horizontal fold (the laptop pose) can stack them instead. Same
    /// content, same order, same controls as the compact page; only the meals scroll on
    /// their own.
    ///
    /// The arrangement view is iOS 27.1; before it the same two regions sit in an `HStack`.
    @ViewBuilder
    private func dashboardAndMeals(
        _ dashboard: DashboardContent,
        projection: DayFoodLogProjection<FoodLogEntry>
    ) -> some View {
        if #available(iOS 27.1, *) {
            ArrangementView {
                dashboardColumn(dashboard)
                    // Enough for the hero: a 168pt donut beside its number column needs about
                    // 380pt, and the dashboard is about 340pt tall. No maximum, so the divider
                    // can still land on the fold in the book pose.
                    .splitArrangementLayoutRatio(
                        minHorizontal: 0.36,
                        idealHorizontal: 0.4,
                        minVertical: 0.38,
                        idealVertical: 0.42
                    )
            } secondary: {
                mealsList(projection: projection, canCopyYesterday: dashboard.canCopyYesterday)
            }
            .arrangementViewStyle(.split)
        } else {
            HStack(alignment: .top, spacing: 0) {
                dashboardColumn(dashboard)
                    .containerRelativeFrame(.horizontal) { width, _ in width * 0.4 }

                mealsList(projection: projection, canCopyYesterday: dashboard.canCopyYesterday)
            }
        }
    }

    /// The dashboard rows as a page of their own, spaced as the list rows are.
    private func dashboardColumn(_ dashboard: DashboardContent) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                dateNavigator
                    .padding(.top, 4)

                dashboardSection(entries: dashboard.entries, calorieBudget: dashboard.calorieBudget)
                    .padding(.top, 12)
                    .padding(.bottom, 4)

                if dashboard.showsNutriscore {
                    nutriscoreSection(distribution: dashboard.nutriscoreDistribution)
                        .padding(.top, 10)
                } else if dashboard.canCopyYesterday {
                    copyYesterdayButton(yesterdayEntries: dashboard.yesterdayEntries)
                        .padding(.top, 10)
                }
            }
            .padding(.horizontal, CalorynTheme.pagePadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.smooth(duration: 0.35), value: dashboard.showsNutriscore)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func mealsList(
        projection: DayFoodLogProjection<FoodLogEntry>,
        canCopyYesterday: Bool
    ) -> some View {
        List {
            mealRows(projection: projection, canCopyYesterday: canCopyYesterday)
        }
        .calorynPlainListStyle()
        .environment(\.defaultMinListRowHeight, 0)
        .contentMargins(.top, 0, for: .scrollContent)
        .id(selectedDate)
    }

    @ViewBuilder
    private func mealRows(
        projection: DayFoodLogProjection<FoodLogEntry>,
        canCopyYesterday: Bool
    ) -> some View {
        ForEach(coreMeals) { meal in
            MealSectionView(
                mealType: meal,
                entries: projection.entries(for: meal),
                canCopyYesterday: canCopyYesterday,
                onAdd: {
                    presentFoodSearch(mealType: meal, snackIndex: 0)
                },
                onEdit: { entry in
                    entryToEdit = entry
                },
                onDelete: deleteEntry
            )
        }

        MealSectionView(
            mealType: .snack,
            entries: projection.entries(for: .snack),
            snackIndex: 1,
            titleOverride: "Snacks",
            canCopyYesterday: canCopyYesterday,
            onAdd: {
                presentFoodSearch(mealType: .snack, snackIndex: 1)
            },
            onEdit: { entry in
                entryToEdit = entry
            },
            onDelete: deleteEntry
        )
    }

    /// "Friday 17 October" on the left, previous and next day as glass circles on the right.
    ///
    /// One line, as the board draws it, until accessibility sizes: there the chevrons leave
    /// the title about 246pt, and "Wednesday 30 September" would need to shrink below the
    /// 0.7 floor and truncate. The title wraps instead.
    private var dateNavigator: some View {
        HStack(spacing: 12) {
            Text(DayTitle.text(for: selectedDate))
                .font(TodayPlateFont.dateTitle)
                .tracking(-0.2)
                .foregroundStyle(CalorynTheme.textPrimary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())
                .accessibilityLabel(DayTitle.accessibilityLabel(for: selectedDate))
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 8)

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
            // The 44pt hit targets overhang the 36pt circles by 4pt each side; pull the pair
            // back so the right-hand circle sits on the page margin as the board draws it.
            .padding(.trailing, -(Self.minimumHitTarget - Self.dayButtonSize) / 2)
        }
        .padding(.top, 4)
        .padding(.bottom, 4)
    }

    /// A 36pt glass circle inside a 44pt hit target — Apple's minimum; the accessibility audit
    /// reports a bare 36pt control as "Hit area is too small".
    private func dayButton(
        systemImage: String,
        label: String,
        identifier: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            withAnimation {
                action()
            }
        } label: {
            Image(systemName: systemImage)
                .font(CalorynTheme.inlineIcon)
                .imageScale(.small)
                .foregroundStyle(isEnabled ? CalorynTheme.textPrimary : CalorynTheme.textTertiary)
                .frame(width: Self.dayButtonSize, height: Self.dayButtonSize)
                // Tinted with the card colour, as PlateDark draws filled discs: clear glass
                // on the dark page showed nothing but its rim.
                .adaptiveCircleInteractiveGlass(tint: CalorynTheme.cardBackground)
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
        calorieBudget: ActivityCalorieBudget
    ) -> some View {
        CalorieHeroView(
            summary: TodayHeroSummary(
                mealTotals: TodayHeroSummary.mealTotals(
                    entries,
                    mealType: \.mealType,
                    calories: \.calories
                ),
                budget: calorieBudget
            )
        ) {
            withAnimation(.smooth(duration: 0.2)) {
                showingNutritionDetails = true
            }
        }
        .accessibilityIdentifier("today.calorieRing")
    }

    @ViewBuilder
    private func nutritionDetailsSheet(
        entries: [FoodLogEntry],
        calorieBudget: ActivityCalorieBudget
    ) -> some View {
        let content = NutritionDetailsView(
            date: selectedDate,
            entries: entries,
            calorieBudget: calorieBudget,
            nutrientTargets: profile?.nutrientTargets(forCalorieTarget: calorieBudget.adjustedTarget) ?? [:],
            nutrientGoalKinds: profile?.nutrientGoalKinds ?? [:]
        )

        if #available(iOS 26.0, *) {
            content
                .presentationBackground(.regularMaterial)
        } else {
            content
                .presentationBackground(CalorynTheme.cardBackground)
        }
    }

    /// The day's Nutri-Score chips under a label in the style of the meal headers below it
    /// (17pt bold, ink, as a non-meal section is titled), so the badges are not left to
    /// explain themselves. One stop for VoiceOver: the chips already read "Nutri-Score today:
    /// 3 A, 1 C", so the label is not read again before them.
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

    /// Copies all of yesterday's log onto an empty day. Shown under the hero, in the slot the
    /// Nutri-Score chips take once anything is logged, because it is only ever offered while
    /// the day is empty — and every empty meal row points at it ("or copy yesterday's").
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
        DailyFoodLogCommands.copyLoggedEntries(
            orderedEntries,
            to: selectedDate,
            modelContext: modelContext
        )
        try? modelContext.save()
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

    /// Persists today's effective calorie target so History can later compare
    /// the day against the goal that actually applied. Only the current
    /// calendar day is ever recorded (the store enforces this), and the last
    /// write before midnight finalizes the day.
    /// Keeps the screen on the current day when the calendar rolls over while
    /// the app is open, so the new day still gets its goal snapshot.
    private func followCalendarRollover() {
        selectedDate = SelectedDayRollover.selectedDay(
            selected: selectedDate,
            lastKnownToday: lastKnownToday
        )
        lastKnownToday = Date.now.startOfDay
    }

    private func recordDailyGoalSnapshotIfNeeded(calorieBudget: ActivityCalorieBudget) {
        guard let profile else { return }
        // Skip transient budgets while Health data is still loading so a
        // dynamic day is not momentarily snapshotted without its adjustment.
        guard !calorieBudget.isActivityLoading else { return }

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
