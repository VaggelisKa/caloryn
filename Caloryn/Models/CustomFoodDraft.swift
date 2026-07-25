import Foundation

/// The editable state of the manual-food form, and every rule that acts on it.
///
/// The form's real work is arithmetic and bookkeeping: parse thirteen text
/// fields written in per-serving terms, convert them to the per-100g values the
/// store keeps, decide what may be saved, and track which fields the user
/// actually touched so barcode recovery knows what came from a person rather
/// than a provider. All of that lives here so it is reachable without a form.
struct CustomFoodDraft: Equatable {
    /// Every text field on the form. Ordered as they appear so focus advances
    /// naturally.
    enum Field: Hashable, CaseIterable {
        case name, brand, calories, protein, carbs, fat, fiber
        case sugars, addedSugars, saturatedFat, sodium, cholesterol, alcohol
        case servingSize
    }

    /// The serving used when the field is blank or unusable, matching how a
    /// nutrition label with no stated serving is conventionally read.
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

    /// The values the form opened with, so an edit can be told apart from a
    /// field that merely has content. Empty for a new food.
    private(set) var initialTextByField: [Field: String] = [:]
    private(set) var initialProduceKind: ProduceKind?

    init() {}

    // MARK: - Field access

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

    /// The recovery field a form field corresponds to, used when reporting
    /// which values a person supplied.
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

    // MARK: - Parsing

    /// Parses decimal strings accepting both "." and "," as the separator, so
    /// the form behaves the same regardless of which the keyboard produces.
    static func parseDecimal(_ string: String) -> Double? {
        let normalized = string
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    /// Blank is allowed — it means the nutrient was not stated — but anything
    /// present must parse to a non-negative number.
    static func isOptionalNonnegativeDecimal(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return true }
        return (parseDecimal(trimmed) ?? -1) >= 0
    }

    // MARK: - Derived values

    var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    var trimmedBrand: String? {
        brand.isEmpty ? nil : brand.trimmingCharacters(in: .whitespaces)
    }

    var servingGrams: Double {
        Self.parseDecimal(servingSizeGrams) ?? Self.fallbackServingGrams
    }

    /// The serving the saved food is stored against. A zero or negative serving
    /// would make the per-100g conversion meaningless, so it falls back.
    var effectiveServingGrams: Double {
        servingGrams > 0 ? servingGrams : Self.fallbackServingGrams
    }

    var previewCalories: Double { Self.parseDecimal(caloriesPerServing) ?? 0 }
    var previewProtein: Double { Self.parseDecimal(proteinPerServing) ?? 0 }
    var previewCarbs: Double { Self.parseDecimal(carbsPerServing) ?? 0 }
    var previewFat: Double { Self.parseDecimal(fatPerServing) ?? 0 }

    /// Distinguished from `previewProtein` because a blank macro means "not
    /// stated" when saving, which the store records differently from a zero.
    var suppliedProtein: Double? { Self.parseDecimal(proteinPerServing) }
    var suppliedCarbohydrates: Double? { Self.parseDecimal(carbsPerServing) }
    var suppliedFat: Double? { Self.parseDecimal(fatPerServing) }
    var suppliedFiber: Double? { Self.parseDecimal(fiberPerServing) }

    /// The serving size to store, or nil when the field does not name a usable
    /// one — distinct from `effectiveServingGrams`, which always has a value.
    var storedServingGrams: Double? {
        Self.parseDecimal(servingSizeGrams).flatMap { $0 > 0 ? $0 : nil }
    }

    // MARK: - Validation

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

    /// A food needs a name and a stated, non-negative calorie figure. Every
    /// other nutrient is optional.
    var canSave: Bool {
        !trimmedName.isEmpty
        && !caloriesPerServing.isEmpty
        && (Self.parseDecimal(caloriesPerServing) ?? -1) >= 0
        && optionalTrackedInputsAreValid
    }

    // MARK: - Nutrition

    var nutritionPerServing: NutritionValues {
        NutritionValues(
            calories: Self.parseDecimal(caloriesPerServing) ?? 0,
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

    /// Scales a per-serving macro to per-100g while preserving nil, so a macro
    /// the user never stated does not become a zero.
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
        guard !trimmed.isEmpty, let inputValue = Self.parseDecimal(trimmed) else { return nil }
        return unit.storedValue(fromInput: inputValue)
    }

    // MARK: - Provenance

    /// Which fields carry a person's own values.
    ///
    /// For a new food that is every field with content. For an edit it is only
    /// what changed, so reopening a form and saving it untouched does not claim
    /// the provider's numbers as the user's.
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

    // MARK: - Loading an existing food

    /// Fills the form from a saved food and records the starting values so the
    /// edit check above has something to compare against.
    mutating func populate(from food: FoodItem) {
        let serving = food.defaultServingG ?? Self.fallbackServingGrams

        name = food.name
        brand = food.brand ?? ""
        servingSizeGrams = food.defaultServingG.map(\.manualInputFormatted) ?? ""
        caloriesPerServing = "\(Int(food.calories(forGrams: serving)))"
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

    /// A macro the provider never supplied is shown blank rather than as zero,
    /// so the user can tell "not stated" from "none".
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

    // MARK: - Building a personal edit

    /// The payload barcode recovery needs to materialise a personal food.
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
    /// Renders a value the way the manual form expects it typed back: one
    /// decimal place at most, and no trailing ".0".
    var manualInputFormatted: String {
        let rounded = (self * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return "\(Int(rounded))"
        }
        return String(format: "%.1f", rounded)
    }
}
