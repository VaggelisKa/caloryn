import SwiftUI
import SwiftData
import UIKit

/// The row builders live in `FoodSearchRows.swift`; the members they touch
/// are internal rather than private so that same-type extension can reach
/// them from its own file. Nothing else should.
struct FoodSearchView: View {
    struct MultiAddPresentation: Identifiable {
        let id = UUID()
        let groups: [MultiAddSelectionGroup]
    }

    /// A saved food on its way to the portion picker, carrying the portion a
    /// contextual suggestion came with when that is where the tap started.
    struct PortionDestination: Identifiable, Hashable {
        let food: FoodItem
        var suggestedPortionGrams: Double?

        var id: UUID { food.id }
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
    @State var selectedFoodItem: PortionDestination?
    @State private var showingScanner = false
    @State private var hasPresentedInitialScanner = false
    @State private var showingCustomFoodForm = false
    /// Every rule about what a scan, a failure and a recovery do to this
    /// screen's state lives in `BarcodeLookupFlow`.
    @State private var barcodeFlow = BarcodeLookupFlow(
        error: FoodSearchService.debugInitialBarcodeFailure,
        lastScannedBarcode: FoodSearchService.debugInitialBarcode
    )
    @State private var mealErrorMessage: String?
    @State var isSelectingMultiple = false
    @State private var multiAddSelection = MultiAddSelectionState()
    @State private var suggestionSnapshot: [ContextualFoodSuggestion] = []
    @State private var hasCapturedSuggestions = false
    @State var multiAddPresentation: MultiAddPresentation?
    @ScaledMetric(relativeTo: .body)
    var selectionIndicatorWidth: CGFloat = 22
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
            isLookingUpBarcode: barcodeFlow.isLookingUp,
            hasBarcodeLookupError: barcodeFlow.hasError
        )
    }

    /// Which of the screen's seven states is showing. `FoodSearchScreenContent`
    /// owns the precedence; the view only renders the answer.
    private var screenContent: FoodSearchScreenContent {
        FoodSearchScreenContent.resolve(
            isLookingUpBarcode: barcodeFlow.isLookingUp,
            hasBarcodeLookupError: barcodeFlow.hasError,
            showingRecent: showingRecent,
            isSearching: searchService.isSearching,
            hasSearchFailure: searchService.failure != nil,
            hasLocalMatches: hasLocalMatches,
            hasProductSearchResults: hasProductSearchResults
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar

                switch screenContent {
                case .barcodeLookupFailure, .barcodeLookupProgress:
                    barcodeLookupOverlay
                case .recent:
                    recentFoodsList
                case .searchProgress:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .searchFailure:
                    if let failure = searchService.failure {
                        FoodLookupFailureView(presentation: failure.presentation) {
                            searchService.search(query: searchText)
                        }
                    }
                case .noResults:
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different search term.")
                    )
                case .results:
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
                            barcodeFlow.manualEntryOpened()
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
            .navigationDestination(item: $selectedFoodItem) { destination in
                PortionPickerView(
                    foodItem: destination.food,
                    mealType: mealType,
                    logDate: logDate,
                    isNewFood: false,
                    snackIndex: snackIndex,
                    suggestedPortionGrams: destination.suggestedPortionGrams
                ) { dismiss() }
            }
            .sheet(isPresented: $showingCustomFoodForm) {
                CustomFoodFormView(
                    prefilledBarcode: barcodeFlow.manualRecoveryBarcode,
                    onSaved: { food in
                        showingCustomFoodForm = false
                        barcodeFlow.manualEntrySaved()
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
                    isSearchFocused = !screenContent.coversSearchField
                }
            }
            .task(id: barcodeFlow.pendingBarcode) {
                guard let pendingBarcode = barcodeFlow.pendingBarcode else { return }
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
                barcodeFlow.scannerOpened()
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
            if FoodSearchScreenContent.dismissesBarcodeFailure(
                forSearchText: searchText,
                errorDismissesOnNameSearch: barcodeFlow.errorDismissesOnNameSearch
            ) {
                BarcodeRecoveryAnalytics.record(path: .nameSearch, result: .started)
                barcodeFlow.nameSearchStarted()
            }
            searchService.search(query: searchText)
        }
    }

    private var recentFoodsList: some View {
        List {
            if !contextualSuggestions.isEmpty {
                foodSection(title: "Suggested for This Meal") {
                    ForEach(contextualSuggestions, id: \.1.id) { pair in
                        contextualSuggestionRow(
                            food: pair.0,
                            suggestion: pair.1
                        )
                    }
                }
            }

            if mode.supportsMultiSelection, !mealTemplates.isEmpty {
                foodSection(title: "Meals") {
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
                            selectionAccessibilityValue(for: .meal(meal.id))
                        )
                        .accessibilityIdentifier("meal.select.\(meal.id.uuidString)")
                    }
                }
            }

            if mode.isSelection, !recipes.isEmpty {
                foodSection(title: "Recipes", stickyHeaderStyle: .system) {
                    ForEach(recipes) { recipe in
                        recipeRow(for: recipe)
                    }
                }
            }

            if mode.isSelection, !manualEntries.isEmpty {
                foodSection(title: "Manual Entries", stickyHeaderStyle: .system) {
                    ForEach(manualEntries) { food in
                        personalFoodRow(for: food)
                    }
                }
            }

            if !displayedRecentFoods.isEmpty {
                foodSection(title: "Recent") {
                    ForEach(displayedRecentFoods) { food in
                        savedFoodRow(for: food)
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
        List {
            if !matchingMeals.isEmpty {
                foodSection(title: "Meals") {
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
                            selectionAccessibilityValue(for: .meal(meal.id))
                        )
                    }
                }
            }

            if !matchingRecipes.isEmpty {
                foodSection(title: "Recipes") {
                    ForEach(matchingRecipes) { food in
                        recipeRow(for: food)
                    }
                }
            }

            if !matchingManualEntries.isEmpty {
                foodSection(title: "Manual Entries") {
                    ForEach(matchingManualEntries) { food in
                        personalFoodRow(for: food)
                    }
                }
            }

            if hasProductSearchResults {
                foodSection(
                    title: "Search Results",
                    showsTitle: hasCategorizedLocalMatches
                ) {
                    ForEach(matchingEditedProducts) { food in
                        savedFoodRow(for: food)
                    }

                    ForEach(visibleProviderSearchResults) { result in
                        remoteProductRow(result)
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
                .listRowBackground(Color.clear)
            }
        }
        .calorynPlainListStyle()
    }

    /// How a section labels itself when the mode pins headers to the top of
    /// the list (`usesNonStickySectionTitles == false`).
    ///
    /// Two styles exist because the two lists have never agreed: the resting
    /// list's Recipes and Manual Entries sections use `Section(_:)`'s system
    /// header, while every other pinned header is a caption-styled `Text`.
    /// This is a rendering refactor, so the inconsistency is preserved, not
    /// resolved.
    private enum StickyHeaderStyle {
        case system
        case caption
    }

    /// The one shape every section of both lists shares: a title that either
    /// scrolls away with its rows or pins to the top, per the mode, above
    /// rows on a clear background.
    @ViewBuilder
    private func foodSection<Rows: View>(
        title: String,
        stickyHeaderStyle: StickyHeaderStyle = .caption,
        showsTitle: Bool = true,
        @ViewBuilder rows: () -> Rows
    ) -> some View {
        if mode.usesNonStickySectionTitles {
            if showsTitle {
                nonStickySectionTitle(title)
            }

            rows()
                .listRowBackground(Color.clear)
        } else {
            switch stickyHeaderStyle {
            case .system:
                Section(title) {
                    rows()
                        .listRowBackground(Color.clear)
                }
            case .caption:
                Section {
                    rows()
                        .listRowBackground(Color.clear)
                } header: {
                    if showsTitle {
                        Text(title)
                            .font(CalorynTheme.caption)
                            .foregroundStyle(CalorynTheme.textSecondary)
                    }
                }
            }
        }
    }

    var selectionModeAnimation: Animation? {
        accessibilityReduceMotion
            ? nil
            : .smooth(duration: 0.22)
    }

    var selectionChangeAnimation: Animation? {
        accessibilityReduceMotion
            ? nil
            : .spring(response: 0.22, dampingFraction: 0.72)
    }

    private var reviewButtonTitle: String {
        MultiAddSelectionLabels.reviewButtonTitle(
            selectedItemCount: selectedItemCount
        )
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

    func isSelected(_ id: MultiAddSelectionGroup.ID) -> Bool {
        multiAddSelection.contains(id)
    }

    func selectionAccessibilityValue(
        for id: MultiAddSelectionGroup.ID
    ) -> String {
        MultiAddSelectionLabels.selectionValue(
            isSelectingMultiple: isSelectingMultiple,
            isSelected: isSelected(id)
        )
    }

    private func toggle(_ group: MultiAddSelectionGroup) {
        withAnimation(selectionChangeAnimation) {
            multiAddSelection.toggle(group)
        }
    }

    private func toggle(
        _ id: MultiAddSelectionGroup.ID,
        makeGroup: () throws -> MultiAddSelectionGroup
    ) rethrows {
        try withAnimation(selectionChangeAnimation) {
            try multiAddSelection.toggle(id, makeGroup: makeGroup)
        }
    }

    func toggleFoodSelection(_ food: FoodItem) {
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
        toggle(.remoteProduct(product.id)) {
            .remoteProduct(
                result,
                searchService: searchService,
                meal: mealType,
                snackIndex: snackIndex
            )
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
        do {
            try toggle(.meal(meal.id)) {
                .meal(
                    meal,
                    snapshots: try MealTemplateCommands.snapshots(for: meal)
                )
            }
        } catch {
            mealErrorMessage = error.localizedDescription
        }
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
                barcodeFlow.scanned(code)
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
            if let error = barcodeFlow.error {
                BarcodeLookupFailureView(
                    presentation: error.presentation(for: .barcode),
                    normalizedBarcode: barcodeFlow.lastScannedBarcode,
                    offersManualCreation: barcodeFlow.offersManualCreation,
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

    private func performBarcodeLookup(_ code: String) async {
        let outcome = await BarcodeLookupRecoveryCoordinator.resolve(
            barcode: code,
            localFoods: recentFoods,
            providerLookup: searchService.lookupBarcode
        )
        guard !Task.isCancelled else { return }

        switch outcome {
        case .remote(let result):
            barcodeFlow.lookupSucceeded()
            handleProductSelection(result)
        case .local(let food, _):
            barcodeFlow.lookupSucceeded()
            try? modelContext.save()
            handleFoodItemSelection(food)
        case .failure(let error):
            guard let feedback = barcodeFlow.lookupFailed(error) else { return }
            triggerBarcodeLookupHaptic(feedback)
        }
    }

    private func openManualBarcodeRecovery() {
        guard barcodeFlow.manualRecoveryOpened() else { return }
        BarcodeRecoveryAnalytics.record(path: .manualCreation, result: .started)
        isSearchFocused = false
        showingCustomFoodForm = true
    }

    private func handleRetryableBarcodeFailureAction() {
        switch barcodeFlow.retryRequested() {
        case .repeatLookup:
            break
        case .rescan:
            showingScanner = true
        }
    }

    private func triggerBarcodeLookupHaptic(_ feedback: BarcodeLookupFlow.FailureFeedback) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        switch feedback {
        case .warning:
            generator.notificationOccurred(.warning)
        case .error:
            generator.notificationOccurred(.error)
        }
    }

    func handleProductSelection(_ result: FoodSearchResult) {
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

    func handleFoodItemSelection(_ food: FoodItem) {
        switch mode {
        case .logging:
            if isSelectingMultiple {
                toggleFoodSelection(food)
            } else {
                selectedFoodItem = PortionDestination(food: food)
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
