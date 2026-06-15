import Foundation
@testable import Caloryn

nonisolated func makeTestDate(
    year: Int,
    month: Int,
    day: Int,
    hour: Int = 12,
    minute: Int = 0
) -> Date {
    var components = DateComponents()
    components.calendar = Calendar.current
    components.timeZone = Calendar.current.timeZone
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    return components.date!
}

@MainActor
func makeTestFoodItem(
    name: String = "Test Food",
    brand: String? = nil,
    caloriesPer100g: Double = 100,
    proteinPer100g: Double = 10,
    carbsPer100g: Double = 20,
    fatPer100g: Double = 5,
    fiberPer100g: Double = 0,
    sugarsPer100g: Double? = nil,
    addedSugarsPer100g: Double? = nil,
    saturatedFatPer100g: Double? = nil,
    sodiumPer100g: Double? = nil,
    cholesterolPer100g: Double? = nil,
    alcoholPer100g: Double? = nil,
    defaultServingG: Double? = nil,
    servingDescription: String? = nil,
    nutriscoreGrade: String? = nil,
    categoryTags: [String] = [],
    produceKind: ProduceKind? = nil,
    isCustom: Bool = false,
    isRecipe: Bool = false
) -> FoodItem {
    FoodItem(
        name: name,
        brand: brand,
        caloriesPer100g: caloriesPer100g,
        proteinPer100g: proteinPer100g,
        carbsPer100g: carbsPer100g,
        fatPer100g: fatPer100g,
        fiberPer100g: fiberPer100g,
        sugarsPer100g: sugarsPer100g,
        addedSugarsPer100g: addedSugarsPer100g,
        saturatedFatPer100g: saturatedFatPer100g,
        sodiumPer100g: sodiumPer100g,
        cholesterolPer100g: cholesterolPer100g,
        alcoholPer100g: alcoholPer100g,
        defaultServingG: defaultServingG,
        servingDescription: servingDescription,
        nutriscoreGrade: nutriscoreGrade,
        categoryTags: categoryTags,
        produceKind: produceKind,
        isCustom: isCustom,
        isRecipe: isRecipe
    )
}

@MainActor
func makeTestEntry(
    date: Date = makeTestDate(year: 2026, month: 1, day: 1),
    mealType: MealType = .breakfast,
    foodItem: FoodItem,
    portionGrams: Double = 100,
    snackIndex: Int = 1
) -> FoodLogEntry {
    FoodLogEntry(
        date: date,
        mealType: mealType,
        foodItem: foodItem,
        portionGrams: portionGrams,
        snackIndex: snackIndex
    )
}

@MainActor
func makeTestEntry(
    date: Date = makeTestDate(year: 2026, month: 1, day: 1),
    mealType: MealType = .breakfast,
    portionGrams: Double = 100,
    snackIndex: Int = 1
) -> FoodLogEntry {
    makeTestEntry(
        date: date,
        mealType: mealType,
        foodItem: makeTestFoodItem(),
        portionGrams: portionGrams,
        snackIndex: snackIndex
    )
}
