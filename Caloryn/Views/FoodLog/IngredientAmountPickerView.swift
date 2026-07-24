import SwiftUI

struct RecipeIngredientDraft: Identifiable, Hashable {
    var id: UUID
    var name: String
    var brand: String?
    var portionGrams: Double
    var caloriesPer100g: Double
    var proteinPer100g: Double
    var carbsPer100g: Double
    var fatPer100g: Double
    var fiberPer100g: Double
    var sugarsPer100g: Double?
    var addedSugarsPer100g: Double?
    var sucrosePer100g: Double?
    var glucosePer100g: Double?
    var fructosePer100g: Double?
    var lactosePer100g: Double?
    var maltosePer100g: Double?
    var maltodextrinsPer100g: Double?
    var starchPer100g: Double?
    var polyolsPer100g: Double?
    var saturatedFatPer100g: Double?
    var transFatPer100g: Double?
    var monounsaturatedFatPer100g: Double?
    var polyunsaturatedFatPer100g: Double?
    var omega3FatPer100g: Double?
    var omega6FatPer100g: Double?
    var omega9FatPer100g: Double?
    var saltPer100g: Double?
    var sodiumPer100g: Double?
    var cholesterolPer100g: Double?
    var solubleFiberPer100g: Double?
    var insolubleFiberPer100g: Double?
    var caseinPer100g: Double?
    var serumProteinsPer100g: Double?
    var alcoholPer100g: Double?
    var sortOrder: Int
    var produceKind: ProduceKind
    var provenance: FoodProvenance

    init(
        id: UUID = UUID(),
        name: String,
        brand: String?,
        portionGrams: Double,
        caloriesPer100g: Double,
        proteinPer100g: Double,
        carbsPer100g: Double,
        fatPer100g: Double,
        fiberPer100g: Double = 0,
        sugarsPer100g: Double? = nil,
        addedSugarsPer100g: Double? = nil,
        sucrosePer100g: Double? = nil,
        glucosePer100g: Double? = nil,
        fructosePer100g: Double? = nil,
        lactosePer100g: Double? = nil,
        maltosePer100g: Double? = nil,
        maltodextrinsPer100g: Double? = nil,
        starchPer100g: Double? = nil,
        polyolsPer100g: Double? = nil,
        saturatedFatPer100g: Double? = nil,
        transFatPer100g: Double? = nil,
        monounsaturatedFatPer100g: Double? = nil,
        polyunsaturatedFatPer100g: Double? = nil,
        omega3FatPer100g: Double? = nil,
        omega6FatPer100g: Double? = nil,
        omega9FatPer100g: Double? = nil,
        saltPer100g: Double? = nil,
        sodiumPer100g: Double? = nil,
        cholesterolPer100g: Double? = nil,
        solubleFiberPer100g: Double? = nil,
        insolubleFiberPer100g: Double? = nil,
        caseinPer100g: Double? = nil,
        serumProteinsPer100g: Double? = nil,
        alcoholPer100g: Double? = nil,
        sortOrder: Int,
        produceKind: ProduceKind = .unclassified,
        provenance: FoodProvenance = .userEntered
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.portionGrams = portionGrams
        self.caloriesPer100g = caloriesPer100g
        self.proteinPer100g = proteinPer100g
        self.carbsPer100g = carbsPer100g
        self.fatPer100g = fatPer100g
        self.fiberPer100g = fiberPer100g
        self.sugarsPer100g = sugarsPer100g
        self.addedSugarsPer100g = addedSugarsPer100g
        self.sucrosePer100g = sucrosePer100g
        self.glucosePer100g = glucosePer100g
        self.fructosePer100g = fructosePer100g
        self.lactosePer100g = lactosePer100g
        self.maltosePer100g = maltosePer100g
        self.maltodextrinsPer100g = maltodextrinsPer100g
        self.starchPer100g = starchPer100g
        self.polyolsPer100g = polyolsPer100g
        self.saturatedFatPer100g = saturatedFatPer100g
        self.transFatPer100g = transFatPer100g
        self.monounsaturatedFatPer100g = monounsaturatedFatPer100g
        self.polyunsaturatedFatPer100g = polyunsaturatedFatPer100g
        self.omega3FatPer100g = omega3FatPer100g
        self.omega6FatPer100g = omega6FatPer100g
        self.omega9FatPer100g = omega9FatPer100g
        self.saltPer100g = saltPer100g
        self.sodiumPer100g = sodiumPer100g
        self.cholesterolPer100g = cholesterolPer100g
        self.solubleFiberPer100g = solubleFiberPer100g
        self.insolubleFiberPer100g = insolubleFiberPer100g
        self.caseinPer100g = caseinPer100g
        self.serumProteinsPer100g = serumProteinsPer100g
        self.alcoholPer100g = alcoholPer100g
        self.sortOrder = sortOrder
        self.produceKind = produceKind
        self.provenance = provenance
    }

