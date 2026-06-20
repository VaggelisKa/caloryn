import SwiftData
import SwiftUI

struct RecipeFormView: View {
    var existingRecipe: FoodItem?
    var onSaved: ((FoodItem) -> Void)?
    var allowsDeletion: Bool

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var ingredients: [RecipeIngredientDraft] = []
    @State private var showingIngredientSearch = false
    @State private var ingredientForAmount: RecipeIngredientDraft?
    @State private var showingDeleteConfirmation = false

    @FocusState private var isNameFocused: Bool

    private var isEditing: Bool { existingRecipe != nil }

    private var sortedIngredients: [RecipeIngredientDraft] {
        ingredients.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var totalGrams: Double {
        ingredients.reduce(0) { $0 + $1.portionGrams }
    }

    private var totalCalories: Double {
        ingredients.reduce(0) { $0 + $1.calories }
    }

    private var totalProtein: Double {
        ingredients.reduce(0) { $0 + $1.proteinG }
    }

    private var totalCarbs: Double {
        ingredients.reduce(0) { $0 + $1.carbsG }
    }

    private var totalFat: Double {
        ingredients.reduce(0) { $0 + $1.fatG }
    }

    private var totalFiber: Double {
        ingredients.reduce(0) { $0 + $1.fiberG }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && totalGrams > 0 && !ingredients.isEmpty
    }

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
            .navigationTitle(isEditing ? "Edit Recipe" : "Create Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .accessibilityLabel("Close")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveRecipe()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
            .onAppear(perform: populateFromExisting)
            .sheet(isPresented: $showingIngredientSearch) {
                FoodSearchView(
                    mealType: .breakfast,
                    logDate: .now,
                    mode: .ingredientSelection { food in
                        let ingredient = RecipeIngredientDraft(from: food, sortOrder: ingredients.count)
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
                    upsertIngredient(updated)
                }
            }
            .confirmationDialog("Delete Recipe", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive, action: deleteRecipe)
            } message: {
                Text("This will permanently remove \"\(name)\" from your recipes.")
            }
        }
        .presentationDetents([.large])
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RECIPE DETAILS")
                .font(CalorynTheme.caption)
                .foregroundStyle(CalorynTheme.textSecondary)

            TextField("Recipe name (e.g. Greek Salad)", text: $name)
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
                Text("\(Int(totalCalories))")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(CalorynTheme.sage)
                    .contentTransition(.numericText())
                    .animation(.smooth(duration: 0.3), value: Int(totalCalories))

                Text(totalGrams > 0 ? "calories in \(Int(totalGrams.rounded()))g" : "calories")
                    .font(CalorynTheme.bodyText)
                    .foregroundStyle(CalorynTheme.textSecondary)
            }

            HStack(spacing: CalorynTheme.cardSpacing) {
                summaryMetric("Protein", value: totalProtein, color: CalorynTheme.proteinColor)
                summaryMetric("Carbs", value: totalCarbs, color: CalorynTheme.carbColor)
                summaryMetric("Fat", value: totalFat, color: CalorynTheme.fatColor)
                summaryMetric("Fiber", value: totalFiber, color: CalorynTheme.fiberColor)
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
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)

                Spacer()

