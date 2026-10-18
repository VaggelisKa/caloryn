import Foundation
import SwiftData

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
    var lookupProviderSnapshotRaw: String?
    var dataSourceSnapshotRaw: String?
    var nutritionCompletenessSnapshotRaw: String?
    var recoveredByFallbackSnapshotRaw: Bool?

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
        lookupProviderSnapshotRaw = entry.lookupProviderSnapshotRaw
        dataSourceSnapshotRaw = entry.dataSourceSnapshotRaw
        nutritionCompletenessSnapshotRaw = entry.nutritionCompletenessSnapshotRaw
        recoveredByFallbackSnapshotRaw = entry.recoveredByFallbackSnapshotRaw
    }

    init(
        foodItem: FoodItem,
        portionGrams: Double,
        mealType: MealType = .breakfast,
        snackIndex: Int = 0
    ) {
        sourceFoodID = foodItem.id
        self.mealType = mealType
        self.snackIndex = DailyFoodLogCommands.normalizedSnackIndex(
            for: mealType,
            requestedSnackIndex: snackIndex
        )
        foodName = foodItem.name
        self.portionGrams = portionGrams
        nutrition = foodItem.nutrition(forGrams: portionGrams)
        nutriscoreGradeSnapshot = foodItem.nutriscoreGrade
        produceKindSnapshotRaw = foodItem.produceKind.rawValue
        let provenance = foodItem.provenance
        lookupProviderSnapshotRaw = provenance.provider?.rawValue
        dataSourceSnapshotRaw = provenance.source.rawValue
        nutritionCompletenessSnapshotRaw = provenance.completeness.rawValue
        recoveredByFallbackSnapshotRaw = provenance.recoveredByFallback

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

    var nutriscoreGradeSnapshot: String?
    var produceKindSnapshotRaw: String?
    var produceItemsSnapshotRaw: String?

    var lookupProviderSnapshotRaw: String?
    var dataSourceSnapshotRaw: String?
    var nutritionCompletenessSnapshotRaw: String?
    var recoveredByFallbackSnapshotRaw: Bool?

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
        self.date = date.startOfDay
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
        lookupProviderSnapshotRaw = snapshot.lookupProviderSnapshotRaw
        dataSourceSnapshotRaw = snapshot.dataSourceSnapshotRaw
        nutritionCompletenessSnapshotRaw = snapshot.nutritionCompletenessSnapshotRaw
        recoveredByFallbackSnapshotRaw = snapshot.recoveredByFallbackSnapshotRaw
    }

    func updateFromSnapshot(
        date: Date,
        mealType: MealType,
        portionGrams: Double,
        snackIndex: Int = 1
    ) {
        let scaledSnapshot = FoodLogEntrySnapshot(entry: self)
            .scaled(toPortionGrams: portionGrams)
        self.date = date.startOfDay
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
        self.date = date.startOfDay
        self.mealType = mealType
        self.snackIndex = mealType == .snack ? snackIndex : 0
        self.foodItem = foodItem
        self.portionGrams = portionGrams
        let nutrition = foodItem.nutrition(forGrams: portionGrams)
        apply(nutrition: nutrition)
        self.foodName = foodItem.name
        snapshotQuality(from: foodItem)
        snapshotProvenance(from: foodItem)
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

    private func snapshotProvenance(from foodItem: FoodItem) {
        let provenance = foodItem.provenance
        lookupProviderSnapshotRaw = provenance.provider?.rawValue
        dataSourceSnapshotRaw = provenance.source.rawValue
        nutritionCompletenessSnapshotRaw = provenance.completeness.rawValue
        recoveredByFallbackSnapshotRaw = provenance.recoveredByFallback
    }

    var hasQualitySnapshot: Bool {
        produceKindSnapshotRaw != nil
    }

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

    var historicalFoodName: String {
        let storedName = foodName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !storedName.isEmpty { return storedName }

        let liveName = foodItem?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return liveName.isEmpty ? "Unnamed food" : liveName
    }

    var historicalNutriscoreGrade: String? {
        hasQualitySnapshot ? nutriscoreGradeSnapshot : foodItem?.nutriscoreGrade
    }

    var historicalProduceKind: ProduceKind? {
        hasQualitySnapshot ? produceKindSnapshot : foodItem?.produceKind
    }

    var hasProvenanceSnapshot: Bool {
        dataSourceSnapshotRaw != nil || nutritionCompletenessSnapshotRaw != nil
    }

    var historicalProvenance: FoodProvenance {
        if hasProvenanceSnapshot {
            return FoodProvenance(
                provider: lookupProviderSnapshotRaw.flatMap(FoodSearchProvider.init(rawValue:)),
                source: dataSourceSnapshotRaw.flatMap(FoodDataSource.init(rawValue:)) ?? .unknown,
                completeness: nutritionCompletenessSnapshotRaw.flatMap(NutritionCompleteness.init(rawValue:)) ?? .unknown,
                recoveredByFallback: recoveredByFallbackSnapshotRaw ?? false
            )
        }
        return .unknown
    }
}
