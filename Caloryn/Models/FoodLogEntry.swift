import Foundation
import SwiftData

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
        self.calories = foodItem.calories(forGrams: portionGrams)
        self.proteinG = foodItem.protein(forGrams: portionGrams)
        self.carbsG = foodItem.carbs(forGrams: portionGrams)
        self.fatG = foodItem.fat(forGrams: portionGrams)
        self.fiberG = foodItem.fiber(forGrams: portionGrams)
        self.sugarsG = foodItem.sugars(forGrams: portionGrams)
        self.addedSugarsG = foodItem.addedSugars(forGrams: portionGrams)
        self.sucroseG = foodItem.sucrose(forGrams: portionGrams)
        self.glucoseG = foodItem.glucose(forGrams: portionGrams)
        self.fructoseG = foodItem.fructose(forGrams: portionGrams)
        self.lactoseG = foodItem.lactose(forGrams: portionGrams)
        self.maltoseG = foodItem.maltose(forGrams: portionGrams)
        self.maltodextrinsG = foodItem.maltodextrins(forGrams: portionGrams)
        self.starchG = foodItem.starch(forGrams: portionGrams)
        self.polyolsG = foodItem.polyols(forGrams: portionGrams)
        self.saturatedFatG = foodItem.saturatedFat(forGrams: portionGrams)
        self.transFatG = foodItem.transFat(forGrams: portionGrams)
        self.monounsaturatedFatG = foodItem.monounsaturatedFat(forGrams: portionGrams)
        self.polyunsaturatedFatG = foodItem.polyunsaturatedFat(forGrams: portionGrams)
        self.omega3FatG = foodItem.omega3Fat(forGrams: portionGrams)
        self.omega6FatG = foodItem.omega6Fat(forGrams: portionGrams)
        self.omega9FatG = foodItem.omega9Fat(forGrams: portionGrams)
        self.saltG = foodItem.salt(forGrams: portionGrams)
        self.sodiumG = foodItem.sodium(forGrams: portionGrams)
        self.cholesterolG = foodItem.cholesterol(forGrams: portionGrams)
        self.solubleFiberG = foodItem.solubleFiber(forGrams: portionGrams)
        self.insolubleFiberG = foodItem.insolubleFiber(forGrams: portionGrams)
        self.caseinG = foodItem.casein(forGrams: portionGrams)
        self.serumProteinsG = foodItem.serumProteins(forGrams: portionGrams)
        self.alcoholG = foodItem.alcohol(forGrams: portionGrams)
        self.foodName = foodItem.name
    }
}
