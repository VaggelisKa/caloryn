import SwiftUI
import SwiftData

struct PortionPickerView: View {
    let foodItem: FoodItem
    let mealType: MealType
    let logDate: Date
    let isNewFood: Bool
    let snackIndex: Int
    let existingEntry: FoodLogEntry?
    let suggestedPortionGrams: Double?
    var onLogged: (() -> Void)?
    var onDeleted: ((FoodLogEntry) -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selection: PortionSelection
    @State private var selectedMeal: MealType
    @State private var showingDeleteConfirmation = false
    @State private var showingFoodEditor = false
    @State private var hasPersistedPersonalFood = false
    @State private var replacementFoodItem: FoodItem?

    @FocusState private var isGramsFieldFocused: Bool

    private typealias PortionMode = PortionSelection.Mode

    init(
        foodItem: FoodItem,
        mealType: MealType,
        logDate: Date,
        isNewFood: Bool,
        snackIndex: Int = 0,
        existingEntry: FoodLogEntry? = nil,
        suggestedPortionGrams: Double? = nil,
        onLogged: (() -> Void)? = nil,
        onDeleted: ((FoodLogEntry) -> Void)? = nil
    ) {
        self.foodItem = foodItem
        self.mealType = mealType
        self.logDate = logDate
        self.isNewFood = isNewFood
        self.snackIndex = snackIndex
        self.existingEntry = existingEntry
        self.suggestedPortionGrams = suggestedPortionGrams
        self.onLogged = onLogged
        self.onDeleted = onDeleted
        self._selectedMeal = State(initialValue: existingEntry?.mealType ?? mealType)

        self._selection = State(
            initialValue: PortionSelection.opening(
                shape: PortionSelection.Shape(foodItem: foodItem),
                existingEntryGrams: existingEntry?.portionGrams,
                suggestedGrams: suggestedPortionGrams,
                defaultServingGrams: foodItem.defaultServingG
            )
        )
    }

    private var portionGrams: Double { selection.portionGrams }

    private var previewNutrition: NutritionValues {
        activeFoodItem.nutrition(forGrams: portionGrams)
    }

    private var previewCalories: Double { previewNutrition.calories }
    private var isEditing: Bool { existingEntry != nil }
    private var saveButtonTitle: String {
        FoodLogSheetCopy.portionSaveTitle(isEditing: isEditing, meal: selectedMeal)
    }

    private var activeFoodItem: FoodItem {
        replacementFoodItem ?? foodItem
    }

    private var nutritionDetails: [DetailNutrient] {
        PortionNutrientBreakdown(nutrition: previewNutrition).items
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                foodHeader

                if activeFoodItem.provenance.warrantsNutritionNotice {
                    nutritionCompletenessNote
                }

                caloriePreview

                portionPicker

                mealSelector

                nutritionPreview
            }
            .padding(.horizontal, CalorynTheme.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .dismissesGramKeypadOnTap($isGramsFieldFocused)
        }
        .scrollDismissesKeyboard(.immediately)
        .calorynSheetCanvas()
        .navigationTitle(isEditing ? "Edit portion" : "Portion")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(!isEditing)
        .toolbar {
            ToolbarItem(placement: .principal) {
                FoodLogSheetTitle(title: isEditing ? "Edit portion" : "Portion")
            }

            if isEditing {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(CalorynTheme.toolbarIcon)
                            .foregroundStyle(CalorynTheme.textPrimary)
                    }
                    .accessibilityLabel("Close")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                            .font(CalorynTheme.toolbarIcon)
                            .foregroundStyle(CalorynTheme.textPrimary)
                    }
                    .accessibilityLabel("Delete Log Entry")
                    .accessibilityIdentifier("portionPicker.delete")
                }
            } else {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(CalorynTheme.toolbarIcon)
                            .foregroundStyle(CalorynTheme.textPrimary)
                    }
                    .accessibilityLabel("Back")
                    .accessibilityIdentifier("portionPicker.back")
                }
            }

            if !isEditing,
               !activeFoodItem.isRecipe,
               activeFoodItem.normalizedBarcode != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        BarcodeRecoveryAnalytics.record(path: .personalEdit, result: .started)
                        showingFoodEditor = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(CalorynTheme.toolbarIcon)
                            .foregroundStyle(CalorynTheme.textPrimary)
                    }
                    .accessibilityLabel("Edit Food Details")
                    .accessibilityHint("Creates or updates your private version of this barcode")
                }
            }
        }
        .foodLogBottomAction {
            Button(action: savePortion) {
                Text(saveButtonTitle)
                    .contentTransition(.opacity)
                    .animation(.smooth(duration: 0.2), value: saveButtonTitle)
            }
            .calorynPrimaryButton(meal: isEditing ? nil : selectedMeal)
            .animation(.smooth(duration: 0.2), value: selectedMeal)
            .accessibilityIdentifier("portionPicker.save")
        }
        .confirmationDialog("Delete Log Entry", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive, action: deleteEntry)
        } message: {
            Text("Remove \(activeFoodItem.name) from your log?")
        }
        .sheet(isPresented: $showingFoodEditor) {
            CustomFoodFormView(
                existingFood: activeFoodItem,
                onSaved: { savedFood in
                    replacementFoodItem = savedFood
                    selection.update(shape: PortionSelection.Shape(foodItem: savedFood))
                    hasPersistedPersonalFood = true
                    showingFoodEditor = false
                },
                allowsDeletion: false,
                showsFavoriteControl: false
            )
        }
    }

    private var foodHeader: some View {
        FoodLogSheetHeader(
            name: activeFoodItem.name,
            nutriscoreGrade: activeFoodItem.nutriscoreGrade,
            lines: [
                FoodLogSheetCopy.portionDetail(
                    brand: activeFoodItem.brand,
                    servingDescription: activeFoodItem.servingDescription,
                    isRecipe: activeFoodItem.isRecipe,
                    caloriesPer100g: activeFoodItem.caloriesPer100g
                )
            ]
        )
    }

    private var caloriePreview: some View {
        FoodLogCaloriePreview(
            calories: previewCalories.rounded().truncatedSafely,
            tint: selectedMeal.ink,
            detail: "\(previewNutrition.proteinG.spacedMacroFormatted) protein",
            identifier: "portionPicker.calories"
        )
        .animation(.smooth(duration: 0.2), value: selectedMeal)
    }

    private var nutritionCompletenessNote: some View {
        let provenance = activeFoodItem.provenance

        return VStack(alignment: .leading, spacing: 8) {
            if provenance.completeness == .partial {
                Label {
                    Text("Some nutrition values were not provided. Check the package and edit your private food if needed.")
                        .foregroundStyle(CalorynTheme.textPrimary)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(CalorynTheme.textPrimary)
                }
            } else if provenance.completeness == .unknown {
                Label {
                    Text("This food's nutrition may be incomplete. Check the package and edit your private food if needed.")
                        .foregroundStyle(CalorynTheme.textSecondary)
                } icon: {
                    Image(systemName: "questionmark.circle")
                        .foregroundStyle(CalorynTheme.textSecondary)
                }
            }

            if activeFoodItem.normalizedBarcode != nil {
                Button {
                    BarcodeRecoveryAnalytics.record(path: .personalEdit, result: .started)
                    showingFoodEditor = true
                } label: {
                    Text("Edit food details")
                        .fontWeight(.semibold)
                        .foregroundStyle(CalorynTheme.textPrimary)
                        .underline()
                }
                .buttonStyle(.plain)
                .accessibilityHint("Creates or updates your private version without changing the provider record")
            }
        }
        .font(CalorynTypeface.text(.footnote))
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .calorynGroupSurface()
        .accessibilityElement(children: .combine)
    }

    private var maxServingCount: Int { selection.maxServingCount }

    private var unitOptions: [UnitOption] {
        if activeFoodItem.isRecipe {
            return [UnitOption(label: "grams", mode: .grams), UnitOption(label: "serving", mode: .recipeServing)]
        }
        if let info = activeFoodItem.servingInfo {
            return [UnitOption(label: "grams", mode: .grams), UnitOption(label: info.unitName, mode: .serving)]
        }
        return []
    }

    private struct UnitOption: Hashable {
        let label: String
        let mode: PortionMode
    }

    private var portionPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 8) {
                    FoodLogSectionTitle("How much")

                    Spacer(minLength: 8)

                    if !unitOptions.isEmpty {
                        unitChips
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    FoodLogSectionTitle("How much")

                    if !unitOptions.isEmpty {
                        unitChips
                    }
                }
            }

            Group {
                switch selection.mode {
                case .grams:
                    GramAmountField(
                        text: $selection.gramsInput,
                        quickOptions: selection.quickGramOptions,
                        identifierPrefix: "portionPicker",
                        isFocused: $isGramsFieldFocused,
                        onTextChange: { selection.gramsInputChanged() },
                        onCommit: { selection.commitGramsInput() },
                        onQuickOption: { selection.quickGramOptionChosen($0) },
                        onStep: { selection.gramsStepped($0) },
                        quickOptionLabel: { grams in
                            PortionSelection.quickGramOptionLabel(
                                grams,
                                serving: activeFoodItem.isRecipe ? nil : activeFoodItem.servingInfo
                            )
                        }
                    )
                case .serving:
                    servingStepper
                case .recipeServing:
                    recipeServingStepper
                }
            }
            .id(selection.mode)
            .transition(
                .asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.92))
                        .animation(.easeOut(duration: 0.28).delay(0.12)),
                    removal: .opacity.animation(.easeIn(duration: 0.12))
                )
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.easeInOut(duration: 0.28), value: selection.mode)
        }
        .onChange(of: selection.servingCount) { selection.servingCountChanged() }
        .onChange(of: selection.recipeServingID) { selection.recipeServingChanged() }
        .onChange(of: selection.mode) { selection.modeChanged() }
    }

    private var servingStepper: some View {
        let count = selection.servingCount
        let info = activeFoodItem.servingInfo
        return CalorynStepperPill(
            accessibilityTitle: "Count",
            value: "\(count)",
            unit: info.map { count == 1 ? $0.unitName : $0.pluralName },
            canDecrement: count > 1,
            canIncrement: count < maxServingCount,
            onDecrement: { selection.servingCount = max(1, count - 1) },
            onIncrement: { selection.servingCount = min(maxServingCount, count + 1) }
        )
        .accessibilityIdentifier("portionPicker.servingCount")
    }

    private var recipeServingStepper: some View {
        let options = PortionSelection.recipeServingOptions
        let index = options.firstIndex { $0.id == selection.recipeServingID } ?? 0
        let count = options[index].multiplier
        return CalorynStepperPill(
            accessibilityTitle: "Recipe serving",
            value: options[index].label,
            unit: count > 1 ? "servings" : "serving",
            canDecrement: index > 0,
            canIncrement: index < options.count - 1,
            onDecrement: { selection.recipeServingID = options[max(0, index - 1)].id },
            onIncrement: { selection.recipeServingID = options[min(options.count - 1, index + 1)].id }
        )
        .accessibilityIdentifier("portionPicker.recipeServing")
    }

    private var unitChips: some View {
        HStack(spacing: 6) {
            ForEach(unitOptions, id: \.mode) { option in
                Button {
                    selection.mode = option.mode
                } label: {
                    Text(option.label)
                        .calorynChip(isSelected: selection.mode == option.mode)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection.mode == option.mode ? .isSelected : [])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Unit")
    }

    private var nutritionPreview: some View {
        VStack(alignment: .leading, spacing: 6) {
            FoodLogSectionTitle("In this portion")

            FoodLogValueRows(
                rows: nutritionDetails.map { nutrient in
                    FoodLogValueRows.Row(
                        id: nutrient.id,
                        label: nutrient.label,
                        value: nutrient.spacedFormattedValue
                    )
                }
            )
        }
    }

    private var mealSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            FoodLogSectionTitle("Which meal")

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    ForEach(MealType.allCases) { meal in
                        mealChip(meal)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach(MealType.allCases.prefix(2)) { meal in
                            mealChip(meal)
                        }
                    }
                    HStack(spacing: 8) {
                        ForEach(MealType.allCases.dropFirst(2)) { meal in
                            mealChip(meal)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(MealType.allCases) { meal in
                        mealChip(meal)
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Meal")
        }
    }

    private func mealChip(_ meal: MealType) -> some View {
        Button {
            selectedMeal = meal
        } label: {
            Text(meal.displayName)
                .fixedSize()
                .frame(maxWidth: .infinity)
                .calorynChip(isSelected: selectedMeal == meal, meal: meal)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selectedMeal == meal ? .isSelected : [])
    }

    private func savePortion() {
        selection.commitGramsInput()

        if let existingEntry {
            DailyFoodLogCommands.updateLoggedEntry(
                existingEntry,
                date: logDate,
                mealType: selectedMeal,
                foodItem: activeFoodItem,
                portionGrams: portionGrams,
                snackIndex: snackIndex
            )
            try? modelContext.save()
        } else {
            DailyFoodLogCommands.logFood(
                foodItem: activeFoodItem,
                portionGrams: portionGrams,
                mealType: selectedMeal,
                logDate: logDate,
                isNewFood: isNewFood && !hasPersistedPersonalFood,
                modelContext: modelContext,
                snackIndex: snackIndex
            )
            try? modelContext.save()
        }
        if let onLogged {
            onLogged()
        } else {
            dismiss()
        }
    }

    private func deleteEntry() {
        guard let existingEntry else { return }
        if let onDeleted {
            onDeleted(existingEntry)
        } else {
            DailyFoodLogCommands.deleteLoggedEntry(
                existingEntry,
                modelContext: modelContext
            )
            try? modelContext.save()
        }
        dismiss()
    }
}

#Preview("Cup serving") {
    let food = FoodItem(
        name: "Skyr",
        brand: "Arla",
        caloriesPer100g: 63,
        proteinPer100g: 11,
        carbsPer100g: 4,
        fatPer100g: 0,
        fiberPer100g: 0,
        sugarsPer100g: 3.7,
        sodiumPer100g: 0.05,
        defaultServingG: 170,
        servingDescription: "1 cup (170g)"
    )
    return NavigationStack {
        PortionPickerView(
            foodItem: food,
            mealType: .lunch,
            logDate: .now,
            isNewFood: true
        )
    }
    .modelContainer(for: [UserProfile.self, FoodItem.self, FoodLogEntry.self, RecipeIngredient.self], inMemory: true)
}

#Preview("Slice serving") {
    let food = FoodItem(
        name: "Rugbroed",
        brand: "Schulstad",
        caloriesPer100g: 210,
        proteinPer100g: 7,
        carbsPer100g: 36,
        fatPer100g: 2,
        defaultServingG: 45,
        servingDescription: "1 slice (45g)"
    )
    return PortionPickerView(
        foodItem: food,
        mealType: .lunch,
        logDate: .now,
        isNewFood: true
    )
    .modelContainer(for: [UserProfile.self, FoodItem.self, FoodLogEntry.self, RecipeIngredient.self], inMemory: true)
}

#Preview("No serving info") {
    let food = FoodItem(
        name: "Olive Oil",
        brand: "Filippo Berio",
        caloriesPer100g: 884,
        proteinPer100g: 0,
        carbsPer100g: 0,
        fatPer100g: 100
    )
    return PortionPickerView(
        foodItem: food,
        mealType: .dinner,
        logDate: .now,
        isNewFood: true
    )
    .modelContainer(for: [UserProfile.self, FoodItem.self, FoodLogEntry.self, RecipeIngredient.self], inMemory: true)
}
