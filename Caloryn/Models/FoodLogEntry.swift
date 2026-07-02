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
        self.createdAt = Date()
    }
}
