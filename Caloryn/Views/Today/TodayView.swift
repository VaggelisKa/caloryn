import Combine
import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppRouter.self) private var router
    @Query(sort: \UserProfile.updatedAt, order: .reverse) private var profiles: [UserProfile]
    @Query private var allEntries: [FoodLogEntry]

    private static let minimumHitTarget: CGFloat = 44
    private static let dayButtonSize: CGFloat = 36

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
                List {
                    dateNavigator
                        .todayPlateRowLayout(top: 4, bottom: 0)
                        .calorynClearRowBackground()
                        .listRowSeparator(.hidden)

                    dashboardSection(entries: projection.today, calorieBudget: calorieBudget)
                        .todayPlateRowLayout(top: 12, bottom: 4)
                        .calorynClearRowBackground()
                        .listRowSeparator(.hidden)

                    if showNutriscore, hasNutriscoreData {
                        nutriscoreSection(distribution: nutriscoreDistribution)
                            .todayPlateRowLayout(top: 10)
                            .calorynClearRowBackground()
                            .listRowSeparator(.hidden)
                    } else if canCopyYesterday {
                        copyYesterdayButton(yesterdayEntries: projection.yesterday)
                            .todayPlateRowLayout(top: 10)
                            .calorynClearRowBackground()
                            .listRowSeparator(.hidden)
                    }

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
                .calorynPlainListStyle()
                .environment(\.defaultMinListRowHeight, 0)
                .contentMargins(.top, 0, for: .scrollContent)
                .id(selectedDate)
                .animation(.smooth(duration: 0.35), value: hasNutriscoreData)
                .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: projection.today.map(\.id))
            }
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
        .onReceive(
            NotificationCenter.default
                .publisher(for: .NSCalendarDayChanged)
                .receive(on: RunLoop.main)
        ) { _ in
            followCalendarRollover()
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
                .foregroundStyle(isEnabled ? CalorynTheme.textPrimary : CalorynTheme.textTertiary)
                .frame(width: Self.dayButtonSize, height: Self.dayButtonSize)
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

    private func recordDailyGoalSnapshotIfNeeded(calorieBudget: ActivityCalorieBudget) {
        guard let profile else { return }
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
