import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \UserProfile.updatedAt, order: .reverse) private var profiles: [UserProfile]
    @Query private var allEntries: [FoodLogEntry]

    @State private var selectedDate: Date = Date().startOfDay
    @State private var showingFoodSearch = false
    @State private var showingNutritionDetails = false
    @State private var selectedMealType: MealType = .breakfast
    @State private var selectedSnackIndex: Int = 1
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
        let grades = todayEntries.compactMap { $0.foodItem?.nutriscoreGrade }
        let valid = ["a", "b", "c", "d", "e"]
        return valid.map { grade in
            (grade, grades.filter { $0.lowercased() == grade }.count)
        }.filter { $0.count > 0 }
    }

    private var hasNutriscoreData: Bool {
        todayEntries.contains { $0.foodItem?.nutriscoreGrade != nil }
    }

    private var coreMeals: [MealType] {
        [.breakfast, .lunch, .dinner]
    }

    private var snackIndices: [Int] {
        let existing = Set(
            todayEntries
                .filter { $0.mealType == .snack }
                .map { $0.snackIndex }
        )
        let all = existing.union([1])
        return all.sorted()
    }

    private func entries(for meal: MealType) -> [FoodLogEntry] {
        todayEntries
            .filter { $0.mealType == meal }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private func snackEntries(for index: Int) -> [FoodLogEntry] {
        todayEntries
            .filter { $0.mealType == .snack && $0.snackIndex == index }
            .sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                dateNavigator
                    .padding(.horizontal, CalorynTheme.pagePadding)

                ScrollView {
                    VStack(spacing: CalorynTheme.cardSpacing) {
                        dashboardSection

                        if showNutriscore, hasNutriscoreData {
                            nutriscoreSection
                        }

                        ForEach(coreMeals) { meal in
                            MealSectionView(
                                mealType: meal,
                                entries: entries(for: meal),
                                onAdd: {
                                    selectedMealType = meal
                                    selectedSnackIndex = 0
                                    showingFoodSearch = true
                                },
                                onEdit: { entry in
                                    entryToEdit = entry
                                }
                            )
                        }

                        ForEach(snackIndices, id: \.self) { index in
                            MealSectionView(
                                mealType: .snack,
                                entries: snackEntries(for: index),
                                snackIndex: index,
                                onAdd: {
                                    selectedMealType = .snack
                                    selectedSnackIndex = index
                                    showingFoodSearch = true
                                },
                                onEdit: { entry in
                                    entryToEdit = entry
                                }
                            )
                        }

                        CalorynCard {
                            VStack(alignment: .leading, spacing: 12) {
                                addSnackButton
                                copyYesterdayButton
                            }
                        }
                    }
                    .padding(.horizontal, CalorynTheme.pagePadding)
                    .padding(.top, CalorynTheme.cardSpacing)
                    .padding(.bottom, 20)
                    .animation(.smooth(duration: 0.35), value: hasNutriscoreData)
                }
                .background(CalorynTheme.pageBackground)
            }
            .background(CalorynTheme.pageBackground)
            .sheet(isPresented: $showingFoodSearch) {
                FoodSearchView(mealType: selectedMealType, logDate: selectedDate, snackIndex: selectedSnackIndex)
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
                            existingEntry: entry
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
                NutritionDetailsView(
                    date: selectedDate,
                    entries: todayEntries,
                    calorieBudget: calorieBudget,
                    nutrientTargets: profile?.nutrientTargets(forCalorieTarget: calorieBudget.adjustedTarget) ?? [:],
                    nutrientGoalKinds: profile?.nutrientGoalKinds ?? [:]
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        .task(id: healthRefreshKey) {
            await activeEnergyTracker.configure(
                date: selectedDate,
                isEnabled: profile?.effectiveEnergyCalculationMode == .dynamicHealth
            )
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
            activeEnergyTracker.refreshWhenActive()
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
            }
            .accessibilityLabel("Previous day")

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
            }
            .disabled(selectedDate.isAtFutureLogLimit)
            .accessibilityLabel("Next day")
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
            Spacer()
        }
    }

    private var nutriscoreSection: some View {
        NutriscoreDaySummary(distribution: nutriscoreDistribution)
            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .center)))
    }

    private var addSnackButton: some View {
        Button {
            let nextIndex = (snackIndices.last ?? 0) + 1
            selectedMealType = .snack
            selectedSnackIndex = nextIndex
            showingFoodSearch = true
        } label: {
            Label("Add Snack", systemImage: "plus.circle")
                .font(CalorynTheme.buttonLabel)
                .foregroundStyle(CalorynTheme.sage)
        }
    }

    private var copyYesterdayButton: some View {
        let yesterdayEntries = allEntries.filter {
            Calendar.current.isDate($0.date, inSameDayAs: selectedDate.yesterday)
        }

        return Group {
            if todayEntries.isEmpty && !yesterdayEntries.isEmpty {
                Button {
                    withAnimation {
                        copyEntries(from: yesterdayEntries)
                    }
                } label: {
                    Label("Copy Yesterday's Meals", systemImage: "doc.on.doc")
                        .font(CalorynTheme.buttonLabel)
                        .foregroundStyle(CalorynTheme.sage)
                }
            }
        }
    }

    private func deleteEntry(_ entry: FoodLogEntry) {
        withAnimation {
            modelContext.delete(entry)
        }
        try? modelContext.save()
    }

    private func copyEntries(from entries: [FoodLogEntry]) {
        for entry in entries {
            guard let food = entry.foodItem else { continue }
            let newEntry = FoodLogEntry(
                date: selectedDate,
                mealType: entry.mealType,
                foodItem: food,
                portionGrams: entry.portionGrams,
                snackIndex: entry.snackIndex
            )
            modelContext.insert(newEntry)
        }
        try? modelContext.save()
    }
}

private struct MissingFoodEntryView: View {
    @Environment(\.dismiss) private var dismiss

    let entry: FoodLogEntry
    let onDelete: () -> Void

    @State private var showingDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Food Missing",
                systemImage: "exclamationmark.triangle",
                description: Text("\(entry.foodName) no longer has a food attached.")
            )
            .navigationTitle("Edit Portion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(CalorynTheme.toolbarIcon)
                    }
                    .accessibilityLabel("Close")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                            .font(CalorynTheme.toolbarIcon)
                    }
                    .tint(CalorynTheme.terracotta)
                    .accessibilityLabel("Delete Log Entry")
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
        }
    }
}

#Preview {
    TodayView()
        .modelContainer(for: [UserProfile.self, FoodItem.self, FoodLogEntry.self, RecipeIngredient.self], inMemory: true)
}
