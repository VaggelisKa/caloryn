import SwiftUI
import SwiftData
import UIKit

enum FoodSearchMode {
    case logging
    case ingredientSelection((FoodItem) -> Void)

    var title: String {
        switch self {
        case .logging: "Add Food"
        case .ingredientSelection: "Add Ingredient"
        }
    }

    var isIngredientSelection: Bool {
        switch self {
        case .logging: false
        case .ingredientSelection: true
        }
    }
}

struct FoodSearchView: View {
    private struct TemplateLogPresentation: Identifiable {
        let id = UUID()
        let templateName: String
        let snapshots: [FoodLogEntrySnapshot]
    }

    let mealType: MealType
    let logDate: Date
    var snackIndex: Int = 0
    var mode: FoodSearchMode = .logging
    var automaticallyFocusSearch = true

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FoodItem.lastUsed, order: .reverse) private var recentFoods: [FoodItem]
    @Query(sort: \MealTemplate.updatedAt, order: .reverse) private var mealTemplates: [MealTemplate]

    @State private var searchService = FoodSearchService()
    @State private var searchText = ""
    @State private var selectedProduct: OpenFoodFactsProduct?
    @State private var selectedFoodItem: FoodItem?
    @State private var showingScanner = false
    @State private var showingCustomFoodForm = false
    @State private var isLookingUpBarcode = false
    @State private var barcodeLookupError: String?
    @State private var favoriteErrorMessage: String?
    @State private var showsAllFavorites = false
    @State private var templateLogPresentation: TemplateLogPresentation?
    @State private var templateErrorMessage: String?
    @FocusState private var isSearchFocused: Bool

    private var showingRecent: Bool {
        searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var recipes: [FoodItem] {
        guard !mode.isIngredientSelection else { return [] }
        return recentFoods.filter { $0.isRecipe }
    }

    private var customFoods: [FoodItem] {
        recentFoods.filter { $0.isCustom && !$0.isRecipe }
    }

    private var displayedRecentFoods: [FoodItem] {
        Array(
            recentFoods
                .filter { !$0.isUserCreatedFood }
                .prefix(20)
        )
    }

    private var favoriteFoods: [FoodItem] {
        guard !mode.isIngredientSelection else { return [] }
        return FavoriteFoodLogging.sortedFavorites(from: recentFoods)
    }

    private var visibleFavoriteFoods: [FoodItem] {
        FavoriteFoodLogging.visibleFavorites(
            from: favoriteFoods,
            showsAll: showsAllFavorites
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar

                if isLookingUpBarcode || barcodeLookupError != nil {
                    barcodeLookupOverlay
                } else if showingRecent {
                    recentFoodsList
                } else {
                    searchResultsList
                }
            }
            .navigationTitle(mode.title)
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
                if mode.isIngredientSelection {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingCustomFoodForm = true
                        } label: {
                            Image(systemName: "plus")
                                .font(CalorynTheme.toolbarIcon)
                                .foregroundStyle(CalorynTheme.sage)
                        }
                        .accessibilityLabel("Create Manual Entry")
                    }
                }
            }
            .navigationDestination(item: $selectedProduct) { product in
                let food = searchService.createFoodItem(from: product)
                PortionPickerView(
                    foodItem: food,
                    mealType: mealType,
                    logDate: logDate,
                    isNewFood: true,
                    snackIndex: snackIndex
                ) { dismiss() }
            }
            .navigationDestination(item: $selectedFoodItem) { food in
                PortionPickerView(
                    foodItem: food,
                    mealType: mealType,
                    logDate: logDate,
                    isNewFood: false,
                    snackIndex: snackIndex
                ) { dismiss() }
            }
            .sheet(isPresented: $showingCustomFoodForm) {
                CustomFoodFormView(onSaved: { food in
                    showingCustomFoodForm = false
                    Task { @MainActor in
                        handleFoodItemSelection(food)
                    }
                })
            }
            .sheet(item: $templateLogPresentation) { presentation in
                NavigationStack {
                    MealLogConfirmationView(
                        snapshots: presentation.snapshots,
                        sourceName: presentation.templateName,
                        initialDate: logDate,
                        initialMeal: mealType,
                        initialSnackIndex: snackIndex,
                        onLogged: dismiss.callAsFunction
                    )
                }
                .presentationDragIndicator(.visible)
            }
            .fullScreenCover(isPresented: $showingScanner) {
                barcodeScannerSheet
            }
            .alert(
                "Couldn’t Log Favorite",
                isPresented: favoriteErrorIsPresented
            ) {
                Button("OK", role: .cancel) {
                    favoriteErrorMessage = nil
                }
            } message: {
                Text(favoriteErrorMessage ?? "Please try again.")
            }
            .alert("Couldn’t Reuse Meal", isPresented: templateErrorIsPresented) {
                Button("OK", role: .cancel) {
                    templateErrorMessage = nil
                }
            } message: {
                Text(templateErrorMessage ?? "Please try again.")
            }
            .onAppear {
                if automaticallyFocusSearch {
                    isSearchFocused = true
                }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(CalorynTheme.textSecondary)

                TextField("Search foods...", text: $searchText)
                    .font(CalorynTheme.bodyText)
                    .focused($isSearchFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit { searchService.search(query: searchText) }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        searchService.clearResults()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(CalorynTheme.textSecondary)
                    }
                }
            }
            .padding(12)
            .adaptiveCapsuleGlass()
            .overlay {
                Capsule()
                    .stroke(
                        isSearchFocused
                            ? CalorynTheme.sage.opacity(0.42)
                            : CalorynTheme.textSecondary.opacity(0.10),
                        lineWidth: isSearchFocused ? 1 : 0.5
                    )
                    .allowsHitTesting(false)
            }
            .animation(.smooth(duration: 0.18), value: isSearchFocused)

            Button {
                isSearchFocused = false
                showingScanner = true
            } label: {
                Image(systemName: "barcode.viewfinder")
                    .font(CalorynTheme.inlineIcon)
                    .foregroundStyle(CalorynTheme.sage)
                    .frame(width: 44, height: 44)
            }
            .adaptiveCircleInteractiveGlass()
        }
        .padding(.horizontal, CalorynTheme.pagePadding)
        .padding(.vertical, 10)
        .onChange(of: searchText) {
            searchService.search(query: searchText)
        }
    }

    private var recentFoodsList: some View {
        List {
            if !mode.isIngredientSelection {
                Section {
                    if mealTemplates.isEmpty {
                        ReusableMealEmptyRow(
                            title: "No Reusable Meals",
                            message: "Save logged entries from Today to reuse them here.",
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
                            .accessibilityIdentifier("mealTemplate.select.\(template.id.uuidString)")
                        }
                    }
                } header: {
                    Label("Reusable Meals", systemImage: "square.stack.3d.up.fill")
                        .font(CalorynTheme.caption)
                        .foregroundStyle(CalorynTheme.textSecondary)
                }
            }

            if !favoriteFoods.isEmpty {
                Section {
                    ForEach(visibleFavoriteFoods) { food in
                        FavoriteFoodRowView(
                            food: food,
                            plan: favoritePlan(for: food),
                            destinationDescription: destinationDescription,
                            onLog: { handleFavoriteFoodAction(food) },
                            onRemoveFavorite: { toggleFavorite(food) }
                        )
                    }

                    if favoriteFoods.count > FavoriteFoodLogging.collapsedFavoriteLimit {
                        Button(action: toggleFavoritesDisclosure) {
                            HStack {
                                Text(showsAllFavorites ? "Show less" : "Show all \(favoriteFoods.count)")
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
                                : "Show all \(favoriteFoods.count) favorites"
                        )
                    }
                } header: {
                    Label("Favorites", systemImage: "star.fill")
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)
                }
            }

            if !displayedRecentFoods.isEmpty {
                Section {
                    ForEach(displayedRecentFoods) { food in
                        savedFoodRow(for: food)
                    }
                } header: {
                    recentSectionHeader
                }
            }
        }
        .listStyle(.plain)
    }

    private var matchingCustomFoods: [FoodItem] {
        let query = searchText.lowercased().trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return [] }
        return customFoods.filter {
            $0.name.lowercased().contains(query)
            || ($0.brand?.lowercased().contains(query) ?? false)
        }
    }

    private var matchingRecipes: [FoodItem] {
        let query = searchText.lowercased().trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return [] }
        return recipes.filter {
            $0.name.lowercased().contains(query)
        }
    }

    private var searchResultsList: some View {
        Group {
            if searchService.isSearching && matchingCustomFoods.isEmpty && matchingRecipes.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = searchService.errorMessage, matchingCustomFoods.isEmpty && matchingRecipes.isEmpty {
                ContentUnavailableView {
                    Label("Food Search Unavailable", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(error)
                } actions: {
                    Button("Try Again") {
                        searchService.search(query: searchText)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(CalorynTheme.sage)
                }
            } else if searchService.searchResults.isEmpty && matchingCustomFoods.isEmpty && matchingRecipes.isEmpty {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("Try a different search term.")
                )
            } else {
                List {
                    if !matchingRecipes.isEmpty {
                        Section {
                            ForEach(matchingRecipes) { food in
                                recipeRow(for: food)
                            }
                        } header: {
                            Text("Recipes")
                                .font(CalorynTheme.caption)
                                .foregroundStyle(CalorynTheme.textSecondary)
                        }
                    }

                    if !matchingCustomFoods.isEmpty {
                        Section {
                            ForEach(matchingCustomFoods) { food in
                                customFoodRow(for: food)
                            }
                        } header: {
                            Text("Manual Entries")
                                .font(CalorynTheme.caption)
                                .foregroundStyle(CalorynTheme.textSecondary)
                        }
                    }

                    if !searchService.searchResults.isEmpty {
                        Section {
                            ForEach(searchService.searchResults) { product in
                                Button {
                                    handleProductSelection(product)
                                } label: {
                                    FoodRowView(
                                        name: product.productName ?? "Unknown",
                                        brand: product.brands,
                                        caloriesPer100g: product.nutriments?.energyKcal100g ?? 0,
                                        nutriscoreGrade: product.nutritionGrades.flatMap { g in ["a","b","c","d","e"].contains(g.lowercased()) ? g.lowercased() : nil },
                                        servingDescription: product.formattedServingDescription,
                                        caloriesPerServing: product.caloriesPerServing
                                    )
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            if !matchingCustomFoods.isEmpty || !matchingRecipes.isEmpty {
                                Text("Search Results")
                                    .font(CalorynTheme.caption)
                                    .foregroundStyle(CalorynTheme.textSecondary)
                            }
                        }
                    }

                    if searchService.isSearching {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func customFoodRow(for food: FoodItem) -> some View {
        HStack(spacing: 12) {
            Button {
                handleFoodItemSelection(food)
            } label: {
                FoodRowView(
                    name: food.name,
                    brand: food.brand,
                    caloriesPer100g: food.caloriesPer100g,
                    nutriscoreGrade: food.nutriscoreGrade,
                    servingDescription: food.servingDescription,
                    isCustom: true,
                    showsTypeBadge: false
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !mode.isIngredientSelection {
                favoriteButton(for: food)
            }
        }
    }

    private func recipeRow(for food: FoodItem) -> some View {
        HStack(spacing: 12) {
            Button {
                handleFoodItemSelection(food)
            } label: {
                FoodRowView(
                    name: food.name,
                    brand: food.brand,
                    caloriesPer100g: food.caloriesPer100g,
                    caloriesPerServing: food.calories(forGrams: food.defaultServingG ?? 100),
                    isRecipe: true,
                    showsTypeBadge: false
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            favoriteButton(for: food)
        }
    }

    private func savedFoodRow(for food: FoodItem) -> some View {
        Button {
            handleFoodItemSelection(food)
        } label: {
            FoodRowView(
                name: food.name,
                brand: food.brand,
                caloriesPer100g: food.caloriesPer100g,
                nutriscoreGrade: food.nutriscoreGrade,
                servingDescription: food.servingDescription
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func favoriteButton(for food: FoodItem) -> some View {
        Button {
            toggleFavorite(food)
        } label: {
            Image(systemName: food.isFavorite ? "star.fill" : "star")
                .font(CalorynTheme.inlineIcon)
                .foregroundStyle(food.isFavorite ? CalorynTheme.terracotta : CalorynTheme.textSecondary)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            food.isFavorite
                ? "Remove \(food.name) from favorites"
                : "Add \(food.name) to favorites"
        )
        .accessibilityHint(
            food.isFavorite
                ? "Removes this item from quick logging favorites"
                : "Adds this item to quick logging favorites"
        )
    }

    private var recentSectionHeader: some View {
        Text("Recent")
            .font(CalorynTheme.caption)
            .foregroundStyle(CalorynTheme.textSecondary)
    }

    private var destinationDescription: String {
        let normalizedSnackIndex = DailyFoodLogCommands.normalizedSnackIndex(
            for: mealType,
            requestedSnackIndex: snackIndex
        )
        return "\(logDate.shortFormatted) · \(mealType.displayName(snackIndex: normalizedSnackIndex))"
    }

    private func favoritePlan(for food: FoodItem) -> FavoriteFoodLogPlan {
        FavoriteFoodLogging.plan(
            for: food,
            destinationMeal: mealType,
            destinationDate: logDate,
            destinationSnackIndex: snackIndex
        )
    }

    private func handleFavoriteFoodAction(_ food: FoodItem) {
        let plan = favoritePlan(for: food)
        switch plan.action {
        case .log:
            do {
                try FavoriteFoodLogging.log(
                    plan: plan,
                    food: food,
                    modelContext: modelContext
                )
                dismiss()
            } catch {
                favoriteErrorMessage = error.localizedDescription
            }
        case .confirmQuantity:
            selectedFoodItem = food
        case .unavailable:
            favoriteErrorMessage = FavoriteFoodLogging.LoggingError.unavailable.localizedDescription
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

    private func reuse(_ template: MealTemplate) {
        do {
            templateLogPresentation = TemplateLogPresentation(
                templateName: template.name,
                snapshots: try MealTemplateCommands.snapshots(for: template)
            )
        } catch {
            templateErrorMessage = error.localizedDescription
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

    private var barcodeScannerSheet: some View {
        ZStack(alignment: .topLeading) {
            BarcodeScannerView { code in
                showingScanner = false
                handleScannedBarcode(code)
            }
            .ignoresSafeArea()

            Button {
                showingScanner = false
            } label: {
                Image(systemName: "xmark")
                    .font(CalorynTheme.toolbarIcon)
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding(.top, 56)
            .padding(.leading, 20)
        }
    }

    private var barcodeLookupOverlay: some View {
        VStack(spacing: 16) {
            Spacer()
            if let error = barcodeLookupError {
                Image(systemName: "barcode.viewfinder")
                    .font(CalorynTheme.emptyStateIcon)
                    .foregroundStyle(CalorynTheme.textSecondary)
                Text(error)
                    .font(CalorynTheme.bodyText)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .multilineTextAlignment(.center)
                HStack(spacing: 12) {
                    Button("Dismiss") {
                        barcodeLookupError = nil
                    }
                    .buttonStyle(.bordered)
                    .tint(CalorynTheme.textSecondary)

                    Button("Try Again") {
                        barcodeLookupError = nil
                        showingScanner = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(CalorynTheme.sage)
                }
            } else {
                ProgressView()
                    .controlSize(.large)
                Text("Looking up product...")
                    .font(CalorynTheme.bodyText)
                    .foregroundStyle(CalorynTheme.textSecondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func handleScannedBarcode(_ code: String) {
        isLookingUpBarcode = true
        barcodeLookupError = nil

        Task {
            do {
                let product = try await searchService.lookupBarcode(code)
                isLookingUpBarcode = false
                handleProductSelection(product)
            } catch is BarcodeLookupError {
                isLookingUpBarcode = false
                barcodeLookupError = "No results found\nfor this barcode."
                triggerBarcodeLookupHaptic(.warning)
            } catch {
                isLookingUpBarcode = false
                barcodeLookupError = "Lookup failed.\nCheck your connection."
                triggerBarcodeLookupHaptic(.error)
            }
        }
    }

    private func triggerBarcodeLookupHaptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }

    private func handleProductSelection(_ product: OpenFoodFactsProduct) {
        switch mode {
        case .logging:
            selectedProduct = product
        case .ingredientSelection(let handler):
            let food = searchService.createFoodItem(from: product)
            handler(food)
            dismiss()
        }
    }

    private func handleFoodItemSelection(_ food: FoodItem) {
        switch mode {
        case .logging:
            selectedFoodItem = food
        case .ingredientSelection(let handler):
            handler(food)
            dismiss()
        }
    }

}

private struct ReusableMealEmptyRow: View {
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
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    FoodSearchView(mealType: .breakfast, logDate: .now)
        .modelContainer(for: [UserProfile.self, FoodItem.self, FoodLogEntry.self, RecipeIngredient.self, MealTemplate.self, MealTemplateItem.self], inMemory: true)
}
