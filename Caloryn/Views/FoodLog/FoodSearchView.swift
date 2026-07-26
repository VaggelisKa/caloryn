import SwiftUI
import SwiftData
import UIKit

enum FoodSearchMode {
    case logging
    case ingredientSelection((FoodItem) -> Void)
    case mealComponentSelection((FoodItem) -> Void)

    var title: String {
        switch self {
        case .logging: "Add Food"
        case .ingredientSelection: "Add Ingredient"
        case .mealComponentSelection: "Add Meal Item"
        }
    }

    var isSelection: Bool {
        switch self {
        case .logging: false
        case .ingredientSelection, .mealComponentSelection: true
        }
    }

    var includesRecipes: Bool {
        switch self {
        case .logging, .mealComponentSelection: true
        case .ingredientSelection: false
        }
    }

    var usesNonStickySectionTitles: Bool {
        switch self {
        case .logging, .mealComponentSelection: true
        case .ingredientSelection: false
        }
    }

    var allowsManualEntryCreation: Bool {
        switch self {
        case .ingredientSelection: true
        case .logging, .mealComponentSelection: false
        }
    }

    var supportsMultiSelection: Bool {
        switch self {
        case .logging: true
        case .ingredientSelection, .mealComponentSelection: false
        }
    }

    func isMultiSelectionControlEnabled(
        isSelectingMultiple: Bool,
        selectableOptionCount: Int
    ) -> Bool {
        supportsMultiSelection
            && (isSelectingMultiple || selectableOptionCount > 0)
    }

    var isIngredientSelection: Bool {
        switch self {
        case .ingredientSelection: true
        case .logging, .mealComponentSelection: false
        }
    }
}

struct FoodSearchView: View {
    private struct MultiAddPresentation: Identifiable {
        let id = UUID()
        let groups: [MultiAddSelectionGroup]
    }

    let mealType: MealType
    let logDate: Date
    var snackIndex: Int = 0
    var mode: FoodSearchMode = .logging
    var automaticallyFocusSearch = true
    var startsWithScanner = false

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Query(sort: \FoodItem.lastUsed, order: .reverse) private var recentFoods: [FoodItem]
    @Query(sort: \MealTemplate.updatedAt, order: .reverse) private var mealTemplates: [MealTemplate]

    @State private var searchService = FoodSearchService()
    @State private var searchText = FoodSearchService.debugInitialSearchText
    @State private var selectedResult: FoodSearchResult?
    @State private var selectedFoodItem: FoodItem?
    @State private var showingScanner = false
    @State private var hasPresentedInitialScanner = false
    @State private var showingCustomFoodForm = false
    @State private var isLookingUpBarcode = false
    @State private var barcodeLookupError = FoodSearchService.debugInitialBarcodeFailure
    @State private var pendingBarcode: String?
    @State private var lastScannedBarcode = FoodSearchService.debugInitialBarcode
    @State private var manualRecoveryBarcode: String?
    @State private var mealErrorMessage: String?
    @State private var isSelectingMultiple = false
    @State private var multiAddSelection = MultiAddSelectionState()
    @State private var suggestionSnapshot: [ContextualFoodSuggestion] = []
    @State private var hasCapturedSuggestions = false
    @State private var multiAddPresentation: MultiAddPresentation?
    @ScaledMetric(relativeTo: .body)
    private var selectionIndicatorWidth: CGFloat = 22
    @FocusState private var isSearchFocused: Bool

    /// Every rule about what this screen lists lives in `FoodSearchListing`.
    /// The view reads it; it does not decide anything itself.
    private var listing: FoodSearchListing {
        FoodSearchListing(
            mode: FoodSearchListing.Mode(mode),
            searchText: searchText,
            recentFoods: recentFoods,
            mealTemplates: mealTemplates,
            providerResults: searchService.searchResults,
            suggestions: suggestionSnapshot
        )
    }

    private var showingRecent: Bool { listing.showingRecent }

    private var recipes: [FoodItem] { listing.recipes }

    private var manualEntries: [FoodItem] { listing.manualEntries }

    private var displayedRecentFoods: [FoodItem] { listing.displayedRecentFoods }

    private var contextualSuggestions: [(FoodItem, ContextualFoodSuggestion)] {
        listing.contextualSuggestions
    }

    private var selectedItemCount: Int {
        multiAddSelection.itemCount
    }

