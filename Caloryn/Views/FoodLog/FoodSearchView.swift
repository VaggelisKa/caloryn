import SwiftUI
import SwiftData
import UIKit

struct FoodSearchView: View {
    struct MultiAddPresentation: Identifiable {
        let id = UUID()
        let groups: [MultiAddSelectionGroup]
    }

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
    @State private var revealFoodAfterScannerDismiss = false
    @State private var hasPresentedInitialScanner = false
    @State private var showingCustomFoodForm = false
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
    @ScaledMetric(relativeTo: .body)
    private var searchControlHeight: CGFloat = 46
    @FocusState private var isSearchFocused: Bool

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
                if screenContent != .barcodeLookupProgress {
                    searchBar
                }

                switch screenContent {
                case .barcodeLookupProgress:
                    BarcodeLookupProgressView(barcode: barcodeFlow.pendingBarcode)
                case .barcodeLookupFailure:
                    barcodeLookupOverlay
                case .recent:
                    recentFoodsList
                case .searchProgress:
                    FoodSearchSkeletonList()
                case .searchFailure:
                    if let failure = searchService.failure {
                        FoodLookupFailureView(presentation: failure.presentation) {
                            searchService.search(query: searchText)
                        }
                    }
                case .noResults:
                    ContentUnavailableView {
                        Label {
                            Text("No results")
                                .foregroundStyle(CalorynTheme.textPrimary)
                        } icon: {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(CalorynTheme.textSecondary)
                        }
                    } description: {
                        Text("Try a different search term.")
                            .foregroundStyle(CalorynTheme.textSecondary)
                    }
                case .results:
                    searchResultsList
                }
            }
            .calorynSheetCanvas()
            .navigationTitle(sheetTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    sheetTitleView
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(CalorynTheme.toolbarIcon)
                            .foregroundStyle(CalorynTheme.accent)
                    }
                    .accessibilityLabel("Close")
                }
                if mode.supportsMultiSelection {
                    ToolbarItem(placement: .primaryAction) {
                        let isEnabled = mode.isMultiSelectionControlEnabled(
                            isSelectingMultiple: isSelectingMultiple,
                            selectableOptionCount: selectableOptionCount
                        )
                        Button {
                            toggleMultiSelectionMode()
                        } label: {
                            Text(isSelectingMultiple ? "Cancel" : "Select")
                                .font(CalorynTheme.toolbarAction)
                                .contentTransition(.opacity)
                                .foregroundStyle(
                                    isEnabled ? CalorynTheme.accent : CalorynTheme.textSecondary
                                )
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
                        .disabled(!isEnabled)
                        .accessibilityIdentifier("foodSearch.selectMultiple")
                    }
                } else if mode.allowsManualEntryCreation {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            barcodeFlow.manualEntryOpened()
                            showingCustomFoodForm = true
                        } label: {
                            Image(systemName: "plus")
                                .font(CalorynTheme.toolbarIcon)
                                .foregroundStyle(CalorynTheme.accent)
                        }
                        .accessibilityLabel("Create Manual Entry")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Group {
                    if isSelectingMultiple, selectedItemCount > 0, screenContent != .barcodeLookupProgress {
                        Button {
                            multiAddPresentation = MultiAddPresentation(
                                groups: multiAddSelection.groups
                            )
                        } label: {
                            Text(reviewButtonTitle)
                                .contentTransition(.numericText())
                        }
                        .calorynPrimaryButton()
                        .padding(.horizontal, CalorynTheme.pagePadding)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                        .background {
                            FoodLogBottomFade()
                        }
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
            .fullScreenCover(isPresented: $showingScanner, onDismiss: {
                barcodeFlow.scannerDismissed()
                if revealFoodAfterScannerDismiss {
                    revealFoodAfterScannerDismiss = false
                    barcodeFlow.lookupSucceeded()
                }
            }) {
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
                #if DEBUG
                applyDebugPresentationIfRequested()
                #endif
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

    private var sheetTitle: String {
        guard case .logging = mode else { return mode.title }
        return "Add to \(mealType.displayName)"
    }

    @ViewBuilder
    private var sheetTitleView: some View {
        if case .logging = mode {
            HStack(spacing: 6) {
                Text("Add to")
                    .foregroundStyle(CalorynTheme.textPrimary)
                Text(mealType.displayName)
                    .foregroundStyle(mealType.ink)
            }
            .font(CalorynTheme.sectionHeaderTitle)
            .lineLimit(1)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
        } else {
            Text(mode.title)
                .font(CalorynTheme.sectionHeaderTitle)
                .foregroundStyle(CalorynTheme.textPrimary)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .accessibilityHidden(true)

                TextField(
                    text: $searchText,
                    prompt: Text("Search foods")
                        .foregroundStyle(CalorynTheme.textSecondary)
                ) {
                    Text("Search foods")
                }
                .font(CalorynTheme.bodyText)
                .foregroundStyle(CalorynTheme.textPrimary)
                .textFieldStyle(.plain)
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
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(CalorynTheme.accent)
                    }
                    .accessibilityLabel("Clear search")
                }
            }
            .foodSearchWell(isFocused: isSearchFocused, height: searchControlHeight)

            Button {
                isSearchFocused = false
                barcodeFlow.scannerOpened()
                showingScanner = true
            } label: {
                Image(systemName: "barcode.viewfinder")
                    .font(CalorynTheme.inlineIcon)
                    .foregroundStyle(CalorynTheme.accent)
                    .frame(width: searchControlHeight, height: searchControlHeight)
            }
            .adaptiveCircleInteractiveGlass(tint: CalorynTheme.backgroundInset, edge: CalorynTheme.separator)
            .accessibilityLabel("Scan a barcode")
        }
        .padding(.horizontal, CalorynTheme.pagePadding)
        .padding(.top, 8)
        .padding(.bottom, 6)
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
                foodSection(title: FoodLogSheetCopy.suggestionsTitle(for: mealType)) {
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
                        mealRow(for: meal)
                    }
                }
            }

            if mode.isSelection, !recipes.isEmpty {
                foodSection(title: "Recipes") {
                    ForEach(recipes) { recipe in
                        recipeRow(for: recipe)
                    }
                }
            }

            if mode.isSelection, !manualEntries.isEmpty {
                foodSection(title: "Your own entries") {
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
        .scrollDismissesKeyboard(.immediately)
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
                        mealRow(for: meal)
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
                foodSection(title: "Your own entries") {
                    ForEach(matchingManualEntries) { food in
                        personalFoodRow(for: food)
                    }
                }
            }

            if hasProductSearchResults {
                foodSection(
                    title: "Search results",
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
                FoodSearchSkeletonRows()
                    .listRowInsets(FoodSearchSkeletonRows.listRowInsets)
                    .listRowSeparator(.hidden, edges: .bottom)
                    .listRowSeparatorTint(CalorynTheme.separator)
                    .calorynClearRowBackground()
            }
        }
        .calorynPlainListStyle()
        .scrollDismissesKeyboard(.immediately)
    }

    @ViewBuilder
    private func foodSection<Rows: View>(
        title: String,
        showsTitle: Bool = true,
        @ViewBuilder rows: () -> Rows
    ) -> some View {
        if mode.usesNonStickySectionTitles {
            if showsTitle {
                nonStickySectionTitle(title)
            }

            rows()
                .calorynHairlineSeparators()
        } else {
            Section {
                rows()
                    .calorynHairlineSeparators()
            } header: {
                if showsTitle {
                    Text(title)
                        .font(CalorynTheme.sectionHeaderTitle)
                        .foregroundStyle(CalorynTheme.textPrimary)
                        .textCase(nil)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(CalorynTheme.backgroundSecondary)
                        .listRowInsets(EdgeInsets())
                        .accessibilityAddTraits(.isHeader)
                }
            }
            .listSectionSeparator(showsTitle ? .visible : .automatic, edges: .top)
            .listSectionSeparatorTint(CalorynTheme.separator)
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
        CalorynHaptics.selectionChanged()
    }

    private func toggle(
        _ id: MultiAddSelectionGroup.ID,
        makeGroup: () throws -> MultiAddSelectionGroup
    ) rethrows {
        try withAnimation(selectionChangeAnimation) {
            try multiAddSelection.toggle(id, makeGroup: makeGroup)
        }
        CalorynHaptics.selectionChanged()
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

    func handleMealSelection(_ meal: MealTemplate) {
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
            .font(CalorynTheme.sectionHeaderTitle)
            .foregroundStyle(CalorynTheme.textPrimary)
            .accessibilityAddTraits(.isHeader)
            .padding(.top, 14)
            .listRowSeparator(.hidden, edges: .top)
            .calorynHairlineSeparators()
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
            CalorynHaptics.success()
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
            if let barcode = barcodeFlow.scannerLookupBarcode {
                BarcodeLookupProgressView(barcode: barcode)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .calorynSheetCanvas()
            } else {
                BarcodeScannerView { code in
                    acceptScannedBarcode(code)
                }
                .ignoresSafeArea()
            }

            Button {
                abandonScanner()
            } label: {
                scannerCloseGlyph
            }
            .accessibilityLabel(
                barcodeFlow.scannerLookupBarcode == nil ? "Close" : "Cancel lookup"
            )
            .padding(.top, 56)
            .padding(.leading, 20)
        }
        .animation(
            accessibilityReduceMotion ? nil : .smooth(duration: 0.28),
            value: barcodeFlow.scannerLookupBarcode
        )
    }

    @ViewBuilder
    private var scannerCloseGlyph: some View {
        if barcodeFlow.scannerLookupBarcode == nil {
            Image(systemName: "xmark")
                .font(CalorynTheme.toolbarIcon)
                // swiftlint:disable:next raw_white_color
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .adaptiveCircleInteractiveGlass()
        } else {
            Image(systemName: "xmark")
                .font(CalorynTheme.toolbarIcon)
                .foregroundStyle(CalorynTheme.accent)
                .frame(width: 40, height: 40)
                .adaptiveCircleInteractiveGlass()
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
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func acceptScannedBarcode(_ code: String) {
        barcodeFlow.scanned(code)
        if !barcodeFlow.isLookingUp {
            showingScanner = false
        }
    }

    private func abandonScanner() {
        revealFoodAfterScannerDismiss = false
        if barcodeFlow.isLookingUp {
            selectedResult = nil
            selectedFoodItem = nil
            barcodeFlow.lookupCancelled()
        }
        showingScanner = false
    }

    private var opensPortionFromScan: Bool {
        if case .logging = mode, !isSelectingMultiple {
            return true
        }
        return false
    }

    private func performBarcodeLookup(_ code: String) async {
        let outcome = await BarcodeLookupRecoveryCoordinator.resolve(
            barcode: code,
            localFoods: recentFoods,
            providerLookup: searchService.lookupBarcode
        )
        guard !Task.isCancelled else { return }
        guard barcodeFlow.pendingBarcode == code else { return }

        switch outcome {
        case .remote(let result):
            if opensPortionFromScan {
                stageResolvedBarcode { selectedResult = result }
                await revealStagedBarcodeFood()
            } else {
                barcodeFlow.lookupSucceeded()
                showingScanner = false
                handleProductSelection(result)
            }
        case .local(let food, _):
            try? modelContext.save()
            if opensPortionFromScan {
                stageResolvedBarcode {
                    selectedFoodItem = PortionDestination(food: food)
                }
                await revealStagedBarcodeFood()
            } else {
                barcodeFlow.lookupSucceeded()
                showingScanner = false
                handleFoodItemSelection(food)
            }
        case .failure(let error):
            guard let feedback = barcodeFlow.lookupFailed(error) else { return }
            showingScanner = false
            triggerBarcodeLookupHaptic(feedback)
        }
    }

    private func stageResolvedBarcode(_ stage: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            stage()
        }
    }

    private func revealStagedBarcodeFood() async {
        guard showingScanner else {
            barcodeFlow.lookupSucceeded()
            return
        }
        // The portion has to commit under the cover before the cover leaves,
        // or the search sheet flashes in the gap.
        await Task.yield()
        guard showingScanner, barcodeFlow.pendingBarcode != nil else { return }
        revealFoodAfterScannerDismiss = true
        showingScanner = false
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
        switch feedback {
        case .warning:
            CalorynHaptics.warning()
        case .error:
            CalorynHaptics.error()
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

    #if DEBUG
    private func applyDebugPresentationIfRequested() {
        guard case .logging = mode,
              let request = FoodLogDebugPresentation.takeRequest() else { return }
        let foods = FoodLogDebugPresentation.seedDemoFoods(into: modelContext)

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            hasCapturedSuggestions = false
            captureSuggestionsIfNeeded()
            isSearchFocused = false
            switch request {
            case .addFood:
                break
            case .portion:
                selectedFoodItem = PortionDestination(food: foods.skyr, suggestedPortionGrams: 160)
            case .portionServing:
                selectedFoodItem = PortionDestination(food: foods.rugbrod)
            case .select, .multiAdd:
                isSelectingMultiple = true
                toggleFoodSelection(foods.skyr)
                toggleFoodSelection(foods.rugbrod)
                if request == .multiAdd {
                    multiAddPresentation = MultiAddPresentation(groups: multiAddSelection.groups)
                }
            }
        }
    }
    #endif
}

private struct BarcodeLookupProgressView: View {
    var barcode: String?

    @ScaledMetric(relativeTo: .largeTitle) private var symbolSize: CGFloat = 52

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 24)

            Image(systemName: "barcode.viewfinder")
                .font(.system(size: symbolSize, weight: .light))
                .foregroundStyle(CalorynTheme.accent)
                .accessibilityHidden(true)

            ProgressView()
                .controlSize(.large)
                .tint(CalorynTheme.accent)
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text("Looking up this food")
                    .font(CalorynTheme.sectionHeaderTitle)
                    .foregroundStyle(CalorynTheme.textPrimary)
                Text("Checking your foods and the catalog.")
                    .font(CalorynTheme.bodyText)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .multilineTextAlignment(.center)
                if let barcode, !barcode.isEmpty {
                    Text("Barcode \(barcode)")
                        .font(CalorynTheme.numericCaption)
                        .foregroundStyle(CalorynTheme.textSecondary)
                        .textSelection(.enabled)
                }
            }
            .padding(.horizontal, CalorynTheme.pagePadding)

            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier("barcodeLookup.progress")
    }

    private var accessibilityLabel: String {
        if let barcode, !barcode.isEmpty {
            return "Looking up this food. Barcode \(barcode). Checking your foods and the catalog."
        }
        return "Looking up this food. Checking your foods and the catalog."
    }
}

