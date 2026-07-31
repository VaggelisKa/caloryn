import Foundation

/// Equality key for History's expensive analytics recompute.
///
/// `HistoryView` hands this value to `.task(id:)`: analytics rerun exactly when
/// the value changes and never otherwise. The signatures below therefore have
/// to capture every fact the analytics render. A field missing from a signature
/// does not fail loudly — History just keeps showing stale numbers after that
/// field changes, which is why each captured field is pinned by a unit test.
struct HistoryAnalyticsRefreshID: Equatable {
    let dayStart: Date
    let profile: HistoryProfileSignature?
    let entries: [HistoryEntrySignature]
    let goalSnapshots: [HistoryGoalSnapshotSignature]
}

/// The facts of a `DailyGoalSnapshot` that History's per-day targets depend on.
/// `updatedAt` stands in for the remaining snapshot values: every upsert that
/// changes a day's values also rewrites `updatedAt`.
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

/// The facts of a `UserProfile` that History's fallback target and macro
/// patterns depend on.
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

/// The facts of a `FoodLogEntry` that History's summaries, patterns and quality
/// charts depend on. Quality fields go through the `historical*` reads so a
/// legacy entry's live-food fallback is re-evaluated on every comparison.
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

    init(entry: FoodLogEntry) {
        id = entry.id
        date = entry.date
        mealTypeRaw = entry.mealType.rawValue
        snackIndex = entry.snackIndex
        foodName = entry.foodName
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
    }
}
