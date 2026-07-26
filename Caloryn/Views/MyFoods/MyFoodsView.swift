import SwiftData
import SwiftUI

struct MyFoodsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodItem.name) private var foodItems: [FoodItem]
    @Query(sort: \MealTemplate.updatedAt, order: .reverse) private var mealTemplates: [MealTemplate]

    @State private var showingManualEntryForm = false
    @State private var showingRecipeForm = false
    @State private var showingMealForm = false
    @State private var editingManualEntry: FoodItem?
    @State private var editingRecipe: FoodItem?
    @State private var editingMeal: MealTemplate?
    @State private var favoriteErrorMessage: String?
    @State private var mealErrorMessage: String?
    @State private var showsAllFavorites = false

    private var manualEntries: [FoodItem] {
        foodItems.filter(\.isManualEntry)
    }

    private var editedProducts: [FoodItem] {
        foodItems.filter(\.isEditedCatalogProduct)
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
                favoritesSection
                    .listRowBackground(CalorynTheme.cardBackground)

                if recipes.isEmpty {
                    emptyRecipesSection
                        .listRowBackground(CalorynTheme.cardBackground)
                } else if !nonFavoriteRecipes.isEmpty {
                    recipesSection
                        .listRowBackground(CalorynTheme.cardBackground)
                }

                mealsSection
                    .listRowBackground(CalorynTheme.cardBackground)

                if manualEntries.isEmpty {
                    emptyManualEntriesSection
                        .listRowBackground(CalorynTheme.cardBackground)
                } else if !nonFavoriteManualEntries.isEmpty {
                    manualEntriesSection
                        .listRowBackground(CalorynTheme.cardBackground)
                }

                editedProductCatalogSection
                    .listRowBackground(CalorynTheme.cardBackground)
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
            .sheet(isPresented: $showingMealForm) {
                MealFormView {
                    showingMealForm = false
                }
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
            .sheet(item: $editingMeal) { meal in
                MealFormView(existingMeal: meal)
                .presentationDragIndicator(.visible)
            }
            .alert("Couldn’t Update Favorite", isPresented: favoriteErrorIsPresented) {
                Button("OK", role: .cancel) {
                    favoriteErrorMessage = nil
                }
            } message: {
                Text(favoriteErrorMessage ?? "Please try again.")
            }
            .alert("Couldn’t Update Meal", isPresented: mealErrorIsPresented) {
                Button("OK", role: .cancel) {
                    mealErrorMessage = nil
                }
            } message: {
                Text(mealErrorMessage ?? "Please try again.")
            }
        }
        .calorynPageCanvas()
    }

    private var mealsSection: some View {
        Section {
            if mealTemplates.isEmpty {
                EmptyFoodGroupRow(
                    title: "No Meals",
                    message: "Create a meal from foods, manual entries, or recipes.",
                    systemImage: "fork.knife"
                )
            } else {
                ForEach(mealTemplates) { meal in
                    Button {
                        editingMeal = meal
                    } label: {
                        MealTemplateLibraryRow(template: meal)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            delete(meal)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        } header: {
            Text("Meals")
                .font(CalorynTheme.caption)
                .foregroundStyle(CalorynTheme.textSecondary)
        }
    }

    private var favoritesSection: some View {
        Section {
            if favorites.isEmpty {
                EmptyFoodGroupRow(
                    title: "No Favorites",
                    message: "Favorite recipes or manual entries for quick access.",
                    systemImage: "star"
                )
            } else {
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
            .accessibilityIdentifier("myFoods.createManualEntry")

            Button {
                showingRecipeForm = true
            } label: {
                Label("Create Recipe", systemImage: "list.bullet.rectangle")
            }

            Button {
                showingMealForm = true
            } label: {
                Label("Create Meal", systemImage: "fork.knife")
            }
        } label: {
            Image(systemName: "plus")
                .font(CalorynTheme.toolbarIcon)
                .foregroundStyle(CalorynTheme.sage)
        }
        .accessibilityLabel("Create Food")
        .accessibilityIdentifier("myFoods.createMenu")
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

    private var editedProductCatalogSection: some View {
        Section {
            NavigationLink {
                EditedProductCatalogView()
            } label: {
                Text(
                    editedProducts.count == 1
                        ? "1 product"
                        : "\(editedProducts.count) products"
                )
                .font(CalorynTheme.bodyText)
                .foregroundStyle(CalorynTheme.textPrimary)
            }
            .accessibilityLabel(
                "Edited Product Catalog, \(editedProducts.count) "
                    + (editedProducts.count == 1 ? "product" : "products")
            )
        } header: {
            Text("Edited Product Catalog")
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
        .accessibilityIdentifier("myFoods.food.\(food.name)")
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
        do {
            try modelContext.save()
            CalorynAppShortcutRefresh.favoritesChanged()
        } catch {
            // Keep the existing silent deletion behavior.
        }
    }

    private func delete(_ meal: MealTemplate) {
        do {
            try MealTemplateCommands.delete(meal, modelContext: modelContext)
        } catch {
            mealErrorMessage = error.localizedDescription
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

    private var mealErrorIsPresented: Binding<Bool> {
        Binding(
            get: { mealErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    mealErrorMessage = nil
                }
            }
        )
    }

}

private struct EditedProductCatalogView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FoodItem.name) private var foodItems: [FoodItem]

    @State private var searchText = ""
    @State private var editingProduct: FoodItem?

    private var products: [FoodItem] {
        EditedProductCatalog.products(in: foodItems, matching: searchText)
    }

    private var hasEditedProducts: Bool {
        foodItems.contains(where: \.isEditedCatalogProduct)
    }

    var body: some View {
        Group {
            if products.isEmpty {
                if hasEditedProducts {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ContentUnavailableView(
                        "No Edited Products",
                        systemImage: "square.and.pencil",
                        description: Text(
                            "Products you personalize from the catalog will appear here."
                        )
                    )
                }
            } else {
                List(products) { product in
                    Button {
                        editingProduct = product
                    } label: {
                        FoodRowView(
                            name: product.name,
                            brand: product.brand,
                            caloriesPer100g: product.caloriesPer100g,
                            nutriscoreGrade: product.nutriscoreGrade,
                            servingDescription: product.servingDescription,
                            caloriesPerServing: product.calories(
                                forGrams: product.defaultServingG ?? 100
                            ),
                            showsTypeBadge: false
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .calorynGroupedListStyle()
            }
        }
        .navigationTitle("Edited Product Catalog")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(CalorynTheme.toolbarIcon)
                        .foregroundStyle(CalorynTheme.sage)
                }
                .accessibilityLabel("Back")
            }
        }
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search edited products"
        )
        .sheet(item: $editingProduct) { product in
            CustomFoodFormView(existingFood: product)
                .presentationDragIndicator(.visible)
        }
        .calorynPageCanvas()
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
