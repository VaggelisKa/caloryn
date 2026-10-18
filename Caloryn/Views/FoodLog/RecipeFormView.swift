import SwiftData
import SwiftUI

struct RecipeFormView: View {
    var existingRecipe: FoodItem?
    var onSaved: ((FoodItem) -> Void)?
    var allowsDeletion: Bool

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var draft = RecipeDraft()
    @State private var showingIngredientSearch = false
    @State private var ingredientForAmount: RecipeIngredientDraft?
    @State private var showingDeleteConfirmation = false
    @State private var favoriteErrorMessage: String?

    @FocusState private var isNameFocused: Bool

    private var isEditing: Bool { existingRecipe != nil }

    init(existingRecipe: FoodItem? = nil, onSaved: ((FoodItem) -> Void)? = nil, allowsDeletion: Bool = true) {
        self.existingRecipe = existingRecipe
        self.onSaved = onSaved
        self.allowsDeletion = allowsDeletion
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    nameSection
                    summary
                    ingredientSection

                    if isEditing && allowsDeletion {
                        deleteSection
                    }
                }
                .padding(.horizontal, CalorynTheme.pagePadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .calorynSheetCanvas()
            .calorynInlineTitle(isEditing ? "Edit recipe" : "Create recipe")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    CreationFormCloseButton {
                        dismiss()
                    }
                }

