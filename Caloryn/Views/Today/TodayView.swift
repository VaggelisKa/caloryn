import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \UserProfile.updatedAt, order: .reverse) private var profiles: [UserProfile]
    @Query private var allEntries: [FoodLogEntry]

    private struct FoodSearchPresentation: Identifiable {
        let id = UUID()
        let mealType: MealType
        let logDate: Date
        let snackIndex: Int
    }

    @State private var selectedDate: Date = Date().startOfDay
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
                .listStyle(.insetGrouped)
                .listSectionSpacing(.custom(16))
                .contentMargins(.top, 0, for: .scrollContent)
                .animation(.smooth(duration: 0.35), value: hasNutriscoreData)
            }
            .background(CalorynTheme.pageBackground)
            .sheet(item: $foodSearchPresentation) { presentation in
                FoodSearchView(
                    mealType: presentation.mealType,
                    logDate: presentation.logDate,
                    snackIndex: presentation.snackIndex
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
        NutriscoreDaySummary(distribution: nutriscoreDistribution, usesCard: false)
            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .center)))
    }

    private var copyYesterdayButton: some View {
        Button {
            withAnimation {
                copyEntries(from: yesterdayEntries)
            }
        } label: {
            Label("Copy Yesterday's Meals", systemImage: "doc.on.doc")
                .font(CalorynTheme.buttonLabel)
                .foregroundStyle(CalorynTheme.sage)
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }

    private var actionsSection: some View {
        Section {
            copyYesterdayButton
        } header: {
            Color.clear
                .frame(height: 10)
        }
    }

    private func presentFoodSearch(mealType: MealType, snackIndex: Int) {
        foodSearchPresentation = FoodSearchPresentation(
            mealType: mealType,
            logDate: selectedDate,
            snackIndex: snackIndex
        )
    }

    private func deleteEntry(_ entry: FoodLogEntry) {
        withAnimation(.smooth(duration: 0.3)) {
            modelContext.delete(entry)
            try? modelContext.save()
        }
    }

    private func copyEntries(from entries: [FoodLogEntry]) {
        for entry in entries {
            guard let food = entry.foodItem else { continue }
            let newEntry = FoodLogEntry(
                date: selectedDate,
                mealType: entry.mealType,
                foodItem: food,
                portionGrams: entry.portionGrams,
                snackIndex: entry.mealType == .snack ? 1 : entry.snackIndex
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
                        Label("Delete", systemImage: "trash.fill")
                            .font(CalorynTheme.toolbarIcon)
                            .foregroundStyle(.red)
                    }
                    .tint(.red)
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
