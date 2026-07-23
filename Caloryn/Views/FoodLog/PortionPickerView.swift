import SwiftUI
import SwiftData

struct PortionPickerView: View {
    let foodItem: FoodItem
    let mealType: MealType
    let logDate: Date
    let isNewFood: Bool
    let snackIndex: Int
    let existingEntry: FoodLogEntry?
    var onLogged: (() -> Void)?
    var onDeleted: ((FoodLogEntry) -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var portionGrams: Double = 100
    @State private var selectedMeal: MealType
    @State private var portionMode: PortionMode = .grams
    @State private var selectedGramStep: Int = 100
    @State private var selectedServingCount: Int = 1
    @State private var selectedRecipeServingID = RecipeServingOption.one.id
    @State private var showingDeleteConfirmation = false
    @State private var favoriteErrorMessage: String?

    private enum PortionMode: Hashable {
        case grams
        case serving
        case recipeServing
    }

    private struct PortionNutrient: Identifiable {
        enum Unit {
            case grams
            case milligramsFromGrams
        }

        let id: String
        let label: String
        let value: Double
        let unit: Unit

        var formattedValue: String {
            switch unit {
            case .grams:
                value.macroFormatted
            case .milligramsFromGrams:
                "\(Int((value * 1000).rounded()))mg"
            }
        }
    }

    private struct RecipeServingOption: Identifiable, Hashable {
        let id: String
        let label: String
        let multiplier: Double

        static let one = RecipeServingOption(id: "1", label: "1", multiplier: 1)
    }

    private static let recipeServingOptions: [RecipeServingOption] = [
        RecipeServingOption(id: "quarter", label: "1/4", multiplier: 0.25),
        RecipeServingOption(id: "half", label: "1/2", multiplier: 0.5),
        .one,
        RecipeServingOption(id: "2", label: "2", multiplier: 2),
        RecipeServingOption(id: "3", label: "3", multiplier: 3),
        RecipeServingOption(id: "4", label: "4", multiplier: 4)
    ]

    init(
        foodItem: FoodItem,
        mealType: MealType,
        logDate: Date,
        isNewFood: Bool,
        snackIndex: Int = 0,
        existingEntry: FoodLogEntry? = nil,
        onLogged: (() -> Void)? = nil,
        onDeleted: ((FoodLogEntry) -> Void)? = nil
    ) {
        self.foodItem = foodItem
        self.mealType = mealType
        self.logDate = logDate
        self.isNewFood = isNewFood
        self.snackIndex = snackIndex
        self.existingEntry = existingEntry
        self.onLogged = onLogged
        self.onDeleted = onDeleted
        self._selectedMeal = State(initialValue: existingEntry?.mealType ?? mealType)

        let initialPortion = existingEntry?.portionGrams ?? foodItem.defaultServingG ?? 100
        self._portionGrams = State(initialValue: initialPortion)

        let nearestStep = Self.normalizedGramStep(initialPortion, limit: Self.gramOptionLimit(for: foodItem))
        self._selectedGramStep = State(initialValue: nearestStep)

        if foodItem.isRecipe {
            let recipeTotalGrams = foodItem.defaultServingG ?? 100
            let servingID = Self.nearestRecipeServingOptionID(
                for: initialPortion,
                recipeTotalGrams: recipeTotalGrams
            )
            self._selectedRecipeServingID = State(initialValue: servingID)
            let matchesRecipeServing = Self.recipeServingOption(id: servingID)
                .map { Self.isApproximatelyEqual(recipeTotalGrams * $0.multiplier, initialPortion) } == true
            let usesRecipeServingMode = existingEntry == nil || matchesRecipeServing
            self._portionMode = State(
                initialValue: usesRecipeServingMode ? .recipeServing : .grams
            )
        } else if let info = foodItem.servingInfo {
            let count = Self.normalizedServingCount(for: initialPortion, foodItem: foodItem)
            self._selectedServingCount = State(initialValue: count)
            let usesServingMode = existingEntry == nil || Self.isApproximatelyEqual(Double(count) * info.gramsPerUnit, initialPortion)
            self._portionMode = State(
                initialValue: usesServingMode ? .serving : .grams
            )
        }
    }

    private var previewNutrition: NutritionValues {
        foodItem.nutrition(forGrams: portionGrams)
    }

    private var previewCalories: Double { previewNutrition.calories }
    private var previewProtein: Double { previewNutrition.proteinG }
    private var previewCarbs: Double { previewNutrition.carbsG }
    private var previewFat: Double { previewNutrition.fatG }
    private var previewFiber: Double { previewNutrition.fiberG }
    private var isEditing: Bool { existingEntry != nil }
    private var saveButtonTitle: String {
        if isEditing { return "Save Changes" }
        return foodItem.isRecipe ? "Log Recipe" : "Log Food"
    }

    private var nutritionDetails: [PortionNutrient] {
        [
            PortionNutrient(id: "protein", label: "Protein", value: previewProtein, unit: .grams),
            PortionNutrient(id: "carbs", label: "Carbs", value: previewCarbs, unit: .grams),
            PortionNutrient(id: "fat", label: "Fat", value: previewFat, unit: .grams),
            PortionNutrient(id: "fiber", label: "Fiber", value: previewFiber, unit: .grams)
        ] + optionalNutritionDetails
    }

    private var optionalNutritionDetails: [PortionNutrient] {
        [
            nutrient("sugars", "Sugars", previewNutrition.sugarsG),
            nutrient("added-sugars", "Added sugars", previewNutrition.addedSugarsG),
            nutrient("sucrose", "Sucrose", previewNutrition.sucroseG),
            nutrient("glucose", "Glucose", previewNutrition.glucoseG),
            nutrient("fructose", "Fructose", previewNutrition.fructoseG),
            nutrient("lactose", "Lactose", previewNutrition.lactoseG),
            nutrient("maltose", "Maltose", previewNutrition.maltoseG),
            nutrient("maltodextrins", "Maltodextrins", previewNutrition.maltodextrinsG),
            nutrient("starch", "Starch", previewNutrition.starchG),
            nutrient("polyols", "Polyols", previewNutrition.polyolsG),
            nutrient("saturated-fat", "Saturated fat", previewNutrition.saturatedFatG),
            nutrient("trans-fat", "Trans fat", previewNutrition.transFatG),
            nutrient("monounsaturated-fat", "Monounsaturated", previewNutrition.monounsaturatedFatG),
            nutrient("polyunsaturated-fat", "Polyunsaturated", previewNutrition.polyunsaturatedFatG),
            nutrient("omega-3-fat", "Omega-3 fat", previewNutrition.omega3FatG),
            nutrient("omega-6-fat", "Omega-6 fat", previewNutrition.omega6FatG),
            nutrient("omega-9-fat", "Omega-9 fat", previewNutrition.omega9FatG),
            nutrient("salt", "Salt", previewNutrition.saltG),
            nutrient("sodium", "Sodium", previewNutrition.sodiumG, unit: .milligramsFromGrams),
            nutrient("cholesterol", "Cholesterol", previewNutrition.cholesterolG, unit: .milligramsFromGrams),
            nutrient("soluble-fiber", "Soluble fiber", previewNutrition.solubleFiberG),
            nutrient("insoluble-fiber", "Insoluble fiber", previewNutrition.insolubleFiberG),
            nutrient("casein", "Casein", previewNutrition.caseinG),
            nutrient("serum-proteins", "Serum proteins", previewNutrition.serumProteinsG),
            nutrient("alcohol", "Alcohol", previewNutrition.alcoholG)
        ].compactMap { $0 }
    }

    private var recipeTotalGrams: Double {
        foodItem.defaultServingG ?? 100
    }

    private var gramOptions: [Int] {
        Array(stride(from: 5, through: Self.gramOptionLimit(for: foodItem), by: 5))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                foodHeader

                caloriePreview

                portionPicker

                mealSelector

                nutritionPreview
            }
            .padding(.horizontal, CalorynTheme.pagePadding)
            .padding(.bottom, 100)
        }
        .navigationTitle(isEditing ? "Edit Portion" : "Portion")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isEditing {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(CalorynTheme.toolbarIcon)
                    }
                    .accessibilityLabel("Close")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash.fill")
                            .font(CalorynTheme.toolbarIcon)
                            .foregroundStyle(.red)
                    }
                    .tint(.red)
                    .accessibilityLabel("Delete Log Entry")
                }
            }

            if !isNewFood {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: togglePinned) {
                        Image(systemName: foodItem.isPinned ? "pin.fill" : "pin")
                            .font(CalorynTheme.toolbarIcon)
                            .foregroundStyle(foodItem.isPinned ? CalorynTheme.terracotta : CalorynTheme.sage)
                    }
                    .accessibilityLabel(foodItem.isPinned ? "Unpin \(foodItem.name)" : "Pin \(foodItem.name)")
                    .accessibilityHint(foodItem.isPinned ? "Removes this item from pinned foods" : "Adds this item to pinned foods")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Button(action: savePortion) {
                    Text(saveButtonTitle)
                        .font(CalorynTheme.buttonLabel)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .adaptiveGlassProminentButton()
                .tint(CalorynTheme.sage)
                .padding(.horizontal, CalorynTheme.pagePadding)
                .padding(.top, 10)
                .padding(.bottom, 16)
            }
            .background(.regularMaterial)
        }
        .confirmationDialog("Delete Log Entry", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive, action: deleteEntry)
        } message: {
            Text("Remove \(foodItem.name) from your log?")
        }
        .alert("Couldn’t Update Pin", isPresented: favoriteErrorIsPresented) {
            Button("OK", role: .cancel) {
                favoriteErrorMessage = nil
            }
        } message: {
            Text(favoriteErrorMessage ?? "Please try again.")
        }
    }

    @AppStorage("showNutriscore") private var showNutriscore = true

    private var foodHeader: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Text(foodItem.name)
                    .font(CalorynTheme.sectionTitle)
                    .foregroundStyle(CalorynTheme.textPrimary)
                    .multilineTextAlignment(.center)

                if showNutriscore, let grade = foodItem.nutriscoreGrade {
                    NutriscoreBadge(grade: grade)
                }
            }

            if let brand = foodItem.brand, !brand.isEmpty {
                Text(brand)
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)
            }

            if !foodItem.isRecipe, let serving = foodItem.servingDescription, !serving.isEmpty {
                Text("Serving: \(serving)")
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)
            }
        }
        .padding(.top, 8)
    }

    private var caloriePreview: some View {
        VStack(spacing: 4) {
            Text("\(Int(previewCalories))")
                .font(CalorynTheme.displayNumber)
                .foregroundStyle(CalorynTheme.sage)
                .contentTransition(.numericText())
                .animation(.smooth(duration: 0.3), value: Int(previewCalories))

            Text("calories")
                .font(CalorynTheme.bodyText)
                .foregroundStyle(CalorynTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .glassCard()
    }

    private var maxServingCount: Int {
        Self.maxServingCount(for: foodItem)
    }

    private var portionPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PORTION SIZE")
                .font(CalorynTheme.sectionEyebrow)
                .foregroundStyle(CalorynTheme.textSecondary)

            HStack(spacing: 0) {
                Group {
                    switch portionMode {
                    case .grams:
                        Picker("Amount", selection: $selectedGramStep) {
                            ForEach(gramOptions, id: \.self) { g in
                                Text("\(g)").tag(g)
                            }
                        }
                    case .serving:
                        Picker("Count", selection: $selectedServingCount) {
                            ForEach(1...maxServingCount, id: \.self) { n in
                                Text("\(n)").tag(n)
                            }
                        }
                    case .recipeServing:
                        Picker("Recipe serving", selection: $selectedRecipeServingID) {
                            ForEach(Self.recipeServingOptions) { option in
                                Text(option.label).tag(option.id)
                            }
                        }
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)

                if foodItem.isRecipe {
                    Picker("Unit", selection: $portionMode) {
                        Text("grams").tag(PortionMode.grams)
                        Text("serving").tag(PortionMode.recipeServing)
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 120)
                } else if let info = foodItem.servingInfo {
                    Picker("Unit", selection: $portionMode) {
                        Text("grams").tag(PortionMode.grams)
                        Text(info.unitName).tag(PortionMode.serving)
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 120)
                } else {
                    Text("grams")
                        .font(CalorynTheme.bodyText)
                        .foregroundStyle(CalorynTheme.textSecondary)
                        .frame(width: 120)
                }
            }
            .frame(height: 150)
            .clipped()
            .onChange(of: selectedGramStep) {
                guard portionMode == .grams else { return }
                portionGrams = Double(selectedGramStep)
                if foodItem.isRecipe {
                    selectedRecipeServingID = nearestRecipeServingOptionID(for: portionGrams)
                }
            }
            .onChange(of: selectedServingCount) {
                guard portionMode == .serving, let info = foodItem.servingInfo else { return }
                let grams = Double(selectedServingCount) * info.gramsPerUnit
                portionGrams = grams
            }
            .onChange(of: selectedRecipeServingID) {
                guard portionMode == .recipeServing, let option = selectedRecipeServingOption else { return }
                portionGrams = recipeTotalGrams * option.multiplier
                selectedGramStep = Self.normalizedGramStep(portionGrams, limit: Self.gramOptionLimit(for: foodItem))
            }
            .onChange(of: portionMode) {
                switch portionMode {
                case .grams:
                    let nearest = Self.normalizedGramStep(portionGrams, limit: Self.gramOptionLimit(for: foodItem))
                    selectedGramStep = nearest
                    portionGrams = Double(nearest)
                case .serving:
                    guard let info = foodItem.servingInfo else { return }
                    let count = max(1, min(maxServingCount, Int(round(portionGrams / info.gramsPerUnit))))
                    selectedServingCount = count
                    let grams = Double(count) * info.gramsPerUnit
                    portionGrams = grams
                case .recipeServing:
                    selectedRecipeServingID = nearestRecipeServingOptionID(for: portionGrams)
                    if let option = selectedRecipeServingOption {
                        portionGrams = recipeTotalGrams * option.multiplier
                    }
                }
            }
        }
        .glassCard(cornerRadius: CalorynTheme.smallCornerRadius)
    }

    private var nutritionPreview: some View {
        let items = nutritionDetails

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("NUTRITION")
                    .font(CalorynTheme.sectionEyebrow)
                    .foregroundStyle(CalorynTheme.textSecondary)

                Spacer()

                Text("\(Int(portionGrams.rounded()))g")
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .contentTransition(.numericText())
                    .animation(.smooth(duration: 0.3), value: Int(portionGrams.rounded()))
            }

            VStack(spacing: 0) {
                ForEach(items) { item in
                    nutrientRow(item)
                        .padding(.vertical, 7)

                    if item.id != items.last?.id {
                        Divider()
                            .foregroundStyle(CalorynTheme.stone.opacity(0.3))
                    }
                }
            }
        }
        .glassCard(cornerRadius: CalorynTheme.smallCornerRadius)
    }

    private func nutrientRow(_ nutrient: PortionNutrient) -> some View {
        HStack {
            Text(nutrient.label)
                .font(CalorynTheme.bodyText)
                .foregroundStyle(CalorynTheme.textPrimary)

            Spacer()

            Text(nutrient.formattedValue)
                .font(CalorynTheme.numericBody)
                .foregroundStyle(CalorynTheme.textPrimary)
                .contentTransition(.numericText())
                .animation(.smooth(duration: 0.3), value: nutrient.formattedValue)
        }
        .accessibilityElement(children: .combine)
    }

    private func nutrient(
        _ id: String,
        _ label: String,
        _ value: Double?,
        unit: PortionNutrient.Unit = .grams
    ) -> PortionNutrient? {
        guard let value else { return nil }
        return PortionNutrient(id: id, label: label, value: value, unit: unit)
    }

    private var mealSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MEAL")
                .font(CalorynTheme.sectionEyebrow)
                .foregroundStyle(CalorynTheme.textSecondary)

            Picker("Meal", selection: $selectedMeal) {
                ForEach(MealType.allCases) { meal in
                    Label(meal.displayName, systemImage: meal.iconName)
                        .tag(meal)
                }
            }
            .pickerStyle(.segmented)
        }
        .glassCard(cornerRadius: CalorynTheme.smallCornerRadius)
    }

    private func savePortion() {
        if let existingEntry {
            DailyFoodLogCommands.updateLoggedEntry(
                existingEntry,
                date: logDate,
                mealType: selectedMeal,
                foodItem: foodItem,
                portionGrams: portionGrams,
                snackIndex: snackIndex
            )
            try? modelContext.save()
        } else {
            DailyFoodLogCommands.logFood(
                foodItem: foodItem,
                portionGrams: portionGrams,
                mealType: selectedMeal,
                logDate: logDate,
                isNewFood: isNewFood,
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

    private func togglePinned() {
        do {
            try PinnedFoodLogging.setPinned(
                !foodItem.isPinned,
                for: foodItem,
                modelContext: modelContext
            )
        } catch {
            favoriteErrorMessage = "Your pin couldn’t be updated. Please try again."
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

    private var selectedRecipeServingOption: RecipeServingOption? {
        Self.recipeServingOptions.first { $0.id == selectedRecipeServingID }
    }

    private func nearestRecipeServingOptionID(for grams: Double) -> String {
        Self.nearestRecipeServingOptionID(for: grams, recipeTotalGrams: recipeTotalGrams)
    }

    private static func nearestRecipeServingOptionID(for grams: Double, recipeTotalGrams: Double) -> String {
        guard recipeTotalGrams > 0 else { return RecipeServingOption.one.id }
        let multiplier = grams / recipeTotalGrams
        return recipeServingOptions.min {
            abs($0.multiplier - multiplier) < abs($1.multiplier - multiplier)
        }?.id ?? RecipeServingOption.one.id
    }

    private static func recipeServingOption(id: String) -> RecipeServingOption? {
        recipeServingOptions.first { $0.id == id }
    }

    private static func maxServingCount(for foodItem: FoodItem) -> Int {
        guard let info = foodItem.servingInfo else { return 1 }
        return max(2, min(10, Int(500 / info.gramsPerUnit)))
    }

    private static func normalizedServingCount(for grams: Double, foodItem: FoodItem) -> Int {
        guard let info = foodItem.servingInfo else { return 1 }
        let count = Int(round(grams / info.gramsPerUnit))
        return max(1, min(maxServingCount(for: foodItem), count))
    }

    private static func gramOptionLimit(for foodItem: FoodItem) -> Int {
        let defaultServing = foodItem.defaultServingG ?? 100
        let recipeLimit = Int(ceil(defaultServing / 5) * 5)
        if foodItem.isRecipe {
            let maxServingMultiplier = recipeServingOptions.map(\.multiplier).max() ?? 1
            let servingLimit = Int(ceil(defaultServing * maxServingMultiplier / 5) * 5)
            return max(500, servingLimit)
        }
        return max(500, recipeLimit)
    }

    private static func normalizedGramStep(_ grams: Double, limit: Int) -> Int {
        max(5, min(limit, Int(round(grams / 5)) * 5))
    }

    private static func isApproximatelyEqual(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(lhs - rhs) < 0.001
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
