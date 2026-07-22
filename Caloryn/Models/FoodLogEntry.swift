import Foundation
import SwiftData

/// A produce-counting item captured from a recipe's ingredients when a recipe
/// entry is logged, so History keeps counting the ingredients' fruit/vegetable
/// variety even after the recipe is edited or deleted.
struct FoodLogProduceItemSnapshot: Codable, Equatable {
    var name: String
    var kindRaw: String

    init(name: String, kind: ProduceKind) {
        self.name = name
        self.kindRaw = kind.rawValue
    }

    var kind: ProduceKind {
        ProduceKind(rawValue: kindRaw) ?? .unclassified
    }
}

@Model
final class FoodLogEntry {
    var id: UUID = UUID()
    var date: Date = Date()
    var mealType: MealType = MealType.breakfast
    var snackIndex: Int = 0

    var foodItem: FoodItem?

    var portionGrams: Double = 0
    var calories: Double = 0
    var proteinG: Double = 0
    var carbsG: Double = 0
    var fatG: Double = 0
    var fiberG: Double = 0
    var sugarsG: Double?
    var addedSugarsG: Double?
    var sucroseG: Double?
    var glucoseG: Double?
    var fructoseG: Double?
    var lactoseG: Double?
    var maltoseG: Double?
    var maltodextrinsG: Double?
    var starchG: Double?
    var polyolsG: Double?
    var saturatedFatG: Double?
    var transFatG: Double?
    var monounsaturatedFatG: Double?
    var polyunsaturatedFatG: Double?
    var omega3FatG: Double?
    var omega6FatG: Double?
    var omega9FatG: Double?
    var saltG: Double?
    var sodiumG: Double?
    var cholesterolG: Double?
    var solubleFiberG: Double?
    var insolubleFiberG: Double?
    var caseinG: Double?
    var serumProteinsG: Double?
    var alcoholG: Double?

    var foodName: String = ""
    var createdAt: Date = Date()

    // MARK: Food-quality snapshot (issue #71)
    //
    // Nutri-Score and produce classification are captured on the entry at
    // create/update time so History remains accurate after the saved food is
    // edited or deleted.
    //
    // Migration/fallback for legacy entries (created before these fields
    // existed): lightweight migration leaves all three fields nil.
    // `produceKindSnapshotRaw == nil` unambiguously marks a legacy entry,
    // because every snapshot writes at least "unclassified". Legacy entries
    // fall back to the live saved-food relationship (the pre-snapshot
    // behavior) and surface no quality data once that relationship is gone —
    // values are never fabricated.

    /// Nutri-Score grade ("a"–"e") of the food at logging time. On a
    /// snapshotted entry, nil means the food genuinely had no grade.
    var nutriscoreGradeSnapshot: String?
    /// `ProduceKind` raw value at logging time; nil only on legacy entries.
    var produceKindSnapshotRaw: String?
    /// JSON-encoded `[FoodLogProduceItemSnapshot]` captured from recipe
    /// ingredients; nil for non-recipe entries and legacy entries.
    var produceItemsSnapshotRaw: String?

    init(
        date: Date,
        mealType: MealType,
        foodItem: FoodItem,
        portionGrams: Double,
        snackIndex: Int = 1
    ) {
        self.id = UUID()
        self.createdAt = Date()
        update(
            date: date,
            mealType: mealType,
            foodItem: foodItem,
            portionGrams: portionGrams,
            snackIndex: snackIndex
        )
    }

