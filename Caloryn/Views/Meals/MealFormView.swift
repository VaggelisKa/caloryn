import SwiftData
import SwiftUI

struct MealFormView: View {
    let existingMeal: MealTemplate?
    let onSaved: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var draft = MealFormDraft()
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
                            .foregroundStyle(CalorynTheme.sage)
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
                                .foregroundStyle(CalorynTheme.sage)
                        }
                    }
                    .accessibilityLabel("Save Meal")
                    .disabled(!draft.canSave || isSaving)
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
                    draft.upsert(component.updatingPortion(to: updated.portionGrams))
                }
            }
            .confirmationDialog("Delete Meal", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive, action: deleteMeal)
            } message: {
                Text("This will permanently remove \"\(draft.name)\" from your meals.")
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

            TextField("Meal name (e.g. Weekday Breakfast)", text: $draft.name)
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
                Text(draft.totalNutrition.calories.kcalFormatted)
                    .font(CalorynTheme.displayNumber)
                    .foregroundStyle(CalorynTheme.sage)
                    .contentTransition(.numericText())
                    .animation(.smooth(duration: 0.3), value: draft.totalNutrition.calories)

                Text(draft.components.count == 1 ? "1 item" : "\(draft.components.count) items")
                    .font(CalorynTheme.bodyText)
                    .foregroundStyle(CalorynTheme.textSecondary)
            }

            HStack(spacing: CalorynTheme.cardSpacing) {
                summaryMetric("Protein", value: draft.totalNutrition.proteinG, color: CalorynTheme.proteinColor)
                summaryMetric("Carbs", value: draft.totalNutrition.carbsG, color: CalorynTheme.carbColor)
                summaryMetric("Fat", value: draft.totalNutrition.fatG, color: CalorynTheme.fatColor)
                summaryMetric("Fiber", value: draft.totalNutrition.fiberG, color: CalorynTheme.fiberColor)
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

            if draft.components.isEmpty {
                ContentUnavailableView(
                    "No Items",
                    systemImage: "fork.knife",
                    description: Text("Add foods, manual entries, or recipes.")
                )
                .frame(minHeight: 160)
            } else {
                VStack(spacing: 0) {
                    ForEach(draft.components) { component in
                        MealComponentRow(
                            component: component,
                            onEdit: { componentForAmount = component },
                            onDelete: { draft.delete(component) }
                        )

                        if component.id != draft.components.last?.id {
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
        guard draft.components.isEmpty else { return }
        guard let existingMeal else {
            nameIsFocused = true
            return
        }

        draft = MealFormDraft(existingMeal: existingMeal)
    }

    private func saveMeal() {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            try MealTemplateCommands.saveMeal(
                name: draft.name,
                snapshots: draft.components.map(\.snapshot),
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
