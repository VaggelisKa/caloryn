import SwiftUI
import SwiftData

struct CustomFoodFormView: View {
    var existingFood: FoodItem?
    var onSaved: ((FoodItem) -> Void)?
    var allowsDeletion: Bool

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

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

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name, brand, calories, protein, carbs, fat, fiber
        case sugars, addedSugars, saturatedFat, sodium, cholesterol, alcohol
        case servingSize
    }

    private var isEditing: Bool { existingFood != nil }

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

    init(existingFood: FoodItem? = nil, onSaved: ((FoodItem) -> Void)? = nil, allowsDeletion: Bool = true) {
        self.existingFood = existingFood
        self.onSaved = onSaved
        self.allowsDeletion = allowsDeletion
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
            .navigationTitle(isEditing ? "Edit Manual Entry" : "Create Manual Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .accessibilityLabel("Close")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveFood()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
            .onAppear(perform: populateFromExisting)
            .confirmationDialog("Delete Manual Entry", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive, action: deleteFood)
            } message: {
                Text("This will permanently remove \"\(name)\" from your manual entries.")
            }
        }
        .presentationDetents([.large])
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FOOD DETAILS")
                .font(CalorynTheme.caption)
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
        }
        .glassCard(cornerRadius: CalorynTheme.smallCornerRadius)
    }

    private var produceTrackingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FRUIT & VEG VARIETY")
                .font(CalorynTheme.caption)
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
                .font(.system(size: 48, weight: .bold, design: .rounded))
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
                .font(CalorynTheme.caption)
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
                .font(CalorynTheme.caption)
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
                .font(CalorynTheme.caption)
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
        servingSizeGrams = "\(Int(serving))"
        caloriesPerServing = "\(Int(food.calories(forGrams: serving)))"
        proteinPerServing = String(format: "%.1f", food.protein(forGrams: serving))
        carbsPerServing = String(format: "%.1f", food.carbs(forGrams: serving))
        fatPerServing = String(format: "%.1f", food.fat(forGrams: serving))
        fiberPerServing = food.fiber(forGrams: serving).manualInputFormatted
        sugarsPerServing = optionalPerServingText(food.sugarsPer100g, serving: serving)
        addedSugarsPerServing = optionalPerServingText(food.addedSugarsPer100g, serving: serving)
        saturatedFatPerServing = optionalPerServingText(food.saturatedFatPer100g, serving: serving)
        sodiumPerServing = optionalPerServingText(food.sodiumPer100g, serving: serving, unit: .milligramsFromGrams)
        cholesterolPerServing = optionalPerServingText(food.cholesterolPer100g, serving: serving, unit: .milligramsFromGrams)
        alcoholPerServing = optionalPerServingText(food.alcoholPer100g, serving: serving)
        produceKind = food.produceKind
    }

    private func saveFood() {
        let serving = servingGrams > 0 ? servingGrams : 100
        let cal = parseDecimal(caloriesPerServing) ?? 0
        let pro = parseDecimal(proteinPerServing) ?? 0
        let carb = parseDecimal(carbsPerServing) ?? 0
        let f = parseDecimal(fatPerServing) ?? 0
        let fiber = parseDecimal(fiberPerServing) ?? 0
        let sugarsPer100 = optionalPer100g(sugarsPerServing, serving: serving)
        let addedSugarsPer100 = optionalPer100g(addedSugarsPerServing, serving: serving)
        let saturatedFatPer100 = optionalPer100g(saturatedFatPerServing, serving: serving)
        let sodiumPer100 = optionalPer100g(sodiumPerServing, serving: serving, unit: .milligramsFromGrams)
        let cholesterolPer100 = optionalPer100g(cholesterolPerServing, serving: serving, unit: .milligramsFromGrams)
        let alcoholPer100 = optionalPer100g(alcoholPerServing, serving: serving)

        let calPer100 = cal / serving * 100
        let proPer100 = pro / serving * 100
        let carbPer100 = carb / serving * 100
        let fPer100 = f / serving * 100
        let fiberPer100 = fiber / serving * 100

        if let food = existingFood {
            food.name = name.trimmingCharacters(in: .whitespaces)
            food.brand = brand.isEmpty ? nil : brand.trimmingCharacters(in: .whitespaces)
            food.caloriesPer100g = calPer100
            food.proteinPer100g = proPer100
            food.carbsPer100g = carbPer100
            food.fatPer100g = fPer100
            food.fiberPer100g = fiberPer100
            food.sugarsPer100g = sugarsPer100
            food.addedSugarsPer100g = addedSugarsPer100
            food.saturatedFatPer100g = saturatedFatPer100
            food.sodiumPer100g = sodiumPer100
            food.cholesterolPer100g = cholesterolPer100
            food.alcoholPer100g = alcoholPer100
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
                caloriesPer100g: calPer100,
                proteinPer100g: proPer100,
                carbsPer100g: carbPer100,
                fatPer100g: fPer100,
                fiberPer100g: fiberPer100,
                sugarsPer100g: sugarsPer100,
                addedSugarsPer100g: addedSugarsPer100,
                saturatedFatPer100g: saturatedFatPer100,
                sodiumPer100g: sodiumPer100,
                cholesterolPer100g: cholesterolPer100,
                alcoholPer100g: alcoholPer100,
                defaultServingG: serving,
                produceKind: produceKind,
                isCustom: true
            )
            modelContext.insert(food)
            try? modelContext.save()
            onSaved?(food)
        }
        dismiss()
    }

    private func optionalPer100g(
        _ text: String,
        serving: Double,
        unit: TrackedNutrientUnit = .grams
    ) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let inputValue = parseDecimal(trimmed) else { return nil }
        let storedValue = unit.storedValue(fromInput: inputValue)
        return storedValue / serving * 100
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
            modelContext.delete(food)
        }
        dismiss()
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
