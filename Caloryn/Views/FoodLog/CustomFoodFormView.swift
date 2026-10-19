import SwiftUI
import SwiftData

struct CustomFoodFormView: View {
    var existingFood: FoodItem?
    var onSaved: ((FoodItem) -> Void)?
    var allowsDeletion: Bool
    var showsFavoriteControl: Bool
    let prefilledBarcode: String?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(sort: \FoodItem.lastUsed, order: .reverse) private var savedFoods: [FoodItem]

    @State private var draft = CustomFoodDraft()
    @State private var showingDeleteConfirmation = false
    @State private var favoriteErrorMessage: String?

    @FocusState private var focusedField: Field?

    private typealias Field = CustomFoodDraft.Field

    private var isEditing: Bool { existingFood != nil }
    private var recoveryBarcode: String? {
        existingFood?.normalizedBarcode ?? BarcodeIdentity.normalized(prefilledBarcode)
    }

    private var canSave: Bool { draft.canSave }
    private var previewCalories: Double { draft.previewCalories }

    init(
        existingFood: FoodItem? = nil,
        prefilledBarcode: String? = nil,
        onSaved: ((FoodItem) -> Void)? = nil,
        allowsDeletion: Bool = true,
        showsFavoriteControl: Bool = true
    ) {
        self.existingFood = existingFood
        self.prefilledBarcode = BarcodeIdentity.normalized(prefilledBarcode)
        self.onSaved = onSaved
        self.allowsDeletion = allowsDeletion
        self.showsFavoriteControl = showsFavoriteControl
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    nameSection

                    produceTrackingSection

                    caloriePreview

                    nutritionSection

                    optionalNutritionSection

                    servingSizeSection

                    if isEditing && allowsDeletion {
                        deleteSection
                    }
                }
                .padding(.horizontal, CalorynTheme.pagePadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .calorynSheetCanvas()
            .calorynInlineTitle(formTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    CreationFormCloseButton {
                        dismiss()
                    }
                }
                if showsFavoriteControl,
                   let existingFood,
                   existingFood.isManualEntryOrRecipe {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            toggleFavorite(existingFood)
                        } label: {
                            CreationFormFavoriteGlyph(isFavorite: existingFood.isFavorite)
                        }
                        .accessibilityLabel(
                            existingFood.isFavorite
                                ? "Remove \(existingFood.name) from favorites"
                                : "Add \(existingFood.name) to favorites"
                        )
                    }

