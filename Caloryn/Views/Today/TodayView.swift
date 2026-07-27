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
    @ScaledMetric private var ringSize: CGFloat = 180

    private var profile: UserProfile? { profiles.first }
    private var calorieBudget: ActivityCalorieBudget {
        guard let profile else {
            return ActivityCalorieBudget(
                consumed: totalCalories,
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
            consumed: totalCalories,
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

    private var todayEntries: [FoodLogEntry] {
        allEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var totalCalories: Double {
        todayEntries.reduce(0) { $0 + $1.calories }
    }

    private var nutriscoreDistribution: [(grade: String, count: Int)] {
        let grades = todayEntries.compactMap { $0.historicalNutriscoreGrade }
        let valid = ["a", "b", "c", "d", "e"]
        return valid.map { grade in
            (grade, grades.filter { $0.lowercased() == grade }.count)
        }.filter { $0.count > 0 }
    }

    private var hasNutriscoreData: Bool {
        todayEntries.contains { $0.historicalNutriscoreGrade != nil }
    }

    private var coreMeals: [MealType] {
        [.breakfast, .lunch, .dinner]
    }

    private var yesterdayEntries: [FoodLogEntry] {
        allEntries.filter {
            Calendar.current.isDate($0.date, inSameDayAs: selectedDate.yesterday)
        }
    }

    private var canCopyYesterday: Bool {
        todayEntries.isEmpty && !yesterdayEntries.isEmpty
    }

    private func entries(for meal: MealType) -> [FoodLogEntry] {
        todayEntries
            .filter { $0.mealType == meal }
            .sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                dateNavigator
                    .padding(.horizontal, CalorynTheme.pagePadding)

                List {
                    dashboardSection
                        .listRowInsets(EdgeInsets(top: 14, leading: 0, bottom: 12, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                    if showNutriscore, hasNutriscoreData {
                        Section {
                            nutriscoreSection
                        }
                        .listRowBackground(CalorynTheme.cardBackground)
                    }

                    ForEach(coreMeals) { meal in
                        MealSectionView(
                            mealType: meal,
                            entries: entries(for: meal),
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
                        entries: entries(for: .snack),
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
                        actionsSection
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
                nutritionDetailsSheet
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
            recordDailyGoalSnapshotIfNeeded()
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

    private var dashboardSection: some View {
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
    private var nutritionDetailsSheet: some View {
        let content = NutritionDetailsView(
            date: selectedDate,
            entries: todayEntries,
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

    private var nutriscoreSection: some View {
        NutriscoreDaySummary(distribution: nutriscoreDistribution, usesCard: false)
            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .center)))
    }

    private var copyYesterdayButton: some View {
        Button {
            copyYesterday()
        } label: {
            Label("Copy Yesterday's Meals", systemImage: "doc.on.doc")
                .font(CalorynTheme.buttonLabel)
                .foregroundStyle(CalorynTheme.sage)
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
        .accessibilityIdentifier("today.copyYesterday")
    }

    private var actionsSection: some View {
        Section {
            copyYesterdayButton
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

    private func copyYesterday() {
        let orderedEntries = yesterdayEntries.sorted {
            if $0.mealType.sortOrder != $1.mealType.sortOrder {
                return $0.mealType.sortOrder < $1.mealType.sortOrder
            }
            return $0.createdAt < $1.createdAt
        }
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

    private func recordDailyGoalSnapshotIfNeeded() {
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

private struct MissingFoodEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let entry: FoodLogEntry
    let onDelete: () -> Void

    @State private var date: Date
    @State private var mealType: MealType
    @State private var snackIndex: Int
    @State private var portionGrams: Double
    @State private var showingDeleteConfirmation = false
    @State private var errorMessage: String?

    init(entry: FoodLogEntry, onDelete: @escaping () -> Void) {
        self.entry = entry
        self.onDelete = onDelete
        _date = State(initialValue: entry.date)
        _mealType = State(initialValue: entry.mealType)
        _snackIndex = State(initialValue: max(1, entry.snackIndex))
        _portionGrams = State(initialValue: entry.portionGrams)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label {
                        Text("The original saved food is missing. Editing uses the nutrition and quality values recorded in this log entry.")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(CalorynTheme.terracotta)
                    }
                }
                .listRowBackground(CalorynTheme.cardBackground)

                Section("Entry") {
                    LabeledContent("Food", value: entry.foodName)

                    TextField("Portion (g)", value: $portionGrams, format: .number)
                        .keyboardType(.decimalPad)
                        .accessibilityLabel("Portion in grams")
                        .accessibilityIdentifier("missingEntry.portion")

                    DatePicker(
                        "Date",
                        selection: $date,
                        in: ...Date.now.tomorrow,
                        displayedComponents: .date
                    )

                    Picker("Meal", selection: $mealType) {
                        ForEach(MealType.allCases) { meal in
                            Text(meal.displayName).tag(meal)
                        }
                    }

                    if mealType == .snack {
                        Stepper("Snack slot: \(snackIndex)", value: $snackIndex, in: 1...20)
                            .accessibilityIdentifier("missingEntry.snackSlot")
                    }
                }
                .listRowBackground(CalorynTheme.cardBackground)

                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete Log Entry", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                }
                .listRowBackground(CalorynTheme.cardBackground)
            }
            .calorynFormStyle()
            .calorynSheetCanvas()
            .navigationTitle("Edit Portion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(CalorynTheme.toolbarIcon)
                            .foregroundStyle(CalorynTheme.sage)
                    }
                    .accessibilityLabel("Close")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        Text("Save")
                            .font(CalorynTheme.toolbarAction)
                            .foregroundStyle(
                                FavoriteFoodLogging.isSafePortion(portionGrams)
                                    ? CalorynTheme.sage
                                    : CalorynTheme.textSecondary
                            )
                    }
                    .disabled(!FavoriteFoodLogging.isSafePortion(portionGrams))
                    .accessibilityIdentifier("missingEntry.save")
                }
            }
            .confirmationDialog("Delete Log Entry", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
            } message: {
                Text("Remove \(entry.foodName) from your log?")
            }
            .alert("Couldn’t Update Entry", isPresented: errorIsPresented) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Please try again.")
            }
        }
    }

    private func save() {
        do {
            try DailyFoodLogCommands.saveSnapshotEntry(
                entry,
                date: date,
                mealType: mealType,
                portionGrams: portionGrams,
                modelContext: modelContext,
                snackIndex: snackIndex
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}

#Preview {
    TodayView()
        .modelContainer(for: [UserProfile.self, FoodItem.self, FoodLogEntry.self, RecipeIngredient.self, MealTemplate.self, MealTemplateItem.self], inMemory: true)
        .environment(AppRouter())
}