private struct FoodLookupFailureView: View {
    let presentation: FoodLookupFailurePresentation
    let onRetry: () -> Void

    var body: some View {
        ContentUnavailableView {
            FoodLookupFailureLabel(presentation: presentation)
        } description: {
            Text(presentation.message)
                .foregroundStyle(CalorynTheme.textSecondary)
        } actions: {
            if let retryTitle = presentation.retryTitle {
                Button(retryTitle, action: onRetry)
                    .adaptiveGlassProminentButton()
                    .controlSize(.large)
            }
        }
    }
}

private struct FoodLookupFailureLabel: View {
    let presentation: FoodLookupFailurePresentation

    var body: some View {
        Label {
            Text(presentation.title)
                .foregroundStyle(CalorynTheme.textPrimary)
        } icon: {
            Image(systemName: presentation.systemImage)
                .foregroundStyle(CalorynTheme.textSecondary)
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
            FoodLookupFailureLabel(presentation: presentation)
        } description: {
            VStack(spacing: 6) {
                Text(presentation.message)
                    .foregroundStyle(CalorynTheme.textSecondary)
                if offersManualCreation, let normalizedBarcode {
                    Text("Barcode \(normalizedBarcode)")
                        .font(CalorynTheme.numericCaption)
                        .foregroundStyle(CalorynTheme.textSecondary)
                        .textSelection(.enabled)
                }
            }
        } actions: {
            VStack(spacing: 10) {
                if offersManualCreation, normalizedBarcode != nil {
                    Button("Create manual food", action: onCreateManually)
                        .adaptiveGlassProminentButton()
                        .controlSize(.large)
                        .accessibilityHint("Opens a private food with this barcode already filled in")
                }

                if let retryTitle = presentation.retryTitle {
                    Button(retryTitle, action: onRetry)
                        .buttonStyle(.bordered)
                        .tint(CalorynTheme.accent)
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
