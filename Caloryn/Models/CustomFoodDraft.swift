import Foundation

struct CustomFoodDraft: Equatable {
    enum Field: Hashable, CaseIterable {
        case name, brand, calories, protein, carbs, fat, fiber
        case sugars, addedSugars, saturatedFat, sodium, cholesterol, alcohol
        case servingSize
    }

    static let fallbackServingGrams: Double = 100

    var name = ""
    var brand = ""
    var caloriesPerServing = ""
    var proteinPerServing = ""
    var carbsPerServing = ""
    var fatPerServing = ""
    var fiberPerServing = ""
    var sugarsPerServing = ""
    var addedSugarsPerServing = ""
    var saturatedFatPerServing = ""
    var sodiumPerServing = ""
    var cholesterolPerServing = ""
    var alcoholPerServing = ""
    var servingSizeGrams = "100"
    var produceKind: ProduceKind = .unclassified

    private(set) var initialTextByField: [Field: String] = [:]
    private(set) var initialProduceKind: ProduceKind?

    init() {}

    func text(for field: Field) -> String {
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

    static func recoveryField(for field: Field) -> FoodField {
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

    static func isOptionalNonnegativeDecimal(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return true }
        return (trimmed.decimalInputValue ?? -1) >= 0
    }

    var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    var trimmedBrand: String? {
        brand.isEmpty ? nil : brand.trimmingCharacters(in: .whitespaces)
    }

    var servingGrams: Double {
        servingSizeGrams.decimalInputValue ?? Self.fallbackServingGrams
    }

    var effectiveServingGrams: Double {
        servingGrams > 0 ? servingGrams : Self.fallbackServingGrams
    }

    var previewCalories: Double { caloriesPerServing.decimalInputValue ?? 0 }

    var suppliedProtein: Double? { proteinPerServing.decimalInputValue }
    var suppliedCarbohydrates: Double? { carbsPerServing.decimalInputValue }
    var suppliedFat: Double? { fatPerServing.decimalInputValue }
    var suppliedFiber: Double? { fiberPerServing.decimalInputValue }

    var storedServingGrams: Double? {
        servingSizeGrams.decimalInputValue.flatMap { $0 > 0 ? $0 : nil }
    }

    var optionalTrackedInputsAreValid: Bool {
        [
            fiberPerServing,
            sugarsPerServing,
            addedSugarsPerServing,
            saturatedFatPerServing,
            sodiumPerServing,
            cholesterolPerServing,
            alcoholPerServing
        ].allSatisfy(Self.isOptionalNonnegativeDecimal(_:))
    }

    var canSave: Bool {
        !trimmedName.isEmpty
        && !caloriesPerServing.isEmpty
        && (caloriesPerServing.decimalInputValue ?? -1) >= 0
        && optionalTrackedInputsAreValid
    }

    var nutritionPerServing: NutritionValues {
        NutritionValues(
            calories: caloriesPerServing.decimalInputValue ?? 0,
            proteinG: suppliedProtein ?? 0,
            carbsG: suppliedCarbohydrates ?? 0,
            fatG: suppliedFat ?? 0,
            fiberG: suppliedFiber ?? 0,
            sugarsG: optionalServingValue(sugarsPerServing),
            addedSugarsG: optionalServingValue(addedSugarsPerServing),
            saturatedFatG: optionalServingValue(saturatedFatPerServing),
            sodiumG: optionalServingValue(sodiumPerServing, unit: .milligramsFromGrams),
            cholesterolG: optionalServingValue(cholesterolPerServing, unit: .milligramsFromGrams),
            alcoholG: optionalServingValue(alcoholPerServing)
        )
    }

    var nutritionPer100g: NutritionValues {
        NutritionValues.per100g(
            fromServing: nutritionPerServing,
            servingGrams: effectiveServingGrams
        )
    }

    private func per100g(_ perServing: Double?) -> Double? {
        perServing.map { $0 * 100 / effectiveServingGrams }
    }

    var proteinPer100g: Double? { per100g(suppliedProtein) }
    var carbohydratesPer100g: Double? { per100g(suppliedCarbohydrates) }
    var fatPer100g: Double? { per100g(suppliedFat) }
    var fiberPer100g: Double? { per100g(suppliedFiber) }

    private func optionalServingValue(
        _ text: String,
        unit: TrackedNutrientUnit = .grams
    ) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let inputValue = trimmed.decimalInputValue else { return nil }
        return unit.storedValue(fromInput: inputValue)
    }

