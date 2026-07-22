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
    let mealType: MealType
    let logDate: Date
    var snackIndex: Int = 0
    var mode: FoodSearchMode = .logging

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FoodItem.lastUsed, order: .reverse) private var recentFoods: [FoodItem]

    @State private var searchService = FoodSearchService()
    @State private var searchText = ""
    @State private var selectedProduct: OpenFoodFactsProduct?
    @State private var selectedFoodItem: FoodItem?
    @State private var showingScanner = false
    @State private var showingCustomFoodForm = false
    @State private var isLookingUpBarcode = false
    @State private var barcodeLookupError: String?
    @State private var quantityConfirmationFood: FoodItem?
    @State private var favoriteErrorMessage: String?
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
                .filter { !$0.isPinned && !$0.isCustom && !$0.isRecipe }
                .prefix(20)
        )
    }

    private var pinnedFoods: [FoodItem] {
        guard !mode.isIngredientSelection else { return [] }
        return PinnedFoodLogging.sortedPinnedFoods(from: recentFoods)
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
            .sheet(item: $quantityConfirmationFood) { food in
                PinnedPortionConfirmationView(
                    foodItem: food,
                    mealType: mealType,
                    logDate: logDate,
                    snackIndex: snackIndex,
                    onLogged: dismiss.callAsFunction
                )
                .presentationDetents([.medium])
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
            .onAppear {
                isSearchFocused = true
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
        Group {
            if mode.isIngredientSelection && displayedRecentFoods.isEmpty {
                ContentUnavailableView(
                    "No Recent Foods",
                    systemImage: "clock",
                    description: Text("Search above or create saved foods from My Foods.")
                )
            } else {
                List {
                    if !mode.isIngredientSelection {
                        Section {
                            if pinnedFoods.isEmpty {
                                PinnedFoodsEmptyRow()
                            } else {
                                ForEach(pinnedFoods) { food in
                                    PinnedFoodRowView(
                                        food: food,
                                        plan: pinnedPlan(for: food),
                                        destinationDescription: destinationDescription,
                                        onLog: { handlePinnedFoodAction(food) },
                                        onUnpin: { togglePinned(food) }
                                    )
                                }
                            }
                        } header: {
                            Label("Pinned", systemImage: "star.fill")
                                .font(CalorynTheme.caption)
                                .foregroundStyle(CalorynTheme.textSecondary)
                        }
                    }

                    if displayedRecentFoods.isEmpty {
                        if pinnedFoods.isEmpty {
                            Section {
                                SearchEmptyRow(
                                    title: "No Recent Foods",
                                    message: "Search above or create saved foods from My Foods.",
                                    systemImage: "clock"
                                )
                            } header: {
                                recentSectionHeader
                            }
                        }
                    } else {
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
        }
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

            pinButton(for: food)
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

            pinButton(for: food)
        }
    }

    private func savedFoodRow(for food: FoodItem) -> some View {
        HStack(spacing: 12) {
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

            pinButton(for: food)
        }
    }

    private func pinButton(for food: FoodItem) -> some View {
        Button {
            togglePinned(food)
        } label: {
            Image(systemName: food.isPinned ? "star.fill" : "star")
                .font(CalorynTheme.inlineIcon)
                .foregroundStyle(food.isPinned ? CalorynTheme.terracotta : CalorynTheme.textSecondary)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(food.isPinned ? "Unpin \(food.name)" : "Pin \(food.name)")
        .accessibilityHint(food.isPinned ? "Removes this item from favorites" : "Adds this item to favorites")
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

    private func pinnedPlan(for food: FoodItem) -> PinnedFoodLogPlan {
        PinnedFoodLogging.plan(
            for: food,
            destinationMeal: mealType,
            destinationDate: logDate,
            destinationSnackIndex: snackIndex
        )
    }

    private func handlePinnedFoodAction(_ food: FoodItem) {
        let plan = pinnedPlan(for: food)
        switch plan.action {
        case .log:
            do {
                try PinnedFoodLogging.log(
                    plan: plan,
                    food: food,
                    modelContext: modelContext
                )
                dismiss()
            } catch {
                favoriteErrorMessage = error.localizedDescription
            }
        case .confirmQuantity:
            quantityConfirmationFood = food
        case .unavailable:
            favoriteErrorMessage = PinnedFoodLogging.LoggingError.unavailable.localizedDescription
        }
    }

    private func togglePinned(_ food: FoodItem) {
        do {
            try PinnedFoodLogging.setPinned(
                !food.isPinned,
                for: food,
                modelContext: modelContext
            )
        } catch {
            favoriteErrorMessage = "Your favorite couldn’t be updated. Please try again."
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

#Preview {
    FoodSearchView(mealType: .breakfast, logDate: .now)
        .modelContainer(for: [UserProfile.self, FoodItem.self, FoodLogEntry.self, RecipeIngredient.self], inMemory: true)
}