                Button {
                    showingIngredientSearch = true
                } label: {
                    Label("Add Ingredient", systemImage: "plus.circle")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                }
                .tint(CalorynTheme.sage)
            }

            if sortedIngredients.isEmpty {
                ContentUnavailableView(
                    "No Ingredients",
                    systemImage: "list.bullet",
                    description: Text("Add ingredients from search or barcode scan.")
                )
                .frame(minHeight: 160)
            } else {
                VStack(spacing: 0) {
                    ForEach(sortedIngredients) { ingredient in
                        ingredientRow(ingredient)

                        if ingredient.id != sortedIngredients.last?.id {
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
                deleteIngredient(ingredient)
            } label: {
                Image(systemName: "minus.circle")
                    .font(.body)
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
    private func populateFromExisting() {
        guard ingredients.isEmpty else { return }
        guard let existingRecipe else {
            isNameFocused = true
            return
        }

        name = existingRecipe.name
        ingredients = (existingRecipe.recipeIngredients ?? [])
            .sorted { $0.sortOrder < $1.sortOrder }
            .map(RecipeIngredientDraft.init(from:))
    }

    private func upsertIngredient(_ ingredient: RecipeIngredientDraft) {
        if let index = ingredients.firstIndex(where: { $0.id == ingredient.id }) {
            ingredients[index] = ingredient
        } else {
            var newIngredient = ingredient
            newIngredient.sortOrder = ingredients.count
            ingredients.append(newIngredient)
        }
        normalizeSortOrder()
    }

    private func deleteIngredient(_ ingredient: RecipeIngredientDraft) {
        ingredients.removeAll { $0.id == ingredient.id }
        normalizeSortOrder()
    }

    private func normalizeSortOrder() {
        for index in ingredients.indices {
            ingredients[index].sortOrder = index
        }
    }

    private func saveRecipe() {
        let recipe: FoodItem
        if let existingRecipe {
            recipe = existingRecipe
        } else {
            recipe = FoodItem(
                name: name.trimmingCharacters(in: .whitespaces),
                caloriesPer100g: 0,
                proteinPer100g: 0,
                carbsPer100g: 0,
                fatPer100g: 0,
                fiberPer100g: 0,
                isRecipe: true
            )
            modelContext.insert(recipe)
        }

        recipe.name = name.trimmingCharacters(in: .whitespaces)
        recipe.brand = nil
        recipe.barcode = nil
        recipe.isRecipe = true
        recipe.isCustom = false

        for oldIngredient in recipe.recipeIngredients ?? [] {
            modelContext.delete(oldIngredient)
        }

        let newIngredients = sortedIngredients.enumerated().map { index, draft in
            let ingredient = RecipeIngredient(
                name: draft.name,
                brand: draft.brand,
                portionGrams: draft.portionGrams,
                caloriesPer100g: draft.caloriesPer100g,
                proteinPer100g: draft.proteinPer100g,
                carbsPer100g: draft.carbsPer100g,
                fatPer100g: draft.fatPer100g,
                fiberPer100g: draft.fiberPer100g,
                sugarsPer100g: draft.sugarsPer100g,
                addedSugarsPer100g: draft.addedSugarsPer100g,
                sucrosePer100g: draft.sucrosePer100g,
                glucosePer100g: draft.glucosePer100g,
                fructosePer100g: draft.fructosePer100g,
                lactosePer100g: draft.lactosePer100g,
                maltosePer100g: draft.maltosePer100g,
                maltodextrinsPer100g: draft.maltodextrinsPer100g,
                starchPer100g: draft.starchPer100g,
                polyolsPer100g: draft.polyolsPer100g,
                saturatedFatPer100g: draft.saturatedFatPer100g,
                transFatPer100g: draft.transFatPer100g,
                monounsaturatedFatPer100g: draft.monounsaturatedFatPer100g,
                polyunsaturatedFatPer100g: draft.polyunsaturatedFatPer100g,
                omega3FatPer100g: draft.omega3FatPer100g,
                omega6FatPer100g: draft.omega6FatPer100g,
                omega9FatPer100g: draft.omega9FatPer100g,
                saltPer100g: draft.saltPer100g,
                sodiumPer100g: draft.sodiumPer100g,
                cholesterolPer100g: draft.cholesterolPer100g,
                solubleFiberPer100g: draft.solubleFiberPer100g,
                insolubleFiberPer100g: draft.insolubleFiberPer100g,
                caseinPer100g: draft.caseinPer100g,
                serumProteinsPer100g: draft.serumProteinsPer100g,
                alcoholPer100g: draft.alcoholPer100g,
                sortOrder: index,
                produceKind: draft.produceKind
            )
            ingredient.recipe = recipe
            modelContext.insert(ingredient)
            return ingredient
        }

        recipe.recipeIngredients = newIngredients
        recipe.updateRecipeNutritionFromIngredients()
        try? modelContext.save()
        onSaved?(recipe)
        dismiss()
    }

    private func deleteRecipe() {
        if let existingRecipe {
            modelContext.delete(existingRecipe)
            try? modelContext.save()
        }
        dismiss()
    }
}

#Preview {
    RecipeFormView()
        .modelContainer(
            for: [UserProfile.self, FoodItem.self, FoodLogEntry.self, RecipeIngredient.self],
            inMemory: true
        )
}
