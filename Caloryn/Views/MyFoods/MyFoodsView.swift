import SwiftData
import SwiftUI

struct MyFoodsView: View {
    private struct TemplateLogPresentation: Identifiable {
        let id = UUID()
        let templateName: String
        let defaultMeal: MealType
        let defaultSnackIndex: Int
        let snapshots: [FoodLogEntrySnapshot]
    }

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodItem.name) private var foodItems: [FoodItem]
    @Query(sort: \MealTemplate.updatedAt, order: .reverse) private var mealTemplates: [MealTemplate]

    @State private var showingManualEntryForm = false
    @State private var showingRecipeForm = false
    @State private var editingManualEntry: FoodItem?
    @State private var editingRecipe: FoodItem?
    @State private var favoriteErrorMessage: String?
    @State private var showsAllFavorites = false
    @State private var templateLogPresentation: TemplateLogPresentation?
    @State private var templateErrorMessage: String?

    private var manualEntries: [FoodItem] {
        foodItems.filter { $0.isCustom && !$0.isRecipe }
    }

    private var recipes: [FoodItem] {
        foodItems.filter(\.isRecipe)
    }

    private var favorites: [FoodItem] {
        FavoriteFoodLogging.sortedFavorites(from: foodItems)
    }

    private var visibleFavorites: [FoodItem] {
        FavoriteFoodLogging.visibleFavorites(
            from: foodItems,
            showsAll: showsAllFavorites
        )
    }

    private var nonFavoriteManualEntries: [FoodItem] {
        manualEntries.filter { !$0.isFavorite }
    }

    private var nonFavoriteRecipes: [FoodItem] {
        recipes.filter { !$0.isFavorite }
    }

    var body: some View {
        NavigationStack {
            List {
                reusableMealsSection

                if !favorites.isEmpty {
                    favoritesSection
                }

                if manualEntries.isEmpty {
                    emptyManualEntriesSection
                } else if !nonFavoriteManualEntries.isEmpty {
                    manualEntriesSection
                }

                if recipes.isEmpty {
                    emptyRecipesSection
                } else if !nonFavoriteRecipes.isEmpty {
                    recipesSection
                }
            }
            .calorynGroupedListStyle()
            .navigationTitle("My Foods")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    createMenu
                }
            }
            .sheet(isPresented: $showingManualEntryForm) {
                CustomFoodFormView(onSaved: { _ in
                    showingManualEntryForm = false
                })
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingRecipeForm) {
                RecipeFormView(onSaved: { _ in
                    showingRecipeForm = false
                })
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $editingManualEntry) { food in
                CustomFoodFormView(existingFood: food)
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $editingRecipe) { recipe in
                RecipeFormView(existingRecipe: recipe)
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $templateLogPresentation) { presentation in
                NavigationStack {
                    MealLogConfirmationView(
                        snapshots: presentation.snapshots,
                        sourceName: presentation.templateName,
                        initialDate: .now,
                        initialMeal: presentation.defaultMeal,
                        initialSnackIndex: presentation.defaultSnackIndex
                    ) {
                        templateLogPresentation = nil
                    }
                }
                .presentationDragIndicator(.visible)
            }
            .alert("Couldn’t Update Favorite", isPresented: favoriteErrorIsPresented) {
                Button("OK", role: .cancel) {
                    favoriteErrorMessage = nil
                }
            } message: {
                Text(favoriteErrorMessage ?? "Please try again.")
            }
            .alert("Couldn’t Update Reusable Meal", isPresented: templateErrorIsPresented) {
                Button("OK", role: .cancel) {
                    templateErrorMessage = nil
                }
            } message: {
                Text(templateErrorMessage ?? "Please try again.")
            }
        }
        .calorynPageCanvas()
    }

    private var reusableMealsSection: some View {
        Section {
            if mealTemplates.isEmpty {
                EmptyFoodGroupRow(
                    title: "No Reusable Meals",
                    message: "Select logged entries from Today to save a reusable meal.",
                    systemImage: "square.stack.3d.up"
                )
            } else {
                ForEach(mealTemplates) { template in
                    Button {
                        reuse(template)
                    } label: {
                        MealTemplateLibraryRow(template: template)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            delete(template)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        } header: {
            Text("Reusable Meals")
                .font(CalorynTheme.caption)
                .foregroundStyle(CalorynTheme.textSecondary)
        } footer: {
            if !mealTemplates.isEmpty {
                Text("Choose a meal to review its date and destination before logging.")
            }
        }
    }

    private var favoritesSection: some View {
        Section {
            ForEach(visibleFavorites) { food in
                libraryButton(for: food)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        deleteButton(for: food)
                        favoriteButton(for: food)
                    }
            }

            if favorites.count > FavoriteFoodLogging.collapsedFavoriteLimit {
                Button(action: toggleFavoritesDisclosure) {
                    HStack {
                        Text(showsAllFavorites ? "Show less" : "Show all \(favorites.count)")
                        Spacer()
                        Image(systemName: showsAllFavorites ? "chevron.up" : "chevron.down")
                    }
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.sage)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    showsAllFavorites
                        ? "Show fewer favorites"
                        : "Show all \(favorites.count) favorites"
                )
            }
        } header: {
            HStack {
                Label("Favorites", systemImage: "star.fill")
                Spacer()
                Text("\(favorites.count)")
            }
            .font(CalorynTheme.caption)
            .foregroundStyle(CalorynTheme.textSecondary)
        }
    }

    private var createMenu: some View {
        Menu {
            Button {
                showingManualEntryForm = true
            } label: {
                Label("Create Manual Entry", systemImage: "plus")
            }

            Button {
                showingRecipeForm = true
            } label: {
                Label("Create Recipe", systemImage: "list.bullet.rectangle")
            }
        } label: {
            Image(systemName: "plus")
                .font(CalorynTheme.toolbarIcon)
                .foregroundStyle(CalorynTheme.sage)
        }
        .accessibilityLabel("Create Food")
    }

    private var manualEntriesSection: some View {
        Section {
            ForEach(nonFavoriteManualEntries) { food in
                libraryButton(for: food)
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        favoriteButton(for: food)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        deleteButton(for: food)
                    }
            }
        } header: {
            Text("Manual Entries")
                .font(CalorynTheme.caption)
                .foregroundStyle(CalorynTheme.textSecondary)
        }
    }

    private var recipesSection: some View {
        Section {
            ForEach(nonFavoriteRecipes) { recipe in
                libraryButton(for: recipe)
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        favoriteButton(for: recipe)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        deleteButton(for: recipe)
                    }
            }
        } header: {
            Text("Recipes")
                .font(CalorynTheme.caption)
                .foregroundStyle(CalorynTheme.textSecondary)
        }
    }

    private var emptyManualEntriesSection: some View {
        Section {
            EmptyFoodGroupRow(
                title: "No Manual Entries",
                message: "Create foods you enter yourself.",
                systemImage: "pencil.and.list.clipboard"
            )
        } header: {
            Text("Manual Entries")
                .font(CalorynTheme.caption)
                .foregroundStyle(CalorynTheme.textSecondary)
        }
    }

    private var emptyRecipesSection: some View {
        Section {
            EmptyFoodGroupRow(
                title: "No Recipes",
                message: "Create recipes from reusable ingredients.",
                systemImage: "list.bullet.rectangle"
            )
        } header: {
            Text("Recipes")
                .font(CalorynTheme.caption)
                .foregroundStyle(CalorynTheme.textSecondary)
        }
    }

    private func libraryButton(for food: FoodItem) -> some View {
        Button {
            if food.isRecipe {
                editingRecipe = food
            } else {
                editingManualEntry = food
            }
        } label: {
            if food.isRecipe {
                RecipeLibraryRow(recipe: food)
            } else {
                manualEntryRow(for: food)
            }
        }
        .buttonStyle(.plain)
    }

    private func manualEntryRow(for food: FoodItem) -> some View {
        FoodRowView(
            name: food.name,
            brand: food.brand,
            caloriesPer100g: food.caloriesPer100g,
            nutriscoreGrade: food.nutriscoreGrade,
            servingDescription: food.servingDescription,
            caloriesPerServing: food.calories(forGrams: food.defaultServingG ?? 100),
            isCustom: true,
            showsTypeBadge: false
        )
        .contentShape(Rectangle())
    }

    private func delete(_ food: FoodItem) {
        food.deletePreservingLogEntrySnapshots(from: modelContext)
        try? modelContext.save()
    }

    private func reuse(_ template: MealTemplate) {
        do {
            templateLogPresentation = TemplateLogPresentation(
                templateName: template.name,
                defaultMeal: template.defaultMeal,
                defaultSnackIndex: template.defaultSnackIndex,
                snapshots: try MealTemplateCommands.snapshots(for: template)
            )
        } catch {
            templateErrorMessage = error.localizedDescription
        }
    }

    private func delete(_ template: MealTemplate) {
        do {
            try MealTemplateCommands.delete(template, modelContext: modelContext)
        } catch {
            templateErrorMessage = error.localizedDescription
        }
    }

    private func favoriteButton(for food: FoodItem) -> some View {
        Button {
            toggleFavorite(food)
        } label: {
            Label(
                food.isFavorite ? "Remove Favorite" : "Favorite",
                systemImage: food.isFavorite ? "star.slash" : "star"
            )
        }
        .tint(food.isFavorite ? CalorynTheme.textSecondary : CalorynTheme.terracotta)
    }

    private func deleteButton(for food: FoodItem) -> some View {
        Button(role: .destructive) {
            delete(food)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private func toggleFavorite(_ food: FoodItem) {
        do {
            try FavoriteFoodLogging.setFavorite(
                !food.isFavorite,
                for: food,
                modelContext: modelContext
            )
        } catch {
            favoriteErrorMessage = error.localizedDescription
        }
    }

    private func toggleFavoritesDisclosure() {
        withAnimation {
            showsAllFavorites.toggle()
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

    private var templateErrorIsPresented: Binding<Bool> {
        Binding(
            get: { templateErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    templateErrorMessage = nil
                }
            }
        )
    }
}

private struct EmptyFoodGroupRow: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(CalorynTheme.inlineIcon)
                .foregroundStyle(CalorynTheme.textSecondary)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(CalorynTheme.itemTitle)
                    .foregroundStyle(CalorynTheme.textPrimary)

                Text(message)
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}

private struct RecipeLibraryRow: View {
    let recipe: FoodItem

    private var totalGrams: Double {
        recipe.defaultServingG ?? 0
    }

    private var ingredientCount: Int {
        recipe.recipeIngredients?.count ?? 0
    }

    private var calories: Double {
        recipe.calories(forGrams: totalGrams)
    }

    private var protein: Double {
        recipe.protein(forGrams: totalGrams)
    }

    private var carbs: Double {
        recipe.carbs(forGrams: totalGrams)
    }

    private var fat: Double {
        recipe.fat(forGrams: totalGrams)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(recipe.name)
                    .font(CalorynTheme.itemTitle)
                    .foregroundStyle(CalorynTheme.textPrimary)
                    .lineLimit(1)

                Text(recipeDetail)
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(calories.rounded()))")
                    .font(CalorynTheme.numericBody)
                    .foregroundStyle(CalorynTheme.textPrimary)

                Text("kcal total")
                    .font(CalorynTheme.numericMicroCaption)
                    .foregroundStyle(CalorynTheme.textSecondary)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var recipeDetail: String {
        let ingredientLabel = ingredientCount == 1 ? "1 ingredient" : "\(ingredientCount) ingredients"
        let macroLabel = "\(protein.macroFormatted) P · \(carbs.macroFormatted) C · \(fat.macroFormatted) F"

        guard totalGrams > 0 else {
            return "\(ingredientLabel) · \(macroLabel)"
        }

        return "\(ingredientLabel) · \(Int(totalGrams.rounded()))g · \(macroLabel)"
    }
}

#Preview {
    MyFoodsView()
        .modelContainer(for: [UserProfile.self, FoodItem.self, FoodLogEntry.self, RecipeIngredient.self, MealTemplate.self, MealTemplateItem.self], inMemory: true)
}
