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

    @State private var name = ""
    @State private var brand = ""
    @State private var caloriesPerServing = ""
    @State private var proteinPerServing = ""
    @State private var carbsPerServing = ""
    @State private var fatPerServing = ""
    @State private var fiberPerServing = ""
    @State private var sugarsPerServing = ""
    @State private var addedSugarsPerServing = ""
    @State private var saturatedFatPerServing = ""
    @State private var sodiumPerServing = ""
    @State private var cholesterolPerServing = ""
    @State private var alcoholPerServing = ""
    @State private var servingSizeGrams = "100"
    @State private var produceKind: ProduceKind = .unclassified
    @State private var showingDeleteConfirmation = false
    @State private var favoriteErrorMessage: String?
    @State private var initialTextByField: [Field: String] = [:]
    @State private var initialProduceKind: ProduceKind?

    @FocusState private var focusedField: Field?

    private enum Field: Hashable, CaseIterable {
        case name, brand, calories, protein, carbs, fat, fiber
        case sugars, addedSugars, saturatedFat, sodium, cholesterol, alcohol
        case servingSize
    }

    private var isEditing: Bool { existingFood != nil }
    private var recoveryBarcode: String? {
        existingFood?.normalizedBarcode ?? BarcodeIdentity.normalized(prefilledBarcode)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
        && (parseDecimal(caloriesPerServing) ?? -1) >= 0
        && !caloriesPerServing.isEmpty
        && optionalTrackedInputsAreValid
    }

    private var servingGrams: Double {
        parseDecimal(servingSizeGrams) ?? 100
    }

    private var previewCalories: Double {
        parseDecimal(caloriesPerServing) ?? 0
    }

    private var previewProtein: Double {
        parseDecimal(proteinPerServing) ?? 0
    }

    private var previewCarbs: Double {
        parseDecimal(carbsPerServing) ?? 0
    }

    private var previewFat: Double {
        parseDecimal(fatPerServing) ?? 0
    }

    private var optionalTrackedInputsAreValid: Bool {
        [
            fiberPerServing,
            sugarsPerServing,
            addedSugarsPerServing,
            saturatedFatPerServing,
            sodiumPerServing,
            cholesterolPerServing,
            alcoholPerServing
        ].allSatisfy(isOptionalNonnegativeDecimal(_:))
    }

    /// Parses decimal strings, supporting both "." and "," as decimal separators (locale-agnostic).
    private func parseDecimal(_ string: String) -> Double? {
        let normalized = string.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    private func isOptionalNonnegativeDecimal(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return true }
        return (parseDecimal(trimmed) ?? -1) >= 0
    }

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
                    .disabled(!canSave)
                }
            }
            .onAppear(perform: populateFromExisting)
            .confirmationDialog("Delete Manual Entry", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive, action: deleteFood)
            } message: {
                Text("This will permanently remove \"\(name)\" from your manual entries.")
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

            TextField("Food name (e.g. Nick's Pizza)", text: $name)
                .font(CalorynTheme.bodyText)
                .textInputAutocapitalization(.words)
                .focused($focusedField, equals: .name)
                .calorynInputField(isFocused: focusedField == .name)

            TextField("Brand (optional)", text: $brand)
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

            Picker("Count as", selection: $produceKind) {
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
                text: $caloriesPerServing,
                unit: "kcal",
                focus: .calories,
                required: true
            )

            nutritionField(
                label: "Protein",
                text: $proteinPerServing,
                unit: "g",
                focus: .protein
            )

            nutritionField(
                label: "Carbs",
                text: $carbsPerServing,
                unit: "g",
                focus: .carbs
            )

            nutritionField(
                label: "Fat",
                text: $fatPerServing,
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
                text: $fiberPerServing,
                unit: "g",
                focus: .fiber,
                placeholder: ""
            )

            nutritionField(
                label: "Sugars",
                text: $sugarsPerServing,
                unit: "g",
                focus: .sugars,
                placeholder: ""
            )

            nutritionField(
                label: "Added Sugar",
                text: $addedSugarsPerServing,
                unit: "g",
                focus: .addedSugars,
                placeholder: ""
            )

            nutritionField(
                label: "Sat Fat",
                text: $saturatedFatPerServing,
                unit: "g",
                focus: .saturatedFat,
                placeholder: ""
            )

            nutritionField(
                label: "Sodium",
                text: $sodiumPerServing,
                unit: "mg",
                focus: .sodium,
                placeholder: ""
            )

            nutritionField(
                label: "Cholesterol",
                text: $cholesterolPerServing,
                unit: "mg",
                focus: .cholesterol,
                placeholder: ""
            )

            nutritionField(
                label: "Alcohol",
                text: $alcoholPerServing,
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

                TextField("100", text: $servingSizeGrams)
                    .font(CalorynTheme.numericBody)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .servingSize)
                    .calorynInputField(isFocused: focusedField == .servingSize)
                    .frame(width: 80)

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
        name = food.name
        brand = food.brand ?? ""
        let serving = food.defaultServingG ?? 100
        servingSizeGrams = food.defaultServingG.map(\.manualInputFormatted) ?? ""
        caloriesPerServing = "\(Int(food.calories(forGrams: serving)))"
        proteinPerServing = editableCoreText(
            food.protein(forGrams: serving),
            origin: food.fieldOrigin(for: .protein)
        )
        carbsPerServing = editableCoreText(
            food.carbs(forGrams: serving),
            origin: food.fieldOrigin(for: .carbohydrates)
        )
        fatPerServing = editableCoreText(
            food.fat(forGrams: serving),
            origin: food.fieldOrigin(for: .fat)
        )
        fiberPerServing = editableCoreText(
            food.fiber(forGrams: serving),
            origin: food.fieldOrigin(for: .fiber)
        )
        sugarsPerServing = optionalPerServingText(food.sugarsPer100g, serving: serving)
        addedSugarsPerServing = optionalPerServingText(food.addedSugarsPer100g, serving: serving)
        saturatedFatPerServing = optionalPerServingText(food.saturatedFatPer100g, serving: serving)
        sodiumPerServing = optionalPerServingText(food.sodiumPer100g, serving: serving, unit: .milligramsFromGrams)
        cholesterolPerServing = optionalPerServingText(food.cholesterolPer100g, serving: serving, unit: .milligramsFromGrams)
        alcoholPerServing = optionalPerServingText(food.alcoholPer100g, serving: serving)
        produceKind = food.produceKind
        initialTextByField = Dictionary(
            uniqueKeysWithValues: Field.allCases.map { ($0, text(for: $0)) }
        )
        initialProduceKind = produceKind
    }

    private func saveFood() {
        let serving = servingGrams > 0 ? servingGrams : 100
        let cal = parseDecimal(caloriesPerServing) ?? 0
        let suppliedProtein = parseDecimal(proteinPerServing)
        let suppliedCarbohydrates = parseDecimal(carbsPerServing)
        let suppliedFat = parseDecimal(fatPerServing)
        let pro = suppliedProtein ?? 0
        let carb = suppliedCarbohydrates ?? 0
        let f = suppliedFat ?? 0
        let fiber = parseDecimal(fiberPerServing) ?? 0
        let nutritionPerServing = NutritionValues(
            calories: cal,
            proteinG: pro,
            carbsG: carb,
            fatG: f,
            fiberG: fiber,
            sugarsG: optionalServingValue(sugarsPerServing),
            addedSugarsG: optionalServingValue(addedSugarsPerServing),
            saturatedFatG: optionalServingValue(saturatedFatPerServing),
            sodiumG: optionalServingValue(sodiumPerServing, unit: .milligramsFromGrams),
            cholesterolG: optionalServingValue(cholesterolPerServing, unit: .milligramsFromGrams),
            alcoholG: optionalServingValue(alcoholPerServing)
        )
        let nutritionPer100g = NutritionValues.per100g(
            fromServing: nutritionPerServing,
            servingGrams: serving
        )

        if let recoveryBarcode {
            let personalEdit = FoodPersonalEdit(
                name: name.trimmingCharacters(in: .whitespaces),
                brand: brand.isEmpty ? nil : brand.trimmingCharacters(in: .whitespaces),
                caloriesPer100g: nutritionPer100g.calories,
                proteinPer100g: suppliedProtein.map { $0 * 100 / serving },
                carbohydratesPer100g: suppliedCarbohydrates.map { $0 * 100 / serving },
                fatPer100g: suppliedFat.map { $0 * 100 / serving },
                fiberPer100g: parseDecimal(fiberPerServing).map { $0 * 100 / serving },
                sugarsPer100g: nutritionPer100g.sugarsG,
                addedSugarsPer100g: nutritionPer100g.addedSugarsG,
                saturatedFatPer100g: nutritionPer100g.saturatedFatG,
                sodiumPer100g: nutritionPer100g.sodiumG,
                cholesterolPer100g: nutritionPer100g.cholesterolG,
                alcoholPer100g: nutritionPer100g.alcoholG,
                defaultServingG: parseDecimal(servingSizeGrams).flatMap { $0 > 0 ? $0 : nil },
                produceKind: produceKind,
                userEditedFields: userEditedRecoveryFields
            )
            let materialization = BarcodeRecoveryService.materializePersonalFood(
                barcode: recoveryBarcode,
                edit: personalEdit,
                localFoods: savedFoods,
                editing: existingFood
            )
            if !savedFoods.contains(where: { $0 === materialization.food }) {
                modelContext.insert(materialization.food)
            }
            try? modelContext.save()
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
            food.name = name.trimmingCharacters(in: .whitespaces)
            food.brand = brand.isEmpty ? nil : brand.trimmingCharacters(in: .whitespaces)
            food.applyUserNutritionEdit(
                nutritionPer100g,
                suppliedProtein: suppliedProtein,
                suppliedCarbohydrates: suppliedCarbohydrates,
                suppliedFat: suppliedFat
            )
            food.defaultServingG = serving
            food.servingDescription = nil
            food.categoryTags = []
            food.produceKind = produceKind
            try? modelContext.save()
            onSaved?(food)
        } else {
            let food = FoodItem(
                name: name.trimmingCharacters(in: .whitespaces),
                brand: brand.isEmpty ? nil : brand.trimmingCharacters(in: .whitespaces),
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
                produceKind: produceKind,
                isCustom: true
            )
            food.applyUserNutritionEdit(
                nutritionPer100g,
                suppliedProtein: suppliedProtein,
                suppliedCarbohydrates: suppliedCarbohydrates,
                suppliedFat: suppliedFat
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

    private func editableCoreText(
        _ value: Double,
        origin: FoodFieldOrigin
    ) -> String {
        origin == .missing ? "" : value.manualInputFormatted
    }

    private var userEditedRecoveryFields: Set<FoodField>? {
        if existingFood == nil {
            var suppliedFields = Set(
                Field.allCases.compactMap { field -> FoodField? in
                    let value = text(for: field)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    return value.isEmpty ? nil : recoveryField(for: field)
                }
            )
            if produceKind != .unclassified {
                suppliedFields.insert(.produceKind)
            }
            return suppliedFields
        }

        var editedFields = Set(
            Field.allCases.compactMap { field -> FoodField? in
                guard initialTextByField[field] != text(for: field) else { return nil }
                return recoveryField(for: field)
            }
        )
        if initialProduceKind != produceKind {
            editedFields.insert(.produceKind)
        }
        return editedFields
    }

    private func text(for field: Field) -> String {
        switch field {
        case .name: name
        case .brand: brand
        case .calories: caloriesPerServing
        case .protein: proteinPerServing
        case .carbs: carbsPerServing
        case .fat: fatPerServing
        case .fiber: fiberPerServing
        case .sugars: sugarsPerServing
        case .addedSugars: addedSugarsPerServing
        case .saturatedFat: saturatedFatPerServing
        case .sodium: sodiumPerServing
        case .cholesterol: cholesterolPerServing
        case .alcohol: alcoholPerServing
        case .servingSize: servingSizeGrams
        }
    }

    private func recoveryField(for field: Field) -> FoodField {
        switch field {
        case .name: .name
        case .brand: .brand
        case .calories: .calories
        case .protein: .protein
        case .carbs: .carbohydrates
        case .fat: .fat
        case .fiber: .fiber
        case .sugars: .sugars
        case .addedSugars: .addedSugars
        case .saturatedFat: .saturatedFat
        case .sodium: .sodium
        case .cholesterol: .cholesterol
        case .alcohol: .alcohol
        case .servingSize: .defaultServing
        }
    }

    private func optionalServingValue(
        _ text: String,
        unit: TrackedNutrientUnit = .grams
    ) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let inputValue = parseDecimal(trimmed) else { return nil }
        return unit.storedValue(fromInput: inputValue)
    }

    private func optionalPerServingText(
        _ valuePer100g: Double?,
        serving: Double,
        unit: TrackedNutrientUnit = .grams
    ) -> String {
        guard let valuePer100g else { return "" }
        let storedValue = valuePer100g * serving / 100

        switch unit {
        case .grams:
            return storedValue.manualInputFormatted
        case .milligramsFromGrams:
            return (storedValue * 1000).manualInputFormatted
        }
    }

    private func deleteFood() {
        if let food = existingFood {
            food.deletePreservingLogEntrySnapshots(from: modelContext)
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

private extension Double {
    var manualInputFormatted: String {
        let rounded = (self * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return "\(Int(rounded))"
        }
        return String(format: "%.1f", rounded)
    }
}

#Preview {
    CustomFoodFormView()
        .modelContainer(
            for: [UserProfile.self, FoodItem.self, FoodLogEntry.self, RecipeIngredient.self],
            inMemory: true
        )
}