    private var selectableOptionCount: Int {
        listing.selectableOptionCount(
            isLookingUpBarcode: isLookingUpBarcode,
            hasBarcodeLookupError: barcodeLookupError != nil
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
            .calorynSheetCanvas()
            .navigationTitle(mode.title)
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
                if mode.supportsMultiSelection {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            toggleMultiSelectionMode()
                        } label: {
                            Text(isSelectingMultiple ? "Cancel" : "Select")
                                .contentTransition(.opacity)
                                .foregroundStyle(CalorynTheme.sage)
                                .animation(
                                    selectionModeAnimation,
                                    value: isSelectingMultiple
                                )
                        }
                        .accessibilityLabel(
                            isSelectingMultiple
                                ? "Cancel multiple selection"
                                : "Select multiple items"
                        )
                        .disabled(
                            !mode.isMultiSelectionControlEnabled(
                                isSelectingMultiple: isSelectingMultiple,
                                selectableOptionCount: selectableOptionCount
                            )
                        )
                    }
                } else if mode.allowsManualEntryCreation {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            manualRecoveryBarcode = nil
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
            .safeAreaInset(edge: .bottom) {
                Group {
                    if isSelectingMultiple, selectedItemCount > 0 {
                        Button {
                            multiAddPresentation = MultiAddPresentation(
                                groups: multiAddSelection.groups
                            )
                        } label: {
                            Label {
                                Text(reviewButtonTitle)
                                    .contentTransition(.numericText())
                            } icon: {
                                Image(systemName: "checkmark.circle.fill")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .padding(.horizontal, CalorynTheme.pagePadding)
                        .padding(.vertical, 10)
                        .background(.bar)
                        .transition(
                            .move(edge: .bottom)
                                .combined(with: .opacity)
                        )
                        .accessibilityIdentifier("multiAdd.review")
                    }
                }
                .animation(selectionChangeAnimation, value: selectedItemCount)
            }
            .navigationDestination(item: $selectedResult) { result in
                let food = searchService.createFoodItem(from: result)
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
                CustomFoodFormView(
                    prefilledBarcode: manualRecoveryBarcode,
                    onSaved: { food in
                        showingCustomFoodForm = false
                        manualRecoveryBarcode = nil
                        barcodeLookupError = nil
                        lastScannedBarcode = nil
                        Task { @MainActor in
                            handleFoodItemSelection(food)
                        }
                    }
                )
            }
            .sheet(item: $multiAddPresentation) { presentation in
                MultiAddReviewView(
                    groups: presentation.groups,
                    initialDate: logDate,
                    initialMeal: mealType,
                    initialSnackIndex: snackIndex,
                    onLogged: dismiss.callAsFunction
                )
                .presentationDragIndicator(.visible)
            }
            .fullScreenCover(isPresented: $showingScanner) {
                barcodeScannerSheet
            }
            .alert("Couldn’t Add Meal", isPresented: mealErrorIsPresented) {
                Button("OK", role: .cancel) {
                    mealErrorMessage = nil
                }
            } message: {
                Text(mealErrorMessage ?? "Please try again.")
            }
            .onAppear {
                captureSuggestionsIfNeeded()
                if startsWithScanner, !hasPresentedInitialScanner {
                    hasPresentedInitialScanner = true
                    showingScanner = true
                }
                if automaticallyFocusSearch {
                    // Keep focus away from a covered search field while a barcode
                    // result is presented so its navigation title settles cleanly.
                    isSearchFocused = !isLookingUpBarcode
                        && barcodeLookupError == nil
                }
            }
            .task(id: pendingBarcode) {
                guard let pendingBarcode else { return }
                await performBarcodeLookup(pendingBarcode)
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
                    .accessibilityIdentifier("foodSearch.searchField")

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
                barcodeLookupError = nil
                lastScannedBarcode = nil
                manualRecoveryBarcode = nil
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
            if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               barcodeLookupError?.dismissesWhenNameSearchBegins == true {
                BarcodeRecoveryAnalytics.record(path: .nameSearch, result: .started)
                barcodeLookupError = nil
                lastScannedBarcode = nil
                manualRecoveryBarcode = nil
            }
            searchService.search(query: searchText)
        }
    }

    private var recentFoodsList: some View {
        List {
            if !contextualSuggestions.isEmpty {
                nonStickySectionTitle("Suggested for This Meal")

                ForEach(contextualSuggestions, id: \.1.id) { pair in
                    contextualSuggestionRow(
                        food: pair.0,
                        suggestion: pair.1
                    )
                }
                .listRowBackground(Color.clear)
            }

            if mode.supportsMultiSelection, !mealTemplates.isEmpty {
                nonStickySectionTitle("Meals")

                ForEach(mealTemplates) { meal in
                    Button {
                        handleMealSelection(meal)
                    } label: {
                        selectionRow(
                            isSelected: isSelected(.meal(meal.id))
                        ) {
                            MealTemplateLibraryRow(
                                template: meal,
                                showsIcon: false
                            )
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(
                        isSelectingMultiple
                            ? selectionAccessibilityValue(for: .meal(meal.id))
                            : ""
                    )
                    .accessibilityIdentifier("meal.select.\(meal.id.uuidString)")
                }
                .listRowBackground(Color.clear)
            }

            if mode.isSelection, !recipes.isEmpty {
                if mode.usesNonStickySectionTitles {
                    nonStickySectionTitle("Recipes")

                    ForEach(recipes) { recipe in
                        recipeRow(for: recipe)
                    }
                    .listRowBackground(Color.clear)
                } else {
                    Section("Recipes") {
                        ForEach(recipes) { recipe in
                            recipeRow(for: recipe)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
            }

            if mode.isSelection, !manualEntries.isEmpty {
                if mode.usesNonStickySectionTitles {
                    nonStickySectionTitle("Manual Entries")

                    ForEach(manualEntries) { food in
                        personalFoodRow(for: food)
                    }
                    .listRowBackground(Color.clear)
                } else {
                    Section("Manual Entries") {
                        ForEach(manualEntries) { food in
                            personalFoodRow(for: food)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
            }

            if !displayedRecentFoods.isEmpty {
                if mode.usesNonStickySectionTitles {
                    nonStickySectionTitle("Recent")

                    ForEach(displayedRecentFoods) { food in
                        savedFoodRow(for: food)
                    }
                    .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(displayedRecentFoods) { food in
                            savedFoodRow(for: food)
                        }
                        .listRowBackground(Color.clear)
                    } header: {
                        recentSectionHeader
                    }
                }
            }
        }
        .calorynPlainListStyle()
    }

    private var matchingManualEntries: [FoodItem] { listing.matchingManualEntries }

    private var matchingEditedProducts: [FoodItem] { listing.matchingEditedProducts }

    private var visibleProviderSearchResults: [FoodSearchResult] {
        listing.visibleProviderSearchResults
    }

    private var matchingRecipes: [FoodItem] { listing.matchingRecipes }

    private var matchingMeals: [MealTemplate] { listing.matchingMeals }

    private var hasLocalMatches: Bool { listing.hasLocalMatches }

    private var hasCategorizedLocalMatches: Bool { listing.hasCategorizedLocalMatches }

    private var hasProductSearchResults: Bool { listing.hasProductSearchResults }

    private var searchResultsList: some View {
        Group {
            if searchService.isSearching && !hasLocalMatches {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let failure = searchService.failure, !hasLocalMatches {
                FoodLookupFailureView(presentation: failure.presentation) {
                    searchService.search(query: searchText)
                }
            } else if !hasProductSearchResults && !hasLocalMatches {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("Try a different search term.")
                )
            } else {
                List {
                    if !matchingMeals.isEmpty {
                        nonStickySectionTitle("Meals")

                        ForEach(matchingMeals) { meal in
                            Button {
                                handleMealSelection(meal)
                            } label: {
                                selectionRow(
                                    isSelected: isSelected(.meal(meal.id))
                                ) {
                                    MealTemplateLibraryRow(
                                        template: meal,
                                        showsIcon: false
                                    )
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityValue(
                                isSelectingMultiple
                                    ? selectionAccessibilityValue(for: .meal(meal.id))
                                    : ""
                            )
                        }
                        .listRowBackground(Color.clear)
                    }

                    if !matchingRecipes.isEmpty {
                        if mode.usesNonStickySectionTitles {
                            nonStickySectionTitle("Recipes")

                            ForEach(matchingRecipes) { food in
                                recipeRow(for: food)
                            }
                            .listRowBackground(Color.clear)
                        } else {
                            Section {
                                ForEach(matchingRecipes) { food in
                                    recipeRow(for: food)
                                }
                                .listRowBackground(Color.clear)
                            } header: {
                                Text("Recipes")
                                    .font(CalorynTheme.caption)
                                    .foregroundStyle(CalorynTheme.textSecondary)
                            }
                        }
                    }

                    if !matchingManualEntries.isEmpty {
                        if mode.usesNonStickySectionTitles {
                            nonStickySectionTitle("Manual Entries")

                            ForEach(matchingManualEntries) { food in
                                personalFoodRow(for: food)
                            }
                            .listRowBackground(Color.clear)
                        } else {
                            Section {
                                ForEach(matchingManualEntries) { food in
                                    personalFoodRow(for: food)
                                }
                                .listRowBackground(Color.clear)
                            } header: {
                                Text("Manual Entries")
                                    .font(CalorynTheme.caption)
                                    .foregroundStyle(CalorynTheme.textSecondary)
                            }
                        }
                    }

                    if hasProductSearchResults {
                        if mode.usesNonStickySectionTitles {
                            if hasCategorizedLocalMatches {
                                nonStickySectionTitle("Search Results")
                            }

                            ForEach(matchingEditedProducts) { food in
                                savedFoodRow(for: food)
                            }
                            .listRowBackground(Color.clear)

                            ForEach(visibleProviderSearchResults) { result in
                                remoteProductRow(result)
                            }
                            .listRowBackground(Color.clear)
                        } else {
                            Section {
                                ForEach(matchingEditedProducts) { food in
                                    savedFoodRow(for: food)
                                }
                                .listRowBackground(Color.clear)

                                ForEach(visibleProviderSearchResults) { result in
                                    remoteProductRow(result)
                                }
                                .listRowBackground(Color.clear)
                            } header: {
                                if hasCategorizedLocalMatches {
                                    Text("Search Results")
                                        .font(CalorynTheme.caption)
                                        .foregroundStyle(CalorynTheme.textSecondary)
                                }
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
                .calorynPlainListStyle()
            }
        }
    }

    private func personalFoodRow(for food: FoodItem) -> some View {
        Button {
            handleFoodItemSelection(food)
        } label: {
            selectionRow(isSelected: isSelected(.food(food.id))) {
                FoodRowView(
                    name: food.name,
                    brand: food.brand,
                    caloriesPer100g: food.caloriesPer100g,
                    nutriscoreGrade: food.nutriscoreGrade,
                    servingDescription: food.servingDescription,
                    isCustom: true,
                    showsTypeBadge: false
                )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(selectionAccessibilityValue(for: .food(food.id)))
        .accessibilityIdentifier("foodSearch.result.\(food.name)")
    }

    private func recipeRow(for food: FoodItem) -> some View {
        Button {
            handleFoodItemSelection(food)
        } label: {
            selectionRow(isSelected: isSelected(.food(food.id))) {
                FoodRowView(
                    name: food.name,
                    brand: food.brand,
                    caloriesPer100g: food.caloriesPer100g,
                    caloriesPerServing: food.calories(forGrams: food.defaultServingG ?? 100),
                    isRecipe: true,
                    showsTypeBadge: false
                )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(selectionAccessibilityValue(for: .food(food.id)))
    }

    private func savedFoodRow(for food: FoodItem) -> some View {
        Button {
            handleFoodItemSelection(food)
        } label: {
            selectionRow(isSelected: isSelected(.food(food.id))) {
                FoodRowView(
                    name: food.name,
                    brand: food.brand,
                    caloriesPer100g: food.caloriesPer100g,
                    nutriscoreGrade: food.nutriscoreGrade,
                    servingDescription: food.servingDescription
                )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(selectionAccessibilityValue(for: .food(food.id)))
        .accessibilityIdentifier("foodSearch.result.\(food.name)")
    }

    private func remoteProductRow(_ result: FoodSearchResult) -> some View {
        let product = result.product
        let productName = product.productName ?? "Unknown"

        return Button {
            handleProductSelection(result)
        } label: {
            selectionRow(
                isSelected: isSelected(.remoteProduct(product.id))
            ) {
                FoodRowView(
                    name: productName,
                    brand: product.brands,
                    caloriesPer100g: product.nutriments?.energyKcal100g ?? 0,
                    nutriscoreGrade: product.nutritionGrades.flatMap { grade in
                        ["a", "b", "c", "d", "e"].contains(grade.lowercased())
                            ? grade.lowercased()
                            : nil
                    },
                    servingDescription: product.formattedServingDescription,
                    caloriesPerServing: product.caloriesPerServing
                )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(
            selectionAccessibilityValue(for: .remoteProduct(product.id))
        )
    }

    private func contextualSuggestionRow(
        food: FoodItem,
        suggestion: ContextualFoodSuggestion
    ) -> some View {
        Button {
            if isSelectingMultiple {
                toggleFoodSelection(food)
            } else {
                multiAddPresentation = MultiAddPresentation(
                    groups: [
                        .savedFood(
                            food,
                            portionGrams: suggestion.resolvedPortionGrams,
                            meal: mealType,
                            snackIndex: snackIndex
                        ),
                    ]
                )
            }
        } label: {
            selectionRow(
                isSelected: isSelected(.food(food.id)),
                spacing: 12
            ) {
                Text(food.name)
                    .font(CalorynTheme.itemTitle)
                    .foregroundStyle(CalorynTheme.textPrimary)

                Spacer(minLength: 8)

                Text("\(Int(suggestion.resolvedPortionGrams.rounded()))g")
                    .font(CalorynTheme.numericBody)
                    .foregroundStyle(CalorynTheme.textPrimary)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "\(food.name), suggested \(Int(suggestion.resolvedPortionGrams.rounded())) grams"
        )
        .accessibilityValue(selectionAccessibilityValue(for: .food(food.id)))
        .accessibilityHint(
            isSelectingMultiple
                ? "Double tap to \(isSelected(.food(food.id)) ? "remove" : "select") this item"
                : "Double tap to review its portion"
        )
        .accessibilityIdentifier("contextualSuggestions.food.\(food.id.uuidString)")
    }

    private func selectionRow<Content: View>(
        isSelected: Bool,
        spacing: CGFloat = 10,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 0) {
            selectionIndicator(isSelected: isSelected)
                .frame(
                    width: selectionIndicatorWidth,
                    alignment: .leading
                )
                .opacity(isSelectingMultiple ? 1 : 0)
                .scaleEffect(
                    isSelectingMultiple ? 1 : 0.82,
                    anchor: .leading
                )
                .frame(
                    width: isSelectingMultiple
                        ? selectionIndicatorWidth + spacing
                        : 0,
                    alignment: .leading
                )
                .clipped()

            content()
        }
        .animation(selectionModeAnimation, value: isSelectingMultiple)
    }

    private func selectionIndicator(isSelected: Bool) -> some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(CalorynTheme.inlineIcon)
            .foregroundStyle(
                isSelected ? CalorynTheme.sage : CalorynTheme.textSecondary
            )
            .contentTransition(.symbolEffect(.replace))
            .scaleEffect(isSelected ? 1 : 0.94)
            .animation(selectionChangeAnimation, value: isSelected)
            .accessibilityHidden(true)
    }

    private var selectionModeAnimation: Animation? {
        accessibilityReduceMotion
            ? nil
            : .smooth(duration: 0.22)
    }

    private var selectionChangeAnimation: Animation? {
        accessibilityReduceMotion
            ? nil
            : .spring(response: 0.22, dampingFraction: 0.72)
    }

    private var reviewButtonTitle: String {
        let noun = selectedItemCount == 1 ? "Item" : "Items"
        return "Review \(selectedItemCount) \(noun)"
    }

    private func captureSuggestionsIfNeeded() {
        guard !hasCapturedSuggestions, mode.supportsMultiSelection else { return }
        let now = Date()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        guard let historyStart = calendar.date(
            byAdding: .day,
            value: -(ContextualFoodSuggestionRanker.historyDayCount - 1),
            to: today
        ), let historyEnd = calendar.date(byAdding: .day, value: 1, to: today) else {
            hasCapturedSuggestions = true
            return
        }
        let entries = (try? modelContext.fetch(
            FetchDescriptor<FoodLogEntry>(
                predicate: #Predicate { entry in
                    entry.date >= historyStart && entry.date < historyEnd
                }
            )
        )) ?? []
        suggestionSnapshot = ContextualFoodSuggestionAdapter.rank(
            foods: recentFoods,
            entries: entries,
            destinationDate: logDate,
            destinationMeal: mealType,
            destinationSnackIndex: snackIndex,
            now: now,
            calendar: calendar
        )
        hasCapturedSuggestions = true
    }

    private func toggleMultiSelectionMode() {
        isSearchFocused = false
        if isSelectingMultiple {
            isSelectingMultiple = false
            multiAddSelection.removeAll()
        } else {
            isSelectingMultiple = true
        }
    }

    private func isSelected(_ id: MultiAddSelectionGroup.ID) -> Bool {
        multiAddSelection.contains(id)
    }

    private func selectionAccessibilityValue(
        for id: MultiAddSelectionGroup.ID
    ) -> String {
        guard isSelectingMultiple else { return "" }
        return isSelected(id) ? "Selected" : "Not selected"
    }

    private func toggle(_ group: MultiAddSelectionGroup) {
        withAnimation(selectionChangeAnimation) {
            multiAddSelection.toggle(group)
        }
    }

    private func toggleFoodSelection(_ food: FoodItem) {
        let portion = suggestionSnapshot
            .first { $0.foodID == food.id }?
            .resolvedPortionGrams
            ?? ContextualFoodSuggestionAdapter.resolvedPortion(
                for: food,
                destinationDate: logDate,
                destinationMeal: mealType,
                destinationSnackIndex: snackIndex
            )
        toggle(
            .savedFood(
                food,
                portionGrams: portion,
                meal: mealType,
                snackIndex: snackIndex
            )
        )
    }

    private func toggleRemoteProductSelection(_ result: FoodSearchResult) {
        let product = result.product
        let id = MultiAddSelectionGroup.ID.remoteProduct(product.id)
        if multiAddSelection.contains(id) {
            withAnimation(selectionChangeAnimation) {
                multiAddSelection.remove(id)
            }
        } else {
            withAnimation(selectionChangeAnimation) {
                multiAddSelection.toggle(
                    .remoteProduct(
                        result,
                        searchService: searchService,
                        meal: mealType,
                        snackIndex: snackIndex
                    )
                )
            }
        }
    }

    private func handleMealSelection(_ meal: MealTemplate) {
        if isSelectingMultiple {
            toggleMealSelection(meal)
        } else {
            addMeal(meal)
        }
    }

    private func toggleMealSelection(_ meal: MealTemplate) {
        let id = MultiAddSelectionGroup.ID.meal(meal.id)
        if multiAddSelection.contains(id) {
            withAnimation(selectionChangeAnimation) {
                multiAddSelection.remove(id)
            }
            return
        }

        do {
            toggle(
                .meal(
                    meal,
                    snapshots: try MealTemplateCommands.snapshots(for: meal)
                )
            )
        } catch {
            mealErrorMessage = error.localizedDescription
        }
    }

    private var recentSectionHeader: some View {
        Text("Recent")
            .font(CalorynTheme.caption)
            .foregroundStyle(CalorynTheme.textSecondary)
    }

    private func nonStickySectionTitle(_ title: String) -> some View {
        Text(title)
            .font(CalorynTheme.caption)
            .foregroundStyle(CalorynTheme.textSecondary)
            .accessibilityAddTraits(.isHeader)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .padding(.top, 8)
    }

    private func addMeal(_ meal: MealTemplate) {
        do {
            let plan = try MealTemplateCommands.plan(
                sourceName: meal.name,
                snapshots: MealTemplateCommands.snapshots(for: meal),
                destinationDate: logDate,
                destinationMeal: mealType,
                destinationSnackIndex: snackIndex
            )
            try MealTemplateCommands.log(
                plan: plan,
                availableFoods: recentFoods,
                modelContext: modelContext
            )
            dismiss()
        } catch {
            mealErrorMessage = error.localizedDescription
        }
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
        Group {
            if let error = barcodeLookupError {
                BarcodeLookupFailureView(
                    presentation: error.presentation(for: .barcode),
                    normalizedBarcode: lastScannedBarcode,
                    offersManualCreation: error == .notFound,
                    onRetry: handleRetryableBarcodeFailureAction,
                    onCreateManually: openManualBarcodeRecovery
                )
            } else {
                VStack(spacing: 16) {
                    Spacer()
                ProgressView()
                    .controlSize(.large)
                Text("Looking up product...")
                    .font(CalorynTheme.bodyText)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func handleScannedBarcode(_ code: String) {
        guard let normalizedBarcode = BarcodeIdentity.normalized(code) else {
            isLookingUpBarcode = false
            barcodeLookupError = .invalidRequest
            lastScannedBarcode = nil
            return
        }
        isLookingUpBarcode = true
        barcodeLookupError = nil
        lastScannedBarcode = normalizedBarcode
        pendingBarcode = normalizedBarcode
    }

    private func performBarcodeLookup(_ code: String) async {
        let outcome = await BarcodeLookupRecoveryCoordinator.resolve(
            barcode: code,
            localFoods: recentFoods,
            providerLookup: searchService.lookupBarcode
        )
        guard !Task.isCancelled else { return }

        switch outcome {
        case .remote(let result):
            isLookingUpBarcode = false
            pendingBarcode = nil
            lastScannedBarcode = nil
            handleProductSelection(result)
        case .local(let food, _):
            isLookingUpBarcode = false
            pendingBarcode = nil
            lastScannedBarcode = nil
            try? modelContext.save()
            handleFoodItemSelection(food)
        case .failure(let error):
            guard error != .cancelled else { return }
            isLookingUpBarcode = false
            pendingBarcode = nil
            barcodeLookupError = error
            triggerBarcodeLookupHaptic(error == .notFound ? .warning : .error)
        }
    }

    private func openManualBarcodeRecovery() {
        guard let normalizedBarcode = BarcodeIdentity.normalized(lastScannedBarcode) else {
            return
        }
        manualRecoveryBarcode = normalizedBarcode
        BarcodeRecoveryAnalytics.record(path: .manualCreation, result: .started)
        barcodeLookupError = nil
        isSearchFocused = false
        showingCustomFoodForm = true
    }

    private func handleRetryableBarcodeFailureAction() {
        guard let lastScannedBarcode else {
            barcodeLookupError = nil
            showingScanner = true
            return
        }
        barcodeLookupError = nil
        isLookingUpBarcode = true
        pendingBarcode = lastScannedBarcode
    }

    private func triggerBarcodeLookupHaptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }

    private func handleProductSelection(_ result: FoodSearchResult) {
        switch mode {
        case .logging:
            if isSelectingMultiple {
                toggleRemoteProductSelection(result)
            } else {
                selectedResult = result
            }
        case .ingredientSelection(let handler), .mealComponentSelection(let handler):
            let food = searchService.createFoodItem(from: result)
            handler(food)
            dismiss()
        }
    }

    private func handleFoodItemSelection(_ food: FoodItem) {
        switch mode {
        case .logging:
            if isSelectingMultiple {
                toggleFoodSelection(food)
            } else {
                selectedFoodItem = food
            }
        case .ingredientSelection(let handler), .mealComponentSelection(let handler):
            handler(food)
            dismiss()
        }
    }

}

private struct FoodLookupFailureView: View {
    let presentation: FoodLookupFailurePresentation
    let onRetry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(presentation.title, systemImage: presentation.systemImage)
        } description: {
            Text(presentation.message)
        } actions: {
            if let retryTitle = presentation.retryTitle {
                Button(retryTitle, action: onRetry)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        }
    }
}

private struct BarcodeLookupFailureView: View {
    let presentation: FoodLookupFailurePresentation
    let normalizedBarcode: String?
    let offersManualCreation: Bool
    let onRetry: () -> Void
    let onCreateManually: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(presentation.title, systemImage: presentation.systemImage)
        } description: {
            VStack(spacing: 6) {
                Text(presentation.message)
                if offersManualCreation, let normalizedBarcode {
                    Text("Barcode \(normalizedBarcode)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        } actions: {
            VStack(spacing: 10) {
                if offersManualCreation, normalizedBarcode != nil {
                    Button("Create Manual Food", action: onCreateManually)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .accessibilityHint("Opens a private food with this barcode already filled in")
                }

                if let retryTitle = presentation.retryTitle {
                    Button(retryTitle, action: onRetry)
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                }
            }
        }
    }
}

#Preview {
    FoodSearchView(mealType: .breakfast, logDate: .now)
        .modelContainer(for: [UserProfile.self, FoodItem.self, FoodLogEntry.self, RecipeIngredient.self, MealTemplate.self, MealTemplateItem.self], inMemory: true)
}
