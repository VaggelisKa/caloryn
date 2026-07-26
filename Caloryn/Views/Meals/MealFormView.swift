import SwiftData
import SwiftUI

private struct MealComponentDraft: Identifiable {
    let id: UUID
    var snapshot: FoodLogEntrySnapshot

    init(id: UUID = UUID(), foodItem: FoodItem) {
        self.id = id
        snapshot = FoodLogEntrySnapshot(
            foodItem: foodItem,
            portionGrams: foodItem.defaultServingG ?? 100
        )
    }

    init?(item: MealTemplateItem) {
        guard let data = item.snapshotData,
              let snapshot = try? JSONDecoder().decode(FoodLogEntrySnapshot.self, from: data) else {
            return nil
        }
        id = item.id
        self.snapshot = snapshot
    }

    var amountDraft: RecipeIngredientDraft {
        let portionGrams = snapshot.portionGrams
        let nutritionPer100g = portionGrams > 0
            ? snapshot.nutrition.scaled(by: 100 / portionGrams)
            : .zero

        return RecipeIngredientDraft(
            id: id,
            name: snapshot.foodName,
            brand: nil,
            portionGrams: portionGrams,
            caloriesPer100g: nutritionPer100g.calories,
            proteinPer100g: nutritionPer100g.proteinG,
            carbsPer100g: nutritionPer100g.carbsG,
            fatPer100g: nutritionPer100g.fatG,
            fiberPer100g: nutritionPer100g.fiberG,
            sugarsPer100g: nutritionPer100g.sugarsG,
            addedSugarsPer100g: nutritionPer100g.addedSugarsG,
            sucrosePer100g: nutritionPer100g.sucroseG,
            glucosePer100g: nutritionPer100g.glucoseG,
            fructosePer100g: nutritionPer100g.fructoseG,
            lactosePer100g: nutritionPer100g.lactoseG,
            maltosePer100g: nutritionPer100g.maltoseG,
            maltodextrinsPer100g: nutritionPer100g.maltodextrinsG,
            starchPer100g: nutritionPer100g.starchG,
            polyolsPer100g: nutritionPer100g.polyolsG,
            saturatedFatPer100g: nutritionPer100g.saturatedFatG,
            transFatPer100g: nutritionPer100g.transFatG,
            monounsaturatedFatPer100g: nutritionPer100g.monounsaturatedFatG,
            polyunsaturatedFatPer100g: nutritionPer100g.polyunsaturatedFatG,
            omega3FatPer100g: nutritionPer100g.omega3FatG,
            omega6FatPer100g: nutritionPer100g.omega6FatG,
            omega9FatPer100g: nutritionPer100g.omega9FatG,
            saltPer100g: nutritionPer100g.saltG,
            sodiumPer100g: nutritionPer100g.sodiumG,
            cholesterolPer100g: nutritionPer100g.cholesterolG,
            solubleFiberPer100g: nutritionPer100g.solubleFiberG,
            insolubleFiberPer100g: nutritionPer100g.insolubleFiberG,
            caseinPer100g: nutritionPer100g.caseinG,
            serumProteinsPer100g: nutritionPer100g.serumProteinsG,
            alcoholPer100g: nutritionPer100g.alcoholG,
            sortOrder: 0,
            produceKind: ProduceKind(rawValue: snapshot.produceKindSnapshotRaw ?? "")
                ?? .unclassified
        )
    }

    func updatingPortion(to grams: Double) -> MealComponentDraft {
        var copy = self
        copy.snapshot = snapshot.scaled(toPortionGrams: grams)
        return copy
    }
}

struct MealFormView: View {
    let existingMeal: MealTemplate?
    let onSaved: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var components: [MealComponentDraft] = []
    @State private var showingFoodSearch = false
    @State private var componentForAmount: MealComponentDraft?
    @State private var showingDeleteConfirmation = false
    @State private var errorMessage: String?
    @State private var isSaving = false
    @FocusState private var nameIsFocused: Bool

    init(
        existingMeal: MealTemplate? = nil,
        onSaved: (() -> Void)? = nil
    ) {
        self.existingMeal = existingMeal
        self.onSaved = onSaved
    }

    private var isEditing: Bool {
        existingMeal != nil
    }

