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
                VStack(alignment: .leading, spacing: 28) {
                    nameSection
                    summary
                    componentsSection

                    if isEditing {
                        deleteSection
                    }
                }
                .padding(.horizontal, CalorynTheme.pagePadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .calorynSheetCanvas()
            .navigationTitle(isEditing ? "Edit meal" : "Create meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    CreationFormCloseButton {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveMeal()
                    } label: {
                        CreationFormSaveGlyph(isEnabled: draft.canSave && !isSaving, isSaving: isSaving)
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
        CreationFormSection("Meal details") {
            TextField("Meal name (e.g. Weekday Breakfast)", text: $draft.name)
                .font(CalorynTheme.bodyText)
                .textInputAutocapitalization(.words)
                .focused($nameIsFocused)
                .calorynInputField(isFocused: nameIsFocused)
        }
    }

    private var summary: some View {
        CreationFormTotal(
            kcal: draft.totalNutrition.calories.truncatedSafely,
            caption: draft.components.count == 1 ? "kcal in 1 item" : "kcal in \(draft.components.count) items",
            macros: [
                ("Protein", draft.totalNutrition.proteinG.spacedMacroFormatted),
                ("Carbs", draft.totalNutrition.carbsG.spacedMacroFormatted),
                ("Fat", draft.totalNutrition.fatG.spacedMacroFormatted),
                ("Fiber", draft.totalNutrition.fiberG.spacedMacroFormatted),
            ]
        )
    }

    private var componentsSection: some View {
        CreationFormSection("Items", surface: .group) {
            CreationFormAddButton(title: "Add item") {
                showingFoodSearch = true
            }
        } content: {
            if draft.components.isEmpty {
                CreationFormEmptyRow(
                    title: "No items yet",
                    detail: "Add foods, manual entries, or recipes."
                )
            } else {
                ForEach(draft.components) { component in
                    if component.id != draft.components.first?.id {
                        CreationFormDivider()
                    }
                    MealComponentRow(
                        component: component,
                        onEdit: { componentForAmount = component },
                        onDelete: { draft.delete(component) }
                    )
                }
            }
        }
    }

    private var deleteSection: some View {
        CreationFormDeleteButton("Delete meal") {
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
        CreationFormItemRow(
            name: component.snapshot.foodName,
            detail: "\(component.snapshot.portionGrams.rounded().spacedMacroFormatted), "
                + "\(component.snapshot.nutrition.proteinG.spacedMacroFormatted) protein",
            kcal: component.snapshot.nutrition.calories.truncatedSafely,
            onEdit: onEdit,
            onDelete: onDelete
        )
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