    func update(
        date: Date,
        mealType: MealType,
        foodItem: FoodItem,
        portionGrams: Double,
        snackIndex: Int = 1
    ) {
        self.date = Calendar.current.startOfDay(for: date)
        self.mealType = mealType
        self.snackIndex = mealType == .snack ? snackIndex : 0
        self.foodItem = foodItem
        self.portionGrams = portionGrams
        let nutrition = foodItem.nutrition(forGrams: portionGrams)
        self.calories = nutrition.calories
        self.proteinG = nutrition.proteinG
        self.carbsG = nutrition.carbsG
        self.fatG = nutrition.fatG
        self.fiberG = nutrition.fiberG
        self.sugarsG = nutrition.sugarsG
        self.addedSugarsG = nutrition.addedSugarsG
        self.sucroseG = nutrition.sucroseG
        self.glucoseG = nutrition.glucoseG
        self.fructoseG = nutrition.fructoseG
        self.lactoseG = nutrition.lactoseG
        self.maltoseG = nutrition.maltoseG
        self.maltodextrinsG = nutrition.maltodextrinsG
        self.starchG = nutrition.starchG
        self.polyolsG = nutrition.polyolsG
        self.saturatedFatG = nutrition.saturatedFatG
        self.transFatG = nutrition.transFatG
        self.monounsaturatedFatG = nutrition.monounsaturatedFatG
        self.polyunsaturatedFatG = nutrition.polyunsaturatedFatG
        self.omega3FatG = nutrition.omega3FatG
        self.omega6FatG = nutrition.omega6FatG
        self.omega9FatG = nutrition.omega9FatG
        self.saltG = nutrition.saltG
        self.sodiumG = nutrition.sodiumG
        self.cholesterolG = nutrition.cholesterolG
        self.solubleFiberG = nutrition.solubleFiberG
        self.insolubleFiberG = nutrition.insolubleFiberG
        self.caseinG = nutrition.caseinG
        self.serumProteinsG = nutrition.serumProteinsG
        self.alcoholG = nutrition.alcoholG
        self.foodName = foodItem.name
        snapshotQuality(from: foodItem)
    }

    private func snapshotQuality(from foodItem: FoodItem) {
        nutriscoreGradeSnapshot = foodItem.nutriscoreGrade
        produceKindSnapshotRaw = foodItem.produceKind.rawValue

        if foodItem.isRecipe,
           let ingredients = foodItem.recipeIngredients,
           !ingredients.isEmpty {
            produceItemsSnapshot = ingredients
                .filter { $0.portionGrams > 0 }
                .sorted { $0.sortOrder < $1.sortOrder }
                .map { FoodLogProduceItemSnapshot(name: $0.name, kind: $0.produceKind) }
        } else {
            produceItemsSnapshot = nil
        }
    }

    /// True when this entry carries a quality snapshot. False only for legacy
    /// entries created before quality snapshots existed.
    var hasQualitySnapshot: Bool {
        produceKindSnapshotRaw != nil
    }

    /// Snapshotted produce classification; nil only on legacy entries.
    var produceKindSnapshot: ProduceKind? {
        guard let raw = produceKindSnapshotRaw else { return nil }
        return ProduceKind(rawValue: raw) ?? .unclassified
    }

    var produceItemsSnapshot: [FoodLogProduceItemSnapshot]? {
        get {
            guard let raw = produceItemsSnapshotRaw,
                  let data = raw.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode([FoodLogProduceItemSnapshot].self, from: data)
        }
        set {
            guard let newValue,
                  let data = try? JSONEncoder().encode(newValue) else {
                produceItemsSnapshotRaw = nil
                return
            }
            produceItemsSnapshotRaw = String(decoding: data, as: UTF8.self)
        }
    }

    /// Nutri-Score grade for historical reads: the snapshot when available;
    /// legacy entries fall back to the live saved-food relationship and
    /// report nil (unknown) once that food is gone.
    var historicalNutriscoreGrade: String? {
        hasQualitySnapshot ? nutriscoreGradeSnapshot : foodItem?.nutriscoreGrade
    }

    /// Produce classification for historical reads: the snapshot when
    /// available; legacy entries fall back to the live saved-food
    /// relationship. nil means unknown (legacy entry whose food is gone),
    /// which is distinct from a known `.unclassified` value.
    var historicalProduceKind: ProduceKind? {
        hasQualitySnapshot ? produceKindSnapshot : foodItem?.produceKind
    }
}