                if let existingRecipe {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            toggleFavorite(existingRecipe)
                        } label: {
                            CreationFormFavoriteGlyph(isFavorite: existingRecipe.isFavorite)
                        }
                        .accessibilityLabel(
                            existingRecipe.isFavorite
                                ? "Remove \(existingRecipe.name) from favorites"
                                : "Add \(existingRecipe.name) to favorites"
                        )
                    }

                    if #available(iOS 26.0, *) {
                        ToolbarSpacer(.fixed, placement: .topBarTrailing)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        saveRecipe()
                    } label: {
                        CreationFormSaveGlyph(isEnabled: draft.canSave)
                    }
                    .accessibilityLabel("Save")
                    .disabled(!draft.canSave)
                }
            }
            .onAppear(perform: seedFromExisting)
            .sheet(isPresented: $showingIngredientSearch) {
                FoodSearchView(
                    mealType: .breakfast,
                    logDate: .now,
                    mode: .ingredientSelection { food in
                        let ingredient = RecipeIngredientDraft(from: food, sortOrder: draft.ingredients.count)
                        showingIngredientSearch = false
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(250))
                            ingredientForAmount = ingredient
                        }
                    }
                )
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $ingredientForAmount) { ingredient in
                IngredientAmountPickerView(ingredient: ingredient) { updated in
                    draft.upsert(updated)
                }
            }
            .confirmationDialog("Delete Recipe", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive, action: deleteRecipe)
            } message: {
                Text("This will permanently remove \"\(draft.name)\" from your recipes.")
            }
            .alert("Couldn’t Update Favorite", isPresented: favoriteErrorIsPresented) {
                Button("OK", role: .cancel) {
                    favoriteErrorMessage = nil
                }
            } message: {
                Text(favoriteErrorMessage ?? "Please try again.")
            }
        }
        .presentationDetents([.large])
    }

    private var nameSection: some View {
        CreationFormSection("Recipe details") {
            TextField("Recipe name (e.g. Greek Salad)", text: $draft.name)
                .font(CalorynTheme.bodyText)
                .textInputAutocapitalization(.words)
                .focused($isNameFocused)
                .calorynInputField(isFocused: isNameFocused)
        }
    }

    private var summary: some View {
        CreationFormTotal(
            kcal: draft.totalCalories.truncatedSafely,
            caption: draft.totalCaloriesCaption,
            macros: [
                ("Protein", draft.totalProtein.spacedMacroFormatted),
                ("Carbs", draft.totalCarbs.spacedMacroFormatted),
                ("Fat", draft.totalFat.spacedMacroFormatted),
                ("Fiber", draft.totalFiber.spacedMacroFormatted),
            ]
        )
    }

    private var ingredientSection: some View {
        CreationFormSection("Ingredients", surface: .group) {
            CreationFormAddButton(title: "Add ingredient") {
                showingIngredientSearch = true
            }
            .accessibilityIdentifier("recipe.addIngredient")
        } content: {
            if draft.sortedIngredients.isEmpty {
                CreationFormEmptyRow(
                    title: "No ingredients yet",
                    detail: "Add ingredients from search or barcode scan."
                )
            } else {
                ForEach(draft.sortedIngredients) { ingredient in
                    if ingredient.id != draft.sortedIngredients.first?.id {
                        CreationFormDivider()
                    }
                    ingredientRow(ingredient)
                }
            }
        }
    }

    private func ingredientRow(_ ingredient: RecipeIngredientDraft) -> some View {
        CreationFormItemRow(
            name: ingredient.name,
            detail: "\(ingredient.portionGrams.rounded().spacedMacroFormatted), \(ingredient.proteinG.spacedMacroFormatted) protein",
            kcal: ingredient.calories.truncatedSafely,
            onEdit: { ingredientForAmount = ingredient },
            onDelete: { draft.remove(ingredient) }
        )
    }

    private var deleteSection: some View {
        CreationFormDeleteButton("Delete recipe") {
            showingDeleteConfirmation = true
        }
    }

    @MainActor
    private func seedFromExisting() {
        if draft.seed(from: existingRecipe) == .startedEmpty {
            isNameFocused = true
        }
    }

    private func saveRecipe() {
        let recipe: FoodItem
        if let existingRecipe {
            recipe = existingRecipe
        } else {
            recipe = FoodItem(
                name: draft.trimmedName,
                caloriesPer100g: 0,
                proteinPer100g: 0,
                carbsPer100g: 0,
                fatPer100g: 0,
                fiberPer100g: 0,
                isRecipe: true
            )
            modelContext.insert(recipe)
        }

        recipe.name = draft.trimmedName
        recipe.brand = nil
        recipe.barcode = nil
        recipe.isRecipe = true
        recipe.isCustom = false

        for oldIngredient in recipe.recipeIngredients ?? [] {
            modelContext.delete(oldIngredient)
        }

        let newIngredients = draft.ingredientsForSaving.map { ingredientDraft in
            let ingredient = RecipeIngredient(
                name: ingredientDraft.name,
                brand: ingredientDraft.brand,
                portionGrams: ingredientDraft.portionGrams,
                caloriesPer100g: ingredientDraft.caloriesPer100g,
                proteinPer100g: ingredientDraft.proteinPer100g,
                carbsPer100g: ingredientDraft.carbsPer100g,
                fatPer100g: ingredientDraft.fatPer100g,
                fiberPer100g: ingredientDraft.fiberPer100g,
                sugarsPer100g: ingredientDraft.sugarsPer100g,
                addedSugarsPer100g: ingredientDraft.addedSugarsPer100g,
                sucrosePer100g: ingredientDraft.sucrosePer100g,
                glucosePer100g: ingredientDraft.glucosePer100g,
                fructosePer100g: ingredientDraft.fructosePer100g,
                lactosePer100g: ingredientDraft.lactosePer100g,
                maltosePer100g: ingredientDraft.maltosePer100g,
                maltodextrinsPer100g: ingredientDraft.maltodextrinsPer100g,
                starchPer100g: ingredientDraft.starchPer100g,
                polyolsPer100g: ingredientDraft.polyolsPer100g,
                saturatedFatPer100g: ingredientDraft.saturatedFatPer100g,
                transFatPer100g: ingredientDraft.transFatPer100g,
                monounsaturatedFatPer100g: ingredientDraft.monounsaturatedFatPer100g,
                polyunsaturatedFatPer100g: ingredientDraft.polyunsaturatedFatPer100g,
                omega3FatPer100g: ingredientDraft.omega3FatPer100g,
                omega6FatPer100g: ingredientDraft.omega6FatPer100g,
                omega9FatPer100g: ingredientDraft.omega9FatPer100g,
                saltPer100g: ingredientDraft.saltPer100g,
                sodiumPer100g: ingredientDraft.sodiumPer100g,
                cholesterolPer100g: ingredientDraft.cholesterolPer100g,
                solubleFiberPer100g: ingredientDraft.solubleFiberPer100g,
                insolubleFiberPer100g: ingredientDraft.insolubleFiberPer100g,
                caseinPer100g: ingredientDraft.caseinPer100g,
                serumProteinsPer100g: ingredientDraft.serumProteinsPer100g,
                alcoholPer100g: ingredientDraft.alcoholPer100g,
                sortOrder: ingredientDraft.sortOrder,
                produceKind: ingredientDraft.produceKind,
                provenance: ingredientDraft.provenance
            )
            ingredient.recipe = recipe
            modelContext.insert(ingredient)
            return ingredient
        }

        recipe.recipeIngredients = newIngredients
        recipe.updateRecipeNutritionFromIngredients()
        do {
            try modelContext.save()
            if existingRecipe != nil {
                CalorynAppShortcutRefresh.favoriteWasEdited(
                    isFavorite: recipe.isFavorite
                )
            }
        } catch {
            // Keep the existing silent save behavior.
        }
        onSaved?(recipe)
        dismiss()
    }

    private func deleteRecipe() {
        if let existingRecipe {
            existingRecipe.deletePreservingLogEntrySnapshots(from: modelContext)
            do {
                try modelContext.save()
                CalorynAppShortcutRefresh.favoritesChanged()
            } catch {
                // Keep the existing silent deletion behavior.
            }
        }
        dismiss()
    }

    private func toggleFavorite(_ recipe: FoodItem) {
        do {
            try FavoriteFoodLogging.setFavorite(
                !recipe.isFavorite,
                for: recipe,
                modelContext: modelContext
            )
        } catch {
            favoriteErrorMessage = error.localizedDescription
        }
    }

    private var favoriteErrorIsPresented: Binding<Bool> {
        Binding(
            get: { favoriteErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    favoriteErrorMessage = nil
                }
            }
        )
    }
}

#Preview {
    RecipeFormView()
        .modelContainer(
            for: [UserProfile.self, FoodItem.self, FoodLogEntry.self, RecipeIngredient.self],
            inMemory: true
        )
}