                    if #available(iOS 26.0, *) {
                        ToolbarSpacer(.fixed, placement: .topBarTrailing)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        saveFood()
                    } label: {
                        CreationFormSaveGlyph(isEnabled: canSave)
                    }
                    .accessibilityLabel("Save")
                    .accessibilityIdentifier("customFood.save")
                    .disabled(!canSave)
                }
            }
            .onAppear(perform: populateFromExisting)
            .confirmationDialog("Delete Manual Entry", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive, action: deleteFood)
            } message: {
                Text("This will permanently remove \"\(draft.name)\" from your manual entries.")
            }
            .alert("Couldn’t Update Favorite", isPresented: favoriteErrorIsPresented) {
                Button("OK", role: .cancel) {
                    favoriteErrorMessage = nil
                }
            } message: {
                Text(favoriteErrorMessage ?? "Please try again.")
            }
        }
        .presentationDetents([.large])
    }

    private var nameSection: some View {
        CreationFormSection("Food details") {
            VStack(alignment: .leading, spacing: 10) {
                TextField("Food name (e.g. Nick's Pizza)", text: $draft.name)
                    .font(CalorynTheme.bodyText)
                    .textInputAutocapitalization(.words)
                    .focused($focusedField, equals: .name)
                    .calorynInputField(isFocused: focusedField == .name)
                    .accessibilityIdentifier("customFood.name")

                TextField("Brand (optional)", text: $draft.brand)
                    .font(CalorynTheme.bodyText)
                    .textInputAutocapitalization(.words)
                    .focused($focusedField, equals: .brand)
                    .calorynInputField(isFocused: focusedField == .brand)
            }

            if let recoveryBarcode {
                CreationFormSheetRow {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Barcode")
                                .font(CreationFormTypography.rowLabel)
                                .foregroundStyle(CalorynTheme.textPrimary)

                            barcodeValue(recoveryBarcode)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        LabeledContent {
                            barcodeValue(recoveryBarcode)
                        } label: {
                            Text("Barcode")
                                .font(CreationFormTypography.rowLabel)
                                .foregroundStyle(CalorynTheme.textPrimary)
                        }
                    }
                }
                .padding(.top, 14)
            }
        }
    }

    private func barcodeValue(_ barcode: String) -> some View {
        Text(barcode)
            .font(CalorynTheme.numericBody)
            .foregroundStyle(CalorynTheme.textSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .textSelection(.enabled)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Barcode \(barcode)")
    }

    private var produceTrackingSection: some View {
        CreationFormSection("Fruit and veg variety") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Count as")
                    .font(CreationFormTypography.rowLabel)
                    .foregroundStyle(CalorynTheme.textPrimary)

                WrappingChipFlow {
                    ForEach(ProduceKind.manualCases) { kind in
                        Button {
                            withAnimation(.smooth(duration: 0.2)) {
                                draft.produceKind = kind
                            }
                        } label: {
                            Text(kind.displayName)
                                .calorynChip(isSelected: draft.produceKind == kind)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Count as \(kind.fullDisplayName)")
                        .accessibilityAddTraits(draft.produceKind == kind ? .isSelected : [])
                    }
                }
            }
        }
    }

    private var caloriePreview: some View {
        CreationFormTotal(
            kcal: previewCalories.truncatedSafely,
            caption: "kcal per serving"
        )
    }

    private var nutritionSection: some View {
        CreationFormSection("Nutrition per serving") {
            nutritionField(
                label: "Calories",
                text: $draft.caloriesPerServing,
                unit: "kcal",
                focus: .calories,
                required: true,
                identifier: "customFood.calories"
            )
            nutritionField(
                label: "Protein",
                text: $draft.proteinPerServing,
                unit: "g",
                focus: .protein
            )
            nutritionField(
                label: "Carbs",
                text: $draft.carbsPerServing,
                unit: "g",
                focus: .carbs
            )
            nutritionField(
                label: "Fat",
                text: $draft.fatPerServing,
                unit: "g",
                focus: .fat
            )
        }
    }

    private var optionalNutritionSection: some View {
        CreationFormSection("Optional, per serving", footer: "Leave unknown values blank.") {
            nutritionField(
                label: "Fiber",
                text: $draft.fiberPerServing,
                unit: "g",
                focus: .fiber,
                placeholder: ""
            )
            nutritionField(
                label: "Sugars",
                text: $draft.sugarsPerServing,
                unit: "g",
                focus: .sugars,
                placeholder: ""
            )
            nutritionField(
                label: "Added sugar",
                text: $draft.addedSugarsPerServing,
                unit: "g",
                focus: .addedSugars,
                placeholder: ""
            )
            nutritionField(
                label: "Saturated fat",
                text: $draft.saturatedFatPerServing,
                unit: "g",
                focus: .saturatedFat,
                placeholder: ""
            )
            nutritionField(
                label: "Sodium",
                text: $draft.sodiumPerServing,
                unit: "mg",
                focus: .sodium,
                placeholder: ""
            )
            nutritionField(
                label: "Cholesterol",
                text: $draft.cholesterolPerServing,
                unit: "mg",
                focus: .cholesterol,
                placeholder: ""
            )
            nutritionField(
                label: "Alcohol",
                text: $draft.alcoholPerServing,
                unit: "g",
                focus: .alcohol,
                placeholder: ""
            )
        }
    }

    private func nutritionField(
        label: String,
        text: Binding<String>,
        unit: String,
        focus: Field,
        required: Bool = false,
        placeholder: String = "0",
        identifier: String? = nil
    ) -> some View {
        CreationFormSheetRow {
            fieldRow(labelWidth: 112) {
                HStack(spacing: 3) {
                    Text(label)
                        .font(CreationFormTypography.rowLabel)
                        .foregroundStyle(CalorynTheme.textPrimary)
                    if required {
                        Text("*")
                            .font(CreationFormTypography.rowLabel.weight(.semibold))
                            .foregroundStyle(CalorynTheme.textSecondary)
                            .accessibilityLabel("required")
                    }
                }
            } field: {
                TextField(placeholder, text: text)
                    .font(CalorynTheme.numericBody)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: focus)
                    .calorynInputField(isFocused: focusedField == focus)
                    // On the field itself, not the row: an identifier on the row
                    // resolves to the label, which a test can see but not type in.
                    .accessibilityIdentifier(ifPresent: identifier)
            } unit: {
                Text(unit)
            }
        }
    }

    private var servingSizeSection: some View {
        CreationFormSection(
            "Serving size",
            footer: "The nutrition values above are for one serving of this size."
        ) {
            CreationFormSheetRow {
                fieldRow(fieldWidth: 88) {
                    Text("One serving")
                        .font(CreationFormTypography.rowLabel)
                        .foregroundStyle(CalorynTheme.textPrimary)
                } field: {
                    TextField("100", text: $draft.servingSizeGrams)
                        .font(CalorynTheme.numericBody)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .servingSize)
                        .calorynInputField(isFocused: focusedField == .servingSize)
                        .accessibilityIdentifier("customFood.servingSize")
                } unit: {
                    Text("g")
                }
            }
        }
    }

    @ViewBuilder
    private func fieldRow<Label: View, FieldView: View, Unit: View>(
        labelWidth: CGFloat? = nil,
        fieldWidth: CGFloat? = nil,
        @ViewBuilder label: () -> Label,
        @ViewBuilder field: () -> FieldView,
        @ViewBuilder unit: () -> Unit
    ) -> some View {
        let unitText = unit()
            .font(CreationFormTypography.detail)
            .foregroundStyle(CalorynTheme.textSecondary)

        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 6) {
                label()
                HStack(spacing: 10) {
                    field()
                    unitText
                        .fixedSize()
                }
            }
        } else {
            HStack(spacing: 10) {
                if let labelWidth {
                    label()
                        .frame(width: labelWidth, alignment: .leading)
                } else {
                    label()
                    Spacer()
                }

                field()
                    .frame(width: fieldWidth)

                unitText
                    .frame(width: 32, alignment: .leading)
            }
        }
    }

    private var deleteSection: some View {
        CreationFormDeleteButton("Delete manual entry") {
            showingDeleteConfirmation = true
        }
    }

    private func populateFromExisting() {
        guard let food = existingFood else {
            focusedField = .name
            return
        }
        draft.populate(from: food)
    }

    private func saveFood() {
        let serving = draft.effectiveServingGrams
        let nutritionPer100g = draft.nutritionPer100g

        if let recoveryBarcode {
            let materialization = BarcodeRecoveryService.materializePersonalFood(
                barcode: recoveryBarcode,
                edit: draft.personalEdit(isEditingExistingFood: existingFood != nil),
                localFoods: savedFoods,
                editing: existingFood
            )
            if !savedFoods.contains(where: { $0 === materialization.food }) {
                modelContext.insert(materialization.food)
            }
            do {
                try modelContext.save()
                if existingFood != nil {
                    CalorynAppShortcutRefresh.favoriteWasEdited(
                        isFavorite: materialization.food.isFavorite
                    )
                }
            } catch {
            }
            BarcodeRecoveryAnalytics.record(
                path: existingFood == nil ? .manualCreation : .personalEdit,
                result: existingFood != nil
                    ? .completed
                    : (materialization.isNew ? .completed : .reused)
            )
            CalorynHaptics.success()
            onSaved?(materialization.food)
            dismiss()
            return
        }

        if let food = existingFood {
            food.name = draft.trimmedName
            food.brand = draft.trimmedBrand
            food.applyUserNutritionEdit(
                nutritionPer100g,
                suppliedProtein: draft.suppliedProtein,
                suppliedCarbohydrates: draft.suppliedCarbohydrates,
                suppliedFat: draft.suppliedFat
            )
            food.defaultServingG = serving
            food.servingDescription = nil
            food.categoryTags = []
            food.produceKind = draft.produceKind
            do {
                try modelContext.save()
                CalorynAppShortcutRefresh.favoriteWasEdited(
                    isFavorite: food.isFavorite
                )
            } catch {
            }
            onSaved?(food)
        } else {
            let food = FoodItem(
                name: draft.trimmedName,
                brand: draft.trimmedBrand,
                caloriesPer100g: nutritionPer100g.calories,
                proteinPer100g: nutritionPer100g.proteinG,
                carbsPer100g: nutritionPer100g.carbsG,
                fatPer100g: nutritionPer100g.fatG,
                fiberPer100g: nutritionPer100g.fiberG,
                sugarsPer100g: nutritionPer100g.sugarsG,
                addedSugarsPer100g: nutritionPer100g.addedSugarsG,
                saturatedFatPer100g: nutritionPer100g.saturatedFatG,
                sodiumPer100g: nutritionPer100g.sodiumG,
                cholesterolPer100g: nutritionPer100g.cholesterolG,
                alcoholPer100g: nutritionPer100g.alcoholG,
                defaultServingG: serving,
                produceKind: draft.produceKind,
                isCustom: true
            )
            food.applyUserNutritionEdit(
                nutritionPer100g,
                suppliedProtein: draft.suppliedProtein,
                suppliedCarbohydrates: draft.suppliedCarbohydrates,
                suppliedFat: draft.suppliedFat
            )
            modelContext.insert(food)
            try? modelContext.save()
            onSaved?(food)
        }
        CalorynHaptics.success()
        dismiss()
    }

    private var formTitle: String {
        if isEditing {
            return existingFood?.isCatalogProduct == true
                ? "Edit product"
                : "Edit manual entry"
        }
        return recoveryBarcode != nil ? "Create manual food" : "Create manual entry"
    }

    private func deleteFood() {
        if let food = existingFood {
            food.deletePreservingLogEntrySnapshots(from: modelContext)
            do {
                try modelContext.save()
                CalorynAppShortcutRefresh.favoritesChanged()
            } catch {
            }
        }
        dismiss()
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
}

private extension View {
    /// Applies an identifier only when there is one, so the fields that do not
    /// need naming keep the identifier they would have had rather than an
    /// explicit empty one.
    @ViewBuilder
    func accessibilityIdentifier(ifPresent identifier: String?) -> some View {
        if let identifier {
            accessibilityIdentifier(identifier)
        } else {
            self
        }
    }
}

#Preview {
    CustomFoodFormView()
        .modelContainer(
            for: [UserProfile.self, FoodItem.self, FoodLogEntry.self, RecipeIngredient.self],
            inMemory: true
        )
}
