import Foundation

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

    init?(item: MealTemplateItem) {
        guard let data = item.snapshotData,
              let snapshot = try? JSONDecoder().decode(FoodLogEntrySnapshot.self, from: data) else {
            return nil
        }
        id = item.id
        self.snapshot = snapshot
    }

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

struct MealFormDraft: Equatable {
    var name = ""
    var components: [MealComponentDraft] = []

    init() {}

    @MainActor
    init(existingMeal: MealTemplate) {
        name = existingMeal.name
        components = existingMeal.sortedItems.compactMap(MealComponentDraft.init(item:))
    }

    var totalNutrition: NutritionValues {
        components.reduce(.zero) { $0 + $1.snapshot.nutrition }
    }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !components.isEmpty
            && components.allSatisfy { $0.snapshot.portionGrams > 0 }
    }

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
