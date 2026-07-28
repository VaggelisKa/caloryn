import Foundation

/// One item on the meal form: a food, recipe, or manual entry captured as a
/// snapshot so the meal keeps working even if the source food is later edited
/// or removed.
struct MealComponentDraft: Identifiable, Equatable {
    let id: UUID
    var snapshot: FoodLogEntrySnapshot

    init(id: UUID = UUID(), foodItem: FoodItem) {
        self.id = id
        snapshot = FoodLogEntrySnapshot(
            foodItem: foodItem,
            portionGrams: foodItem.defaultServingG ?? 100
        )
    }

    /// Rehydrates a component from a saved meal's item. Fails when the stored
    /// snapshot can't be decoded, which the caller drops via `compactMap`
    /// rather than surfacing as an error.
    init?(item: MealTemplateItem) {
        guard let data = item.snapshotData,
              let snapshot = try? JSONDecoder().decode(FoodLogEntrySnapshot.self, from: data) else {
            return nil
        }
        id = item.id
        self.snapshot = snapshot
    }

    /// The facts the amount picker needs, expressed per 100g so the picker's
    /// own scaling stays independent of whatever portion this component
    /// currently holds.
    var amountDraft: RecipeIngredientDraft {
        let portionGrams = snapshot.portionGrams
        let nutritionPer100g = portionGrams > 0
            ? snapshot.nutrition.scaled(by: 100 / portionGrams)
            : .zero

        return RecipeIngredientDraft(
            id: id,
            name: snapshot.foodName,
            brand: nil,
            portionGrams: portionGrams,
            caloriesPer100g: nutritionPer100g.calories,
            proteinPer100g: nutritionPer100g.proteinG,
            carbsPer100g: nutritionPer100g.carbsG,
            fatPer100g: nutritionPer100g.fatG,
            fiberPer100g: nutritionPer100g.fiberG,
            sugarsPer100g: nutritionPer100g.sugarsG,
            addedSugarsPer100g: nutritionPer100g.addedSugarsG,
            sucrosePer100g: nutritionPer100g.sucroseG,
            glucosePer100g: nutritionPer100g.glucoseG,
            fructosePer100g: nutritionPer100g.fructoseG,
            lactosePer100g: nutritionPer100g.lactoseG,
            maltosePer100g: nutritionPer100g.maltoseG,
            maltodextrinsPer100g: nutritionPer100g.maltodextrinsG,
            starchPer100g: nutritionPer100g.starchG,
            polyolsPer100g: nutritionPer100g.polyolsG,
            saturatedFatPer100g: nutritionPer100g.saturatedFatG,
            transFatPer100g: nutritionPer100g.transFatG,
            monounsaturatedFatPer100g: nutritionPer100g.monounsaturatedFatG,
            polyunsaturatedFatPer100g: nutritionPer100g.polyunsaturatedFatG,
            omega3FatPer100g: nutritionPer100g.omega3FatG,
            omega6FatPer100g: nutritionPer100g.omega6FatG,
            omega9FatPer100g: nutritionPer100g.omega9FatG,
            saltPer100g: nutritionPer100g.saltG,
            sodiumPer100g: nutritionPer100g.sodiumG,
            cholesterolPer100g: nutritionPer100g.cholesterolG,
            solubleFiberPer100g: nutritionPer100g.solubleFiberG,
            insolubleFiberPer100g: nutritionPer100g.insolubleFiberG,
            caseinPer100g: nutritionPer100g.caseinG,
            serumProteinsPer100g: nutritionPer100g.serumProteinsG,
            alcoholPer100g: nutritionPer100g.alcoholG,
            sortOrder: 0,
            produceKind: ProduceKind(rawValue: snapshot.produceKindSnapshotRaw ?? "")
                ?? .unclassified
        )
    }

    func updatingPortion(to grams: Double) -> MealComponentDraft {
        var copy = self
        copy.snapshot = snapshot.scaled(toPortionGrams: grams)
        return copy
    }
}

/// The editable state of the meal form, and every rule that acts on it.
///
/// The form's job is bookkeeping over a list of components: seed it from an
/// existing meal, add/replace/remove items, total their nutrition, and decide
/// whether the result may be saved. Keeping that here rather than in
/// `MealFormView` means the rules are reachable without driving a form.
struct MealFormDraft: Equatable {
    var name = ""
    var components: [MealComponentDraft] = []

    init() {}

    /// Seeds the draft from a saved meal. Items whose snapshot fails to
    /// decode are silently dropped, matching `MealComponentDraft.init(item:)`.
    @MainActor
    init(existingMeal: MealTemplate) {
        name = existingMeal.name
        components = existingMeal.sortedItems.compactMap(MealComponentDraft.init(item:))
    }

    var totalNutrition: NutritionValues {
        components.reduce(.zero) { $0 + $1.snapshot.nutrition }
    }

    /// A meal needs a non-blank name and at least one component, each with a
    /// positive portion.
    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !components.isEmpty
            && components.allSatisfy { $0.snapshot.portionGrams > 0 }
    }

    /// Replaces the component with a matching id, or appends it as new.
    mutating func upsert(_ component: MealComponentDraft) {
        if let index = components.firstIndex(where: { $0.id == component.id }) {
            components[index] = component
        } else {
            components.append(component)
        }
    }

    mutating func delete(_ component: MealComponentDraft) {
        components.removeAll { $0.id == component.id }
    }
}
