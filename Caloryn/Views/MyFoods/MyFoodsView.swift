import SwiftData
import SwiftUI

struct MyFoodsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<FoodItem> { $0.isCustom || $0.isRecipe },
        sort: \FoodItem.name
    ) private var foodItems: [FoodItem]
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

    private var listing: MyFoodsListing {
        MyFoodsListing(
            foodItems: foodItems,
            mealTemplateCount: mealTemplates.count,
            showsAllFavorites: showsAllFavorites
        )
    }

    var body: some View {
        NavigationStack {
            libraryContent
            .calorynPageCanvas()
            .calorynLargeTitle("My Foods")
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
    }

    @ViewBuilder
    private var libraryContent: some View {
        let listing = listing

        if listing.isEmptyLibrary {
            emptyLibraryView
        } else {
            List {
                if listing.showsFavoritesSection {
                    favoritesSection
                        .libraryHairlineSection()
                }

                if listing.showsMealsSection {
                    mealsSection
                        .libraryHairlineSection()
                }

                if listing.showsRecipesSection {
                    recipesSection
                        .libraryHairlineSection()
                }

                if listing.showsManualEntriesSection {
                    manualEntriesSection
                        .libraryHairlineSection()
                }

                if listing.showsEditedProductCatalogSection {
                    editedProductCatalogSection
                        .libraryHairlineSection()
                }
            }
            .calorynPlainListStyle()
            .listSectionSpacing(.compact)
        }
    }

    private var emptyLibraryView: some View {
        ContentUnavailableView {
            Label("Your food library is empty", systemImage: "takeoutbag.and.cup.and.straw")
        } description: {
            Text("Foods, recipes and meals you save appear here, ready to log in one tap.")
                .foregroundStyle(CalorynTheme.textSecondary)
        }
        .foregroundStyle(CalorynTheme.textPrimary, CalorynTheme.textSecondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            CalorynTheme.backgroundPrimary
                .ignoresSafeArea()
        }
        .accessibilityIdentifier("myFoods.emptyLibrary")
    }

    private var mealsSection: some View {
        Section {
            ForEach(mealTemplates) { meal in
                Button {
                    editingMeal = meal
                } label: {
                    LibraryMealRow(template: meal)
                        .libraryRowSeparatorInset()
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("myFoods.meal.\(meal.name)")
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        delete(meal)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .tint(CalorynTheme.fillAction)
                }
            }
        } header: {
            LibrarySectionHeader(title: "Meals", count: mealTemplates.count)
        }
    }

    private var favoritesSection: some View {
        let listing = listing
        return Section {
            ForEach(listing.visibleFavorites) { food in
                libraryButton(for: food)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        deleteButton(for: food)
                        favoriteButton(for: food)
                    }
            }

            if listing.showsFavoritesDisclosure {
                Button(action: toggleFavoritesDisclosure) {
                    HStack {
                        Text(showsAllFavorites ? "Show less" : "Show all \(listing.favorites.count)")
                        Spacer()
                        Image(systemName: showsAllFavorites ? "chevron.up" : "chevron.down")
                    }
                    .font(CalorynTheme.cardSubtitle.weight(.semibold))
                    .foregroundStyle(CalorynTheme.accent)
                    .contentShape(Rectangle())
                    .libraryRowSeparatorInset()
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    showsAllFavorites
                        ? "Show fewer favorites"
                        : "Show all \(listing.favorites.count) favorites"
                )
            }
        } header: {
            LibrarySectionHeader(title: "Favorites", count: listing.favorites.count, marksFavorites: true)
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
            .accessibilityIdentifier("myFoods.createRecipe")

            Button {
                showingMealForm = true
            } label: {
                Label("Create Meal", systemImage: "fork.knife")
            }
            .accessibilityIdentifier("myFoods.createMeal")
        } label: {
            Image(systemName: "plus")
                .font(CalorynTheme.toolbarIcon)
                .foregroundStyle(CalorynTheme.accent)
        }
        .accessibilityLabel("Create Food")
        .accessibilityIdentifier("myFoods.createMenu")
    }

    private var manualEntriesSection: some View {
        Section {
            ForEach(listing.nonFavoriteManualEntries) { food in
                libraryButton(for: food)
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        favoriteButton(for: food)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        deleteButton(for: food)
                    }
            }
        } header: {
            LibrarySectionHeader(title: "Your own entries", count: listing.nonFavoriteManualEntries.count)
        }
    }

    private var recipesSection: some View {
        Section {
            ForEach(listing.nonFavoriteRecipes) { recipe in
                libraryButton(for: recipe)
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        favoriteButton(for: recipe)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        deleteButton(for: recipe)
                    }
            }
        } header: {
            LibrarySectionHeader(title: "Recipes", count: listing.nonFavoriteRecipes.count)
        }
    }

    private var editedProductCatalogSection: some View {
        let editedProductCount = listing.editedProducts.count
        return Section {
            NavigationLink {
                EditedProductCatalogView()
            } label: {
                Text(
                    editedProductCount == 1
                        ? "1 product"
                        : "\(editedProductCount) products"
                )
                .font(LibraryRowStyle.name)
                .foregroundStyle(CalorynTheme.textPrimary)
                .libraryRowSeparatorInset()
            }
            .accessibilityLabel(
                "Edited product catalog, \(editedProductCount) "
                    + (editedProductCount == 1 ? "product" : "products")
            )
        } header: {
            LibrarySectionHeader(title: "Edited products", count: editedProductCount)
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
            Group {
                if food.isRecipe {
                    RecipeLibraryRow(recipe: food, showsTypeBadge: food.isFavorite)
                } else {
                    manualEntryRow(for: food)
                }
            }
            .libraryRowSeparatorInset()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("myFoods.food.\(food.name)")
    }

    private func manualEntryRow(for food: FoodItem) -> some View {
        LibraryFoodRow(
            summary: LibraryFoodRowSummary(food: food),
            nutriscoreGrade: food.nutriscoreGrade,
            showsTypeBadge: food.isFavorite
        )
    }

    private func delete(_ food: FoodItem) {
        food.deletePreservingLogEntrySnapshots(from: modelContext)
        do {
            try modelContext.save()
            CalorynAppShortcutRefresh.favoritesChanged()
        } catch {
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
        .tint(CalorynTheme.fillAction)
    }

    private func deleteButton(for food: FoodItem) -> some View {
        Button(role: .destructive) {
            delete(food)
        } label: {
            Label("Delete", systemImage: "trash")
        }
        .tint(CalorynTheme.fillAction)
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
    @Query(
        filter: #Predicate<FoodItem> { $0.isCustom && !$0.isRecipe },
        sort: \FoodItem.name
    ) private var foodItems: [FoodItem]

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
                        .onCatalogCanvas()
                } else {
                    ContentUnavailableView(
                        "No edited products",
                        systemImage: "square.and.pencil",
                        description: Text(
                            "Products you personalize from the catalog will appear here."
                        )
                        .foregroundStyle(CalorynTheme.textSecondary)
                    )
                    .onCatalogCanvas()
                }
            } else {
                List {
                    Section {
                        ForEach(products) { product in
                            Button {
                                editingProduct = product
                            } label: {
                                LibraryFoodRow(
                                    summary: LibraryFoodRowSummary(food: product),
                                    nutriscoreGrade: product.nutriscoreGrade
                                )
                                .libraryRowSeparatorInset()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .libraryHairlineSection()
                }
                .calorynPlainListStyle()
            }
        }
        .foregroundStyle(CalorynTheme.textPrimary, CalorynTheme.textSecondary)
        .calorynPageCanvas()
        .calorynInlineTitle("Edited product catalog")
        .calorynDrillDownNavigation()
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search edited products"
        )
        .sheet(item: $editingProduct) { product in
            CustomFoodFormView(existingFood: product)
                .presentationDragIndicator(.visible)
        }
    }
}

private extension View {
    func onCatalogCanvas() -> some View {
        self
            .foregroundStyle(CalorynTheme.textPrimary, CalorynTheme.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                CalorynTheme.backgroundPrimary
                    .ignoresSafeArea()
            }
    }
}

private struct LibrarySectionHeader: View {
    let title: String
    let count: Int
    var marksFavorites = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if marksFavorites {
                Image(systemName: "star")
                    .font(CalorynTheme.compactIcon)
                    .foregroundStyle(CalorynTheme.textPrimary)
                    .accessibilityHidden(true)
            }

            Text(title)
                .font(CalorynTheme.sectionHeaderTitle)
                .foregroundStyle(CalorynTheme.textPrimary)

            Spacer(minLength: 8)

            Text("\(count)")
                .font(CalorynTheme.sectionHeaderDetail)
                .foregroundStyle(CalorynTheme.textSecondary)
        }
        .textCase(nil)
        .padding(LibraryRowStyle.headerPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CalorynTheme.backgroundPrimary)
        .listRowInsets(EdgeInsets())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    MyFoodsView()
        .modelContainer(for: [UserProfile.self, FoodItem.self, FoodLogEntry.self, RecipeIngredient.self, MealTemplate.self, MealTemplateItem.self], inMemory: true)
}
