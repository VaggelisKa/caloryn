import Combine
import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppRouter.self) private var router
    @Query(sort: \UserProfile.updatedAt, order: .reverse) private var profiles: [UserProfile]
    @Query private var allEntries: [FoodLogEntry]

    /// Apple's minimum touch target; a bare chevron glyph is smaller than this and the
    /// accessibility audit reports "Hit area is too small".
    private static let minimumHitTarget: CGFloat = 44

    private struct FoodSearchPresentation: Identifiable {
        let id = UUID()
        let mealType: MealType
        let logDate: Date
        let snackIndex: Int
        let startsWithScanner: Bool
    }

    @State private var selectedDate: Date = Date().startOfDay
    @State private var lastKnownToday: Date = Date().startOfDay
    @State private var showingNutritionDetails = false
    @State private var foodSearchPresentation: FoodSearchPresentation?
    @State private var entryToEdit: FoodLogEntry?

    @AppStorage("showNutriscore") private var showNutriscore = true
    @State private var activeEnergyTracker = ActiveEnergyDayTracker()
    private let ringSize: CGFloat = 180

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

        NavigationStack {
            VStack(spacing: 0) {
                dateNavigator
                    .padding(.horizontal, CalorynTheme.pagePadding)

                List {
                    dashboardSection(calorieBudget: calorieBudget)
                        .listRowInsets(EdgeInsets(top: 14, leading: 0, bottom: 12, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                    if showNutriscore, hasNutriscoreData {
                        Section {
                            nutriscoreSection(distribution: nutriscoreDistribution)
                        }
                        .listRowBackground(CalorynTheme.cardBackground)
                    }

                    ForEach(coreMeals) { meal in
                        MealSectionView(
                            mealType: meal,
                            entries: projection.entries(for: meal),
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
                        onAdd: {
                            presentFoodSearch(mealType: .snack, snackIndex: 1)
                        },
                        onEdit: { entry in
                            entryToEdit = entry
                        },
                        onDelete: deleteEntry
                    )

                    if canCopyYesterday {
                        actionsSection(yesterdayEntries: projection.yesterday)
                    }
                }
                .calorynGroupedListStyle()
                .contentMargins(.top, 0, for: .scrollContent)
                .id(selectedDate)
                .animation(.smooth(duration: 0.35), value: hasNutriscoreData)
            }
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

    private var dateNavigator: some View {
        HStack {
            Button {
                withAnimation {
                    selectedDate = selectedDate.yesterday
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(CalorynTheme.inlineIcon)
                    .foregroundStyle(CalorynTheme.sage)
                    .frame(minWidth: Self.minimumHitTarget, minHeight: Self.minimumHitTarget, alignment: .leading)
                    .contentShape([.interaction, .accessibility], .rect)
            }
            .accessibilityLabel("Previous day")
            .accessibilityIdentifier("today.previousDay")

            Spacer()

            Text(selectedDate.shortFormatted)
                .font(CalorynTheme.sectionTitle)
                .foregroundStyle(CalorynTheme.textPrimary)
                .contentTransition(.numericText())
                .accessibilityAddTraits(.isHeader)

            Spacer()

            Button {
                withAnimation {
                    selectedDate = selectedDate.tomorrow
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(CalorynTheme.inlineIcon)
                    .foregroundStyle(selectedDate.isAtFutureLogLimit ? CalorynTheme.textSecondary.opacity(0.3) : CalorynTheme.sage)
                    .frame(minWidth: Self.minimumHitTarget, minHeight: Self.minimumHitTarget, alignment: .trailing)
                    .contentShape([.interaction, .accessibility], .rect)
            }
            .disabled(selectedDate.isAtFutureLogLimit)
            .accessibilityLabel("Next day")
            .accessibilityIdentifier("today.nextDay")
        }
        .padding(.vertical, 8)
    }

    private func dashboardSection(calorieBudget: ActivityCalorieBudget) -> some View {
        HStack {
            Spacer()
            CalorieRingView(
                calorieBudget: calorieBudget,
                ringSize: ringSize
            ) {
                withAnimation(.smooth(duration: 0.2)) {
                    showingNutritionDetails = true
                }
            }
            .accessibilityIdentifier("today.calorieRing")
            Spacer()
        }
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

    private func nutriscoreSection(distribution: [(grade: String, count: Int)]) -> some View {
        NutriscoreDaySummary(distribution: distribution, usesCard: false)
            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .center)))
    }

    private func copyYesterdayButton(yesterdayEntries: [FoodLogEntry]) -> some View {
        Button {
            copyYesterday(yesterdayEntries)
        } label: {
            Label("Copy Yesterday's Meals", systemImage: "doc.on.doc")
                .font(CalorynTheme.buttonLabel)
                .foregroundStyle(CalorynTheme.sage)
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
        .accessibilityIdentifier("today.copyYesterday")
    }

    private func actionsSection(yesterdayEntries: [FoodLogEntry]) -> some View {
        Section {
            copyYesterdayButton(yesterdayEntries: yesterdayEntries)
        } header: {
            Color.clear
                .frame(height: 10)
        }
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
