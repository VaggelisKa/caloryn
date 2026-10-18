import Foundation

struct HistoryAnalyticsRefreshID: Equatable {
    let dayStart: Date
    let profile: HistoryProfileSignature?
    let entries: [HistoryEntrySignature]
    let goalSnapshots: [HistoryGoalSnapshotSignature]
}

struct HistoryGoalSnapshotSignature: Equatable {
    let dayKey: String
    let effectiveCalorieTarget: Int
    let updatedAt: Date

    init(snapshot: DailyGoalSnapshot) {
        dayKey = snapshot.dayKey
        effectiveCalorieTarget = snapshot.effectiveCalorieTarget
        updatedAt = snapshot.updatedAt
    }
}

struct HistoryProfileSignature: Equatable {
    let id: UUID
    let updatedAt: Date
    let dailyCalorieTarget: Int
    let proteinTargetG: Double
    let carbTargetG: Double
    let fatTargetG: Double
    let proteinGoalKindRaw: String
    let carbGoalKindRaw: String
    let fatGoalKindRaw: String

    init(profile: UserProfile) {
        id = profile.id
        updatedAt = profile.updatedAt
        dailyCalorieTarget = profile.dailyCalorieTarget
        proteinTargetG = profile.proteinTargetG
        carbTargetG = profile.carbTargetG
        fatTargetG = profile.fatTargetG
        proteinGoalKindRaw = profile.proteinGoalKindRaw
        carbGoalKindRaw = profile.carbGoalKindRaw
        fatGoalKindRaw = profile.fatGoalKindRaw
    }
}

struct HistoryEntrySignature: Equatable {
    let id: UUID
    let date: Date
    let mealTypeRaw: String
    let snackIndex: Int
    let foodName: String
    let portionGrams: Double
    let calories: Double
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let fiberG: Double
    let sugarsG: Double?
    let addedSugarsG: Double?
    let saturatedFatG: Double?
    let sodiumG: Double?
    let cholesterolG: Double?
    let alcoholG: Double?
    let nutriscoreGrade: String?
    let produceKindRaw: String?
    let produceItemsSnapshotRaw: String?
    let legacyProduceName: String?
    let legacyRecipeIngredients: [LegacyIngredient]?

    struct LegacyIngredient: Equatable {
        let name: String
        let produceKindRaw: String?
        let portionGrams: Double
    }

    init(entry: FoodLogEntry) {
        id = entry.id
        date = entry.date
        mealTypeRaw = entry.mealType.rawValue
        snackIndex = entry.snackIndex
        foodName = entry.historicalFoodName
        portionGrams = entry.portionGrams
        calories = entry.calories
        proteinG = entry.proteinG
        carbsG = entry.carbsG
        fatG = entry.fatG
        fiberG = entry.fiberG
        sugarsG = entry.sugarsG
        addedSugarsG = entry.addedSugarsG
        saturatedFatG = entry.saturatedFatG
        sodiumG = entry.sodiumG
        cholesterolG = entry.cholesterolG
        alcoholG = entry.alcoholG
        nutriscoreGrade = entry.historicalNutriscoreGrade
        produceKindRaw = entry.historicalProduceKind?.rawValue
        produceItemsSnapshotRaw = entry.produceItemsSnapshotRaw
        let legacyFood = entry.hasQualitySnapshot ? nil : entry.foodItem
        legacyProduceName = legacyFood?.name
        legacyRecipeIngredients = legacyFood.flatMap { food in
            guard food.isRecipe else { return nil }
            return food.recipeIngredients?.map {
                LegacyIngredient(name: $0.name, produceKindRaw: $0.produceKindRaw, portionGrams: $0.portionGrams)
            }
        }
    }
}
