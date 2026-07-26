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

    /// Every rule this form applies lives in the draft; the view reads it and
    /// renders. See `CustomFoodDraft`.
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
    private var previewProtein: Double { draft.previewProtein }
    private var previewCarbs: Double { draft.previewCarbs }
    private var previewFat: Double { draft.previewFat }

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
                VStack(spacing: 24) {
                    nameSection

                    produceTrackingSection

                    caloriePreviewCard

                    nutritionSection

                    optionalNutritionSection

                    servingSizeSection

                    if isEditing && allowsDeletion {
                        deleteSection
                    }
                }
                .padding(.horizontal, CalorynTheme.pagePadding)
                .padding(.bottom, 24)
            }
            .calorynSheetCanvas()
            .navigationTitle(formTitle)
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
                if showsFavoriteControl,
                   let existingFood,
                   existingFood.isManualEntryOrRecipe {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            toggleFavorite(existingFood)
                        } label: {
                            Image(systemName: existingFood.isFavorite ? "star.fill" : "star")
                                .font(CalorynTheme.toolbarIcon)
                                .foregroundStyle(
                                    existingFood.isFavorite
                                        ? CalorynTheme.terracotta
                                        : CalorynTheme.sage
                                )
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
                        Image(systemName: "checkmark")
                            .font(CalorynTheme.toolbarIcon)
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
        VStack(alignment: .leading, spacing: 12) {
            Text("FOOD DETAILS")
                .font(CalorynTheme.sectionEyebrow)
                .foregroundStyle(CalorynTheme.textSecondary)

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

            if let recoveryBarcode {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Barcode")
                            .font(CalorynTheme.bodyText)

                        barcodeValue(recoveryBarcode)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    LabeledContent("Barcode") {
                        barcodeValue(recoveryBarcode)
                    }
                }
            }
        }
        .glassCard(cornerRadius: CalorynTheme.smallCornerRadius)
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
        VStack(alignment: .leading, spacing: 12) {
            Text("FRUIT & VEG VARIETY")
                .font(CalorynTheme.sectionEyebrow)
                .foregroundStyle(CalorynTheme.textSecondary)

            HStack {
                Text("Count as")
                    .font(CalorynTheme.bodyText)
                    .foregroundStyle(CalorynTheme.textPrimary)

                Spacer()
            }

            Picker("Count as", selection: $draft.produceKind) {
                ForEach(ProduceKind.manualCases) { kind in
                    Text(kind.displayName)
                        .tag(kind)
                }
            }
            .pickerStyle(.segmented)
        }
        .glassCard(cornerRadius: CalorynTheme.smallCornerRadius)
    }

    private var caloriePreviewCard: some View {
        VStack(spacing: 4) {
            Text("\(Int(previewCalories))")
                .font(CalorynTheme.displayNumber)
                .foregroundStyle(CalorynTheme.sage)
                .contentTransition(.numericText())
                .animation(.smooth(duration: 0.3), value: Int(previewCalories))

            Text("calories per serving")
                .font(CalorynTheme.bodyText)
                .foregroundStyle(CalorynTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .glassCard()
    }

    private var nutritionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("NUTRITION PER SERVING")
                .font(CalorynTheme.sectionEyebrow)
                .foregroundStyle(CalorynTheme.textSecondary)

            nutritionField(
                label: "Calories",
                text: $draft.caloriesPerServing,
                unit: "kcal",
                focus: .calories,
                required: true
            )
            .accessibilityIdentifier("customFood.calories")

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
        .glassCard(cornerRadius: CalorynTheme.smallCornerRadius)
    }

    private var optionalNutritionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("OPTIONAL STATS PER SERVING")
                .font(CalorynTheme.sectionEyebrow)
                .foregroundStyle(CalorynTheme.textSecondary)

            Text("Leave unknown values blank.")
                .font(CalorynTheme.caption)
                .foregroundStyle(CalorynTheme.textSecondary)

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
                label: "Added Sugar",
                text: $draft.addedSugarsPerServing,
                unit: "g",
                focus: .addedSugars,
                placeholder: ""
            )

            nutritionField(
                label: "Sat Fat",
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
        .glassCard(cornerRadius: CalorynTheme.smallCornerRadius)
    }

    private func nutritionField(
        label: String,
        text: Binding<String>,
        unit: String,
        focus: Field,
        required: Bool = false,
        placeholder: String = "0"
    ) -> some View {
        HStack {
            HStack(spacing: 4) {
                Text(label)
                    .font(CalorynTheme.bodyText)
                    .foregroundStyle(CalorynTheme.textPrimary)
                if required {
                    Text("*")
                        .font(CalorynTheme.bodyText)
                        .foregroundStyle(CalorynTheme.terracotta)
                }
            }
            .frame(width: 112, alignment: .leading)

            TextField(placeholder, text: text)
                .font(CalorynTheme.numericBody)
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: focus)
                .calorynInputField(isFocused: focusedField == focus)

            Text(unit)
                .font(CalorynTheme.caption)
                .foregroundStyle(CalorynTheme.textSecondary)
                .frame(width: 44, alignment: .leading)
        }
    }

    private var servingSizeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SERVING SIZE")
                .font(CalorynTheme.sectionEyebrow)
                .foregroundStyle(CalorynTheme.textSecondary)

            HStack {
                Text("One serving")
                    .font(CalorynTheme.bodyText)
                    .foregroundStyle(CalorynTheme.textPrimary)

                Spacer()

                TextField("100", text: $draft.servingSizeGrams)
                    .font(CalorynTheme.numericBody)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .servingSize)
                    .calorynInputField(isFocused: focusedField == .servingSize)
                    .frame(width: 80)
                    .accessibilityIdentifier("customFood.servingSize")

                Text("g")
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)
            }

            Text("The nutrition values above are for one serving of this size.")
                .font(CalorynTheme.caption)
                .foregroundStyle(CalorynTheme.textSecondary)
        }
        .glassCard(cornerRadius: CalorynTheme.smallCornerRadius)
    }

    private var deleteSection: some View {
        DestructiveGlassButton("Delete Manual Entry") {
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
                // Keep the existing silent save behavior.
            }
            BarcodeRecoveryAnalytics.record(
                path: existingFood == nil ? .manualCreation : .personalEdit,
                result: existingFood != nil
                    ? .completed
                    : (materialization.isNew ? .completed : .reused)
            )
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
                // Keep the existing silent save behavior.
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
        dismiss()
    }

    private var formTitle: String {
        if isEditing {
            return existingFood?.isCatalogProduct == true
                ? "Edit Product"
                : "Edit Manual Entry"
        }
        return recoveryBarcode != nil ? "Create Manual Food" : "Create Manual Entry"
    }

    private func deleteFood() {
        if let food = existingFood {
            food.deletePreservingLogEntrySnapshots(from: modelContext)
            do {
                try modelContext.save()
                CalorynAppShortcutRefresh.favoritesChanged()
            } catch {
                // Keep the existing silent deletion behavior.
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

#Preview {
    CustomFoodFormView()
        .modelContainer(
            for: [UserProfile.self, FoodItem.self, FoodLogEntry.self, RecipeIngredient.self],
            inMemory: true
        )
}