    private var totalNutrition: NutritionValues {
        components.reduce(.zero) { $0 + $1.snapshot.nutrition }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !components.isEmpty
            && components.allSatisfy { $0.snapshot.portionGrams > 0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    nameSection
                    summaryCard
                    componentsSection

                    if isEditing {
                        deleteSection
                    }
                }
                .padding(.horizontal, CalorynTheme.pagePadding)
                .padding(.bottom, 24)
            }
            .calorynSheetCanvas()
            .navigationTitle(isEditing ? "Edit Meal" : "Create Meal")
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

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveMeal()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Image(systemName: "checkmark")
                                .font(CalorynTheme.toolbarIcon)
                        }
                    }
                    .accessibilityLabel("Save Meal")
                    .disabled(!canSave || isSaving)
                }
            }
            .onAppear(perform: populateFromExisting)
            .sheet(isPresented: $showingFoodSearch) {
                FoodSearchView(
                    mealType: .breakfast,
                    logDate: .now,
                    mode: .mealComponentSelection { food in
                        showingFoodSearch = false
                        let component = MealComponentDraft(foodItem: food)
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(250))
                            componentForAmount = component
                        }
                    }
                )
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $componentForAmount) { component in
                IngredientAmountPickerView(ingredient: component.amountDraft) { updated in
                    upsert(component.updatingPortion(to: updated.portionGrams))
                }
            }
            .confirmationDialog("Delete Meal", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive, action: deleteMeal)
            } message: {
                Text("This will permanently remove \"\(name)\" from your meals.")
            }
            .alert("Couldn’t Save Meal", isPresented: errorIsPresented) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Please try again.")
            }
        }
        .presentationDetents([.large])
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MEAL DETAILS")
                .font(CalorynTheme.sectionEyebrow)
                .foregroundStyle(CalorynTheme.textSecondary)

            TextField("Meal name (e.g. Weekday Breakfast)", text: $name)
                .font(CalorynTheme.bodyText)
                .textInputAutocapitalization(.words)
                .focused($nameIsFocused)
                .calorynInputField(isFocused: nameIsFocused)
        }
        .glassCard(cornerRadius: CalorynTheme.smallCornerRadius)
    }

    private var summaryCard: some View {
        VStack(spacing: 14) {
            VStack(spacing: 4) {
                Text(totalNutrition.calories.kcalFormatted)
                    .font(CalorynTheme.displayNumber)
                    .foregroundStyle(CalorynTheme.sage)
                    .contentTransition(.numericText())
                    .animation(.smooth(duration: 0.3), value: totalNutrition.calories)

                Text(components.count == 1 ? "1 item" : "\(components.count) items")
                    .font(CalorynTheme.bodyText)
                    .foregroundStyle(CalorynTheme.textSecondary)
            }

            HStack(spacing: CalorynTheme.cardSpacing) {
                summaryMetric("Protein", value: totalNutrition.proteinG, color: CalorynTheme.proteinColor)
                summaryMetric("Carbs", value: totalNutrition.carbsG, color: CalorynTheme.carbColor)
                summaryMetric("Fat", value: totalNutrition.fatG, color: CalorynTheme.fatColor)
                summaryMetric("Fiber", value: totalNutrition.fiberG, color: CalorynTheme.fiberColor)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .glassCard()
    }

    private func summaryMetric(_ label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(CalorynTheme.caption)
                .foregroundStyle(CalorynTheme.textSecondary)
            Text(value.macroFormatted)
                .font(CalorynTheme.numericBody)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    private var componentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("ITEMS")
                    .font(CalorynTheme.sectionEyebrow)
                    .foregroundStyle(CalorynTheme.textSecondary)

                Spacer()

                Button {
                    showingFoodSearch = true
                } label: {
                    Label("Add Item", systemImage: "plus.circle")
                        .font(CalorynTheme.buttonLabel)
                }
            }

            if components.isEmpty {
                ContentUnavailableView(
                    "No Items",
                    systemImage: "fork.knife",
                    description: Text("Add foods, manual entries, or recipes.")
                )
                .frame(minHeight: 160)
            } else {
                VStack(spacing: 0) {
                    ForEach(components) { component in
                        MealComponentRow(
                            component: component,
                            onEdit: { componentForAmount = component },
                            onDelete: { delete(component) }
                        )

                        if component.id != components.last?.id {
                            Divider()
                                .foregroundStyle(CalorynTheme.stone.opacity(0.3))
                        }
                    }
                }
            }
        }
        .glassCard(cornerRadius: CalorynTheme.smallCornerRadius)
    }

    private var deleteSection: some View {
        DestructiveGlassButton("Delete Meal") {
            showingDeleteConfirmation = true
        }
    }

    @MainActor
    private func populateFromExisting() {
        guard components.isEmpty else { return }
        guard let existingMeal else {
            nameIsFocused = true
            return
        }

        name = existingMeal.name
        components = existingMeal.sortedItems.compactMap(MealComponentDraft.init(item:))
    }

    private func upsert(_ component: MealComponentDraft) {
        if let index = components.firstIndex(where: { $0.id == component.id }) {
            components[index] = component
        } else {
            components.append(component)
        }
    }

    private func delete(_ component: MealComponentDraft) {
        components.removeAll { $0.id == component.id }
    }

    private func saveMeal() {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            try MealTemplateCommands.saveMeal(
                name: name,
                snapshots: components.map(\.snapshot),
                existingMealID: existingMeal?.id,
                modelContext: modelContext
            )
            onSaved?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteMeal() {
        guard let existingMeal else { return }

        do {
            try MealTemplateCommands.delete(existingMeal, modelContext: modelContext)
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

private struct MealComponentRow: View {
    let component: MealComponentDraft
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Button(action: onEdit) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(component.snapshot.foodName)
                            .font(CalorynTheme.bodyText)
                            .foregroundStyle(CalorynTheme.textPrimary)
                            .lineLimit(1)

                        Text("\(Int(component.snapshot.portionGrams.rounded()))g")
                            .font(CalorynTheme.caption)
                            .foregroundStyle(CalorynTheme.textSecondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(component.snapshot.nutrition.calories.kcalFormatted)
                            .font(CalorynTheme.numericCaption)
                            .foregroundStyle(CalorynTheme.textPrimary)
                        Text("\(component.snapshot.nutrition.proteinG.macroFormatted) P")
                            .font(CalorynTheme.numericCaption)
                            .foregroundStyle(CalorynTheme.proteinColor)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "minus.circle")
                    .font(CalorynTheme.compactIcon)
                    .foregroundStyle(CalorynTheme.terracotta.opacity(0.7))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete \(component.snapshot.foodName)")
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    MealFormView()
        .modelContainer(
            for: [
                UserProfile.self,
                FoodItem.self,
                FoodLogEntry.self,
                RecipeIngredient.self,
                MealTemplate.self,
                MealTemplateItem.self,
            ],
            inMemory: true
        )
}
