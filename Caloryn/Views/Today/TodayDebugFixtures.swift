#if DEBUG
import Foundation
import SwiftData

enum TodayDebugFixtures {
    static func seedOverBudgetDay(profile: UserProfile, in context: ModelContext) {
        profile.setTarget(50, for: .sugars)
        profile.setTarget(20, for: .saturatedFat)

        let today = Calendar.current.startOfDay(for: Date())

        func food(
            _ name: String,
            kcal: Double,
            protein: Double,
            carbs: Double,
            fat: Double,
            grade: String? = nil,
            produce: ProduceKind? = nil,
            isRecipe: Bool = false
        ) -> FoodItem {
            let item = FoodItem(
                name: name,
                caloriesPer100g: kcal,
                proteinPer100g: protein,
                carbsPer100g: carbs,
                fatPer100g: fat,
                fiberPer100g: produce == nil ? 1 : 2.5,
                sugarsPer100g: carbs * 0.3,
                saturatedFatPer100g: fat * 0.4,
                saltPer100g: 0.3,
                nutriscoreGrade: grade,
                produceKind: produce,
                isRecipe: isRecipe
            )
            context.insert(item)
            return item
        }

        let longAppleName = "Granny Smith apples, organic, family pack from a Danish orchard"
        let logged: [(MealType, FoodItem, Double)] = [
            (.breakfast, food("Skyr", kcal: 63, protein: 11, carbs: 4, fat: 0.2, grade: "a"), 150),
            (.breakfast, food("Granola", kcal: 450, protein: 10, carbs: 64, fat: 16, grade: "c"), 40),
            (.breakfast, food("Banana", kcal: 89, protein: 1.1, carbs: 23, fat: 0.3, grade: "a", produce: .fruit), 120),
            (.lunch, food("Smørrebrød, salmon", kcal: 220, protein: 12, carbs: 18, fat: 11, isRecipe: true), 160),
            (.lunch, food(longAppleName, kcal: 52, protein: 0.3, carbs: 14, fat: 0.2, grade: "a", produce: .fruit), 150),
            (.lunch, food("Carrot sticks", kcal: 41, protein: 0.9, carbs: 10, fat: 0.2, grade: "a", produce: .vegetable), 80),
            (.dinner, food("Pizza, margherita", kcal: 267, protein: 11, carbs: 33, fat: 10, grade: "c"), 240),
            (.dinner, food("Garlic bread", kcal: 263, protein: 7, carbs: 35, fat: 11, grade: "c"), 90),
            (.dinner, food("Ice cream, vanilla", kcal: 220, protein: 3.5, carbs: 24, fat: 12, grade: "d"), 150),
            (.snack, food("Almonds", kcal: 579, protein: 21, carbs: 22, fat: 50, grade: "a"), 20),
        ]
        for (meal, item, grams) in logged {
            context.insert(FoodLogEntry(date: today, mealType: meal, foodItem: item, portionGrams: grams))
        }

        let wine = FoodItem(
            name: "Red wine",
            caloriesPer100g: 68,
            proteinPer100g: 0.1,
            carbsPer100g: 2.6,
            fatPer100g: 0,
            alcoholPer100g: 10
        )
        context.insert(
            FoodLogEntry(
                date: today,
                mealType: .dinner,
                foodItem: nil,
                snapshot: FoodLogEntrySnapshot(foodItem: wine, portionGrams: 250, mealType: .dinner),
                snackIndex: 0
            )
        )
    }
}
#endif
