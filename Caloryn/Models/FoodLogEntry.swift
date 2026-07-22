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

/// The complete, reusable payload of a logged food entry.
///
/// Copy and template flows must use this payload instead of recalculating from
/// a live `FoodItem`. A saved food can change or disappear after logging, while
/// the nutrition and quality values recorded in the log must remain stable.
struct FoodLogEntrySnapshot: Codable, Equatable {
    var sourceFoodID: UUID?
    var mealType: MealType
    var snackIndex: Int
    var foodName: String
    var portionGrams: Double
    var nutrition: NutritionValues
    var nutriscoreGradeSnapshot: String?
    var produceKindSnapshotRaw: String?
    var produceItemsSnapshot: [FoodLogProduceItemSnapshot]?

    init(entry: FoodLogEntry) {
        sourceFoodID = entry.foodItem?.id
        mealType = entry.mealType
        snackIndex = entry.snackIndex
        foodName = entry.foodName
        portionGrams = entry.portionGrams
        nutrition = entry.nutrition
        nutriscoreGradeSnapshot = entry.nutriscoreGradeSnapshot
        produceKindSnapshotRaw = entry.produceKindSnapshotRaw
        produceItemsSnapshot = entry.produceItemsSnapshot
    }

    func scaled(toPortionGrams newPortionGrams: Double) -> FoodLogEntrySnapshot {
        guard portionGrams > 0 else { return self }
        var copy = self
        copy.portionGrams = newPortionGrams
        copy.nutrition = nutrition.scaled(by: newPortionGrams / portionGrams)
        return copy
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
    var replicationOperationID: UUID?
    var replicationItemIndex: Int?
    var replicationPlanFingerprint: String?

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

    /// Creates a normal editable log entry from an immutable logged snapshot.
    /// The live food relationship is retained when available, but it is never
    /// used to recalculate the recorded nutrition or quality values.
    init(
        date: Date,
        mealType: MealType,
        foodItem: FoodItem?,
        snapshot: FoodLogEntrySnapshot,
        snackIndex: Int,
        createdAt: Date = Date(),
        replicationOperationID: UUID? = nil,
        replicationItemIndex: Int? = nil,
        replicationPlanFingerprint: String? = nil
    ) {
        id = UUID()
        self.createdAt = createdAt
        self.date = Calendar.current.startOfDay(for: date)
        self.mealType = mealType
        self.snackIndex = mealType == .snack ? snackIndex : 0
        self.foodItem = foodItem
        self.replicationOperationID = replicationOperationID
        self.replicationItemIndex = replicationItemIndex
        self.replicationPlanFingerprint = replicationPlanFingerprint
        portionGrams = snapshot.portionGrams
        foodName = snapshot.foodName
        apply(nutrition: snapshot.nutrition)
        nutriscoreGradeSnapshot = snapshot.nutriscoreGradeSnapshot
        produceKindSnapshotRaw = snapshot.produceKindSnapshotRaw
        produceItemsSnapshot = snapshot.produceItemsSnapshot
    }

    func updateFromSnapshot(
        date: Date,
        mealType: MealType,
        portionGrams: Double,
        snackIndex: Int = 1
    ) {
        let scaledSnapshot = FoodLogEntrySnapshot(entry: self)
            .scaled(toPortionGrams: portionGrams)
        self.date = Calendar.current.startOfDay(for: date)
        self.mealType = mealType
        self.snackIndex = mealType == .snack ? snackIndex : 0
        self.portionGrams = scaledSnapshot.portionGrams
        apply(nutrition: scaledSnapshot.nutrition)
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
        apply(nutrition: nutrition)
        self.foodName = foodItem.name
        snapshotQuality(from: foodItem)
    }

    private func apply(nutrition: NutritionValues) {
        calories = nutrition.calories
        proteinG = nutrition.proteinG
        carbsG = nutrition.carbsG
        fatG = nutrition.fatG
        fiberG = nutrition.fiberG
        sugarsG = nutrition.sugarsG
        addedSugarsG = nutrition.addedSugarsG
        sucroseG = nutrition.sucroseG
        glucoseG = nutrition.glucoseG
        fructoseG = nutrition.fructoseG
        lactoseG = nutrition.lactoseG
        maltoseG = nutrition.maltoseG
        maltodextrinsG = nutrition.maltodextrinsG
        starchG = nutrition.starchG
        polyolsG = nutrition.polyolsG
        saturatedFatG = nutrition.saturatedFatG
        transFatG = nutrition.transFatG
        monounsaturatedFatG = nutrition.monounsaturatedFatG
        polyunsaturatedFatG = nutrition.polyunsaturatedFatG
        omega3FatG = nutrition.omega3FatG
        omega6FatG = nutrition.omega6FatG
        omega9FatG = nutrition.omega9FatG
        saltG = nutrition.saltG
        sodiumG = nutrition.sodiumG
        cholesterolG = nutrition.cholesterolG
        solubleFiberG = nutrition.solubleFiberG
        insolubleFiberG = nutrition.insolubleFiberG
        caseinG = nutrition.caseinG
        serumProteinsG = nutrition.serumProteinsG
        alcoholG = nutrition.alcoholG
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
