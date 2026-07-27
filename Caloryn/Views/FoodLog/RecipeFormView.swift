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
                VStack(spacing: 24) {
                    nameSection
                    summaryCard
                    ingredientSection

                    if isEditing && allowsDeletion {
                        deleteSection
                    }
                }
                .padding(.horizontal, CalorynTheme.pagePadding)
                .padding(.bottom, 24)
            }
            .calorynSheetCanvas()
            .navigationTitle(isEditing ? "Edit Recipe" : "Create Recipe")
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

                if let existingRecipe {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            toggleFavorite(existingRecipe)
                        } label: {
                            Image(systemName: existingRecipe.isFavorite ? "star.fill" : "star")
                                .font(CalorynTheme.toolbarIcon)
                                .foregroundStyle(
                                    existingRecipe.isFavorite
                                        ? CalorynTheme.terracotta
                                        : CalorynTheme.sage
                                )
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
                        Image(systemName: "checkmark")
                            .font(CalorynTheme.toolbarIcon)
                            .foregroundStyle(CalorynTheme.sage)
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
        VStack(alignment: .leading, spacing: 12) {
            Text("RECIPE DETAILS")
                .font(CalorynTheme.sectionEyebrow)
                .foregroundStyle(CalorynTheme.textSecondary)

            TextField("Recipe name (e.g. Greek Salad)", text: $draft.name)
                .font(CalorynTheme.bodyText)
                .textInputAutocapitalization(.words)
                .focused($isNameFocused)
                .calorynInputField(isFocused: isNameFocused)
        }
        .glassCard(cornerRadius: CalorynTheme.smallCornerRadius)
    }

    private var summaryCard: some View {
        VStack(spacing: 14) {
            VStack(spacing: 4) {
                Text("\(Int(draft.totalCalories))")
                    .font(CalorynTheme.displayNumber)
                    .foregroundStyle(CalorynTheme.sage)
                    .contentTransition(.numericText())
                    .animation(.smooth(duration: 0.3), value: Int(draft.totalCalories))

                Text(draft.totalCaloriesCaption)
                    .font(CalorynTheme.bodyText)
                    .foregroundStyle(CalorynTheme.textSecondary)
            }

            HStack(spacing: CalorynTheme.cardSpacing) {
                summaryMetric("Protein", value: draft.totalProtein, color: CalorynTheme.proteinColor)
                summaryMetric("Carbs", value: draft.totalCarbs, color: CalorynTheme.carbColor)
                summaryMetric("Fat", value: draft.totalFat, color: CalorynTheme.fatColor)
                summaryMetric("Fiber", value: draft.totalFiber, color: CalorynTheme.fiberColor)
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

    private var ingredientSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("INGREDIENTS")
                    .font(CalorynTheme.sectionEyebrow)
                    .foregroundStyle(CalorynTheme.textSecondary)

                Spacer()

                Button {
                    showingIngredientSearch = true
                } label: {
                    Label("Add Ingredient", systemImage: "plus.circle")
                        .font(CalorynTheme.buttonLabel)
                }
                .accessibilityIdentifier("recipe.addIngredient")
            }

            if draft.sortedIngredients.isEmpty {
                ContentUnavailableView(
                    "No Ingredients",
                    systemImage: "list.bullet",
                    description: Text("Add ingredients from search or barcode scan.")
                )
                .frame(minHeight: 160)
            } else {
                VStack(spacing: 0) {
                    ForEach(draft.sortedIngredients) { ingredient in
                        ingredientRow(ingredient)

                        if ingredient.id != draft.sortedIngredients.last?.id {
                            Divider()
                                .foregroundStyle(CalorynTheme.stone.opacity(0.3))
                        }
                    }
                }
            }
        }
        .glassCard(cornerRadius: CalorynTheme.smallCornerRadius)
    }

    private func ingredientRow(_ ingredient: RecipeIngredientDraft) -> some View {
        HStack {
            Button {
                ingredientForAmount = ingredient
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(ingredient.name)
                            .font(CalorynTheme.bodyText)
                            .foregroundStyle(CalorynTheme.textPrimary)
                            .lineLimit(1)

                        Text("\(Int(ingredient.portionGrams.rounded()))g")
                            .font(CalorynTheme.caption)
                            .foregroundStyle(CalorynTheme.textSecondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(ingredient.calories.kcalFormatted)
                            .font(CalorynTheme.numericCaption)
                            .foregroundStyle(CalorynTheme.textPrimary)
                        Text("\(ingredient.proteinG.macroFormatted) P")
                            .font(CalorynTheme.numericCaption)
                            .foregroundStyle(CalorynTheme.proteinColor)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                draft.remove(ingredient)
            } label: {
                Image(systemName: "minus.circle")
                    .font(CalorynTheme.compactIcon)
                    .foregroundStyle(CalorynTheme.terracotta.opacity(0.7))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete \(ingredient.name)")
        }
        .padding(.vertical, 8)
    }

    private var deleteSection: some View {
        DestructiveGlassButton("Delete Recipe") {
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