    func userEditedRecoveryFields(isEditingExistingFood: Bool) -> Set<FoodField> {
        guard isEditingExistingFood else {
            var supplied = Set(
                Field.allCases.compactMap { field -> FoodField? in
                    let value = text(for: field).trimmingCharacters(in: .whitespacesAndNewlines)
                    return value.isEmpty ? nil : Self.recoveryField(for: field)
                }
            )
            if produceKind != .unclassified {
                supplied.insert(.produceKind)
            }
            return supplied
        }

        var edited = Set(
            Field.allCases.compactMap { field -> FoodField? in
                guard initialTextByField[field] != text(for: field) else { return nil }
                return Self.recoveryField(for: field)
            }
        )
        if initialProduceKind != produceKind {
            edited.insert(.produceKind)
        }
        return edited
    }

    mutating func populate(from food: FoodItem) {
        let serving = food.defaultServingG ?? Self.fallbackServingGrams

        name = food.name
        brand = food.brand ?? ""
        servingSizeGrams = food.defaultServingG.map(\.manualInputFormatted) ?? ""
        caloriesPerServing = "\(food.calories(forGrams: serving).truncatedSafely)"
        proteinPerServing = Self.editableCoreText(
            food.protein(forGrams: serving),
            origin: food.fieldOrigin(for: .protein)
        )
        carbsPerServing = Self.editableCoreText(
            food.carbs(forGrams: serving),
            origin: food.fieldOrigin(for: .carbohydrates)
        )
        fatPerServing = Self.editableCoreText(
            food.fat(forGrams: serving),
            origin: food.fieldOrigin(for: .fat)
        )
        fiberPerServing = Self.editableCoreText(
            food.fiber(forGrams: serving),
            origin: food.fieldOrigin(for: .fiber)
        )
        sugarsPerServing = Self.optionalPerServingText(food.sugarsPer100g, serving: serving)
        addedSugarsPerServing = Self.optionalPerServingText(food.addedSugarsPer100g, serving: serving)
        saturatedFatPerServing = Self.optionalPerServingText(food.saturatedFatPer100g, serving: serving)
        sodiumPerServing = Self.optionalPerServingText(
            food.sodiumPer100g,
            serving: serving,
            unit: .milligramsFromGrams
        )
        cholesterolPerServing = Self.optionalPerServingText(
            food.cholesterolPer100g,
            serving: serving,
            unit: .milligramsFromGrams
        )
        alcoholPerServing = Self.optionalPerServingText(food.alcoholPer100g, serving: serving)
        produceKind = food.produceKind

        initialTextByField = Dictionary(uniqueKeysWithValues: Field.allCases.map { ($0, text(for: $0)) })
        initialProduceKind = produceKind
    }

    static func editableCoreText(_ value: Double, origin: FoodFieldOrigin) -> String {
        origin == .missing ? "" : value.manualInputFormatted
    }

    static func optionalPerServingText(
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

    func personalEdit(isEditingExistingFood: Bool) -> FoodPersonalEdit {
        let per100g = nutritionPer100g

        return FoodPersonalEdit(
            name: trimmedName,
            brand: trimmedBrand,
            caloriesPer100g: per100g.calories,
            proteinPer100g: proteinPer100g,
            carbohydratesPer100g: carbohydratesPer100g,
            fatPer100g: fatPer100g,
            fiberPer100g: fiberPer100g,
            sugarsPer100g: per100g.sugarsG,
            addedSugarsPer100g: per100g.addedSugarsG,
            saturatedFatPer100g: per100g.saturatedFatG,
            sodiumPer100g: per100g.sodiumG,
            cholesterolPer100g: per100g.cholesterolG,
            alcoholPer100g: per100g.alcoholG,
            defaultServingG: storedServingGrams,
            produceKind: produceKind,
            userEditedFields: userEditedRecoveryFields(isEditingExistingFood: isEditingExistingFood)
        )
    }
}

extension Double {
    var manualInputFormatted: String {
        let rounded = (self * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return "\(rounded.truncatedSafely)"
        }
        return String(format: "%.1f", rounded)
    }
}