    init(from foodItem: FoodItem, sortOrder: Int) {
        self.init(
            name: foodItem.name,
            brand: foodItem.brand,
            portionGrams: foodItem.defaultServingG ?? 100,
            caloriesPer100g: foodItem.caloriesPer100g,
            proteinPer100g: foodItem.proteinPer100g,
            carbsPer100g: foodItem.carbsPer100g,
            fatPer100g: foodItem.fatPer100g,
            fiberPer100g: foodItem.fiberPer100g,
            sugarsPer100g: foodItem.sugarsPer100g,
            addedSugarsPer100g: foodItem.addedSugarsPer100g,
            sucrosePer100g: foodItem.sucrosePer100g,
            glucosePer100g: foodItem.glucosePer100g,
            fructosePer100g: foodItem.fructosePer100g,
            lactosePer100g: foodItem.lactosePer100g,
            maltosePer100g: foodItem.maltosePer100g,
            maltodextrinsPer100g: foodItem.maltodextrinsPer100g,
            starchPer100g: foodItem.starchPer100g,
            polyolsPer100g: foodItem.polyolsPer100g,
            saturatedFatPer100g: foodItem.saturatedFatPer100g,
            transFatPer100g: foodItem.transFatPer100g,
            monounsaturatedFatPer100g: foodItem.monounsaturatedFatPer100g,
            polyunsaturatedFatPer100g: foodItem.polyunsaturatedFatPer100g,
            omega3FatPer100g: foodItem.omega3FatPer100g,
            omega6FatPer100g: foodItem.omega6FatPer100g,
            omega9FatPer100g: foodItem.omega9FatPer100g,
            saltPer100g: foodItem.saltPer100g,
            sodiumPer100g: foodItem.sodiumPer100g,
            cholesterolPer100g: foodItem.cholesterolPer100g,
            solubleFiberPer100g: foodItem.solubleFiberPer100g,
            insolubleFiberPer100g: foodItem.insolubleFiberPer100g,
            caseinPer100g: foodItem.caseinPer100g,
            serumProteinsPer100g: foodItem.serumProteinsPer100g,
            alcoholPer100g: foodItem.alcoholPer100g,
            sortOrder: sortOrder,
            produceKind: foodItem.produceKind,
            provenance: foodItem.provenance
        )
    }

    init(from ingredient: RecipeIngredient) {
        self.init(
            id: ingredient.id,
            name: ingredient.name,
            brand: ingredient.brand,
            portionGrams: ingredient.portionGrams,
            caloriesPer100g: ingredient.caloriesPer100g,
            proteinPer100g: ingredient.proteinPer100g,
            carbsPer100g: ingredient.carbsPer100g,
            fatPer100g: ingredient.fatPer100g,
            fiberPer100g: ingredient.fiberPer100g,
            sugarsPer100g: ingredient.sugarsPer100g,
            addedSugarsPer100g: ingredient.addedSugarsPer100g,
            sucrosePer100g: ingredient.sucrosePer100g,
            glucosePer100g: ingredient.glucosePer100g,
            fructosePer100g: ingredient.fructosePer100g,
            lactosePer100g: ingredient.lactosePer100g,
            maltosePer100g: ingredient.maltosePer100g,
            maltodextrinsPer100g: ingredient.maltodextrinsPer100g,
            starchPer100g: ingredient.starchPer100g,
            polyolsPer100g: ingredient.polyolsPer100g,
            saturatedFatPer100g: ingredient.saturatedFatPer100g,
            transFatPer100g: ingredient.transFatPer100g,
            monounsaturatedFatPer100g: ingredient.monounsaturatedFatPer100g,
            polyunsaturatedFatPer100g: ingredient.polyunsaturatedFatPer100g,
            omega3FatPer100g: ingredient.omega3FatPer100g,
            omega6FatPer100g: ingredient.omega6FatPer100g,
            omega9FatPer100g: ingredient.omega9FatPer100g,
            saltPer100g: ingredient.saltPer100g,
            sodiumPer100g: ingredient.sodiumPer100g,
            cholesterolPer100g: ingredient.cholesterolPer100g,
            solubleFiberPer100g: ingredient.solubleFiberPer100g,
            insolubleFiberPer100g: ingredient.insolubleFiberPer100g,
            caseinPer100g: ingredient.caseinPer100g,
            serumProteinsPer100g: ingredient.serumProteinsPer100g,
            alcoholPer100g: ingredient.alcoholPer100g,
            sortOrder: ingredient.sortOrder,
            produceKind: ingredient.produceKind,
            provenance: ingredient.provenance
        )
    }

    var calories: Double { nutrition.calories }
    var proteinG: Double { nutrition.proteinG }
    var carbsG: Double { nutrition.carbsG }
    var fatG: Double { nutrition.fatG }
    var fiberG: Double { nutrition.fiberG }
    var sugarsG: Double? { nutrition.sugarsG }
    var addedSugarsG: Double? { nutrition.addedSugarsG }
    var sucroseG: Double? { nutrition.sucroseG }
    var glucoseG: Double? { nutrition.glucoseG }
    var fructoseG: Double? { nutrition.fructoseG }
    var lactoseG: Double? { nutrition.lactoseG }
    var maltoseG: Double? { nutrition.maltoseG }
    var maltodextrinsG: Double? { nutrition.maltodextrinsG }
    var starchG: Double? { nutrition.starchG }
    var polyolsG: Double? { nutrition.polyolsG }
    var saturatedFatG: Double? { nutrition.saturatedFatG }
    var transFatG: Double? { nutrition.transFatG }
    var monounsaturatedFatG: Double? { nutrition.monounsaturatedFatG }
    var polyunsaturatedFatG: Double? { nutrition.polyunsaturatedFatG }
    var omega3FatG: Double? { nutrition.omega3FatG }
    var omega6FatG: Double? { nutrition.omega6FatG }
    var omega9FatG: Double? { nutrition.omega9FatG }
    var saltG: Double? { nutrition.saltG }
    var sodiumG: Double? { nutrition.sodiumG }
    var cholesterolG: Double? { nutrition.cholesterolG }
    var solubleFiberG: Double? { nutrition.solubleFiberG }
    var insolubleFiberG: Double? { nutrition.insolubleFiberG }
    var caseinG: Double? { nutrition.caseinG }
    var serumProteinsG: Double? { nutrition.serumProteinsG }
    var alcoholG: Double? { nutrition.alcoholG }
}

struct IngredientAmountPickerView: View {
    let ingredient: RecipeIngredientDraft
    var onSave: (RecipeIngredientDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var gramsText: String
    @FocusState private var isAmountFocused: Bool

    private var grams: Double {
        parseDecimal(gramsText) ?? 0
    }

    private var canSave: Bool {
        grams > 0
    }

    private var previewNutrition: NutritionValues {
        ingredient.nutritionPer100g.scaled(by: grams / 100)
    }

    private var previewCalories: Double {
        previewNutrition.calories
    }

    private var previewProtein: Double {
        previewNutrition.proteinG
    }

    private var previewCarbs: Double {
        previewNutrition.carbsG
    }

    private var previewFat: Double {
        previewNutrition.fatG
    }

    init(ingredient: RecipeIngredientDraft, onSave: @escaping (RecipeIngredientDraft) -> Void) {
        self.ingredient = ingredient
        self.onSave = onSave
        self._gramsText = State(initialValue: Self.formattedInitialGrams(ingredient.portionGrams))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    ingredientHeader
                    caloriePreview
                    amountSection
                    macroPreview
                }
                .padding(.horizontal, CalorynTheme.pagePadding)
                .padding(.bottom, 24)
            }
            .navigationTitle("Ingredient Amount")
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

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .font(CalorynTheme.toolbarAction)
                    .disabled(!canSave)
                }
            }
            .onAppear {
                isAmountFocused = true
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var ingredientHeader: some View {
        VStack(spacing: 4) {
            Text(ingredient.name)
                .font(CalorynTheme.sectionTitle)
                .foregroundStyle(CalorynTheme.textPrimary)
                .multilineTextAlignment(.center)

            if let brand = ingredient.brand, !brand.isEmpty {
                Text(brand)
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

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AMOUNT")
                .font(CalorynTheme.sectionEyebrow)
                .foregroundStyle(CalorynTheme.textSecondary)

            HStack {
                Text("Measured amount")
                    .font(CalorynTheme.bodyText)
                    .foregroundStyle(CalorynTheme.textPrimary)

                Spacer()

                TextField("100", text: $gramsText)
                    .font(CalorynTheme.numericBody)
                    .keyboardType(.decimalPad)
                    .focused($isAmountFocused)
                    .calorynInputField(isFocused: isAmountFocused)
                    .frame(width: 92)

                Text("g")
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)
            }
        }
        .glassCard(cornerRadius: CalorynTheme.smallCornerRadius)
    }

    private var macroPreview: some View {
        HStack(spacing: CalorynTheme.cardSpacing) {
            macroPill("Protein", value: previewProtein, color: CalorynTheme.proteinColor)
            macroPill("Carbs", value: previewCarbs, color: CalorynTheme.carbColor)
            macroPill("Fat", value: previewFat, color: CalorynTheme.fatColor)
        }
    }

    private func macroPill(_ label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(CalorynTheme.caption)
                .foregroundStyle(CalorynTheme.textSecondary)
            Text(value.macroFormatted)
                .font(CalorynTheme.numericBody)
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .animation(.smooth(duration: 0.3), value: value.macroFormatted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .glassCard(cornerRadius: CalorynTheme.smallCornerRadius)
    }

    private func save() {
        var updated = ingredient
        updated.portionGrams = grams
        onSave(updated)
        dismiss()
    }

    private func parseDecimal(_ string: String) -> Double? {
        let normalized = string.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    private static func formattedInitialGrams(_ value: Double) -> String {
        value.rounded() == value ? "\(Int(value))" : String(format: "%.1f", value)
    }
}

#Preview {
    IngredientAmountPickerView(
        ingredient: RecipeIngredientDraft(
            name: "Tomato",
            brand: nil,
            portionGrams: 100,
            caloriesPer100g: 18,
            proteinPer100g: 0.9,
            carbsPer100g: 3.9,
            fatPer100g: 0.2,
            sortOrder: 0
        ),
        onSave: { _ in }
    )
}
