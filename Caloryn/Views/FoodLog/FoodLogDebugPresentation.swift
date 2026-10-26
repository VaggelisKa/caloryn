#if DEBUG
import Foundation
import SwiftData

enum FoodLogDebugPresentation: String {
    case addFood
    case portion
    case portionServing
    case select
    case multiAdd

    static let flag = "-uitest-present"

    static var requested: FoodLogDebugPresentation? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: flag),
              arguments.indices.contains(index + 1) else {
            return nil
        }
        return FoodLogDebugPresentation(rawValue: arguments[index + 1])
    }

    @MainActor private static var hasPrepared = false

    @MainActor
    static func takeRequest() -> FoodLogDebugPresentation? {
        guard let request = requested, !hasPrepared else { return nil }
        hasPrepared = true
        return request
    }

    struct DemoFoods {
        let skyr: FoodItem
        let rugbrod: FoodItem
        let chocolate: FoodItem
        let banana: FoodItem
        let smorrebrod: FoodItem
    }

    @MainActor
    static func seedDemoFoods(into context: ModelContext) -> DemoFoods {
        let now = Date()
        func food(
            _ name: String,
            brand: String?,
            kcal: Double,
            protein: Double,
            carbs: Double,
            fat: Double,
            fiber: Double,
            salt: Double,
            servingGrams: Double,
            serving: String,
            grade: String,
            minutesAgo: Double
        ) -> FoodItem {
            let item = FoodItem(
                name: name,
                brand: brand,
                caloriesPer100g: kcal,
                proteinPer100g: protein,
                carbsPer100g: carbs,
                fatPer100g: fat,
                fiberPer100g: fiber,
                saltPer100g: salt,
                defaultServingG: servingGrams,
                servingDescription: serving,
                nutriscoreGrade: grade
            )
            item.lastUsed = now.addingTimeInterval(-minutesAgo * 60)
            context.insert(item)
            return item
        }

        let foods = DemoFoods(
            skyr: food(
                "Skyr", brand: "Arla", kcal: 63, protein: 10.7, carbs: 3.3, fat: 0.2,
                fiber: 0, salt: 0.13, servingGrams: 150, serving: "1 pot (150g)",
                grade: "a", minutesAgo: 1
            ),
            rugbrod: food(
                "Rugbrød", brand: "Schulstad", kcal: 210, protein: 7, carbs: 36, fat: 2,
                fiber: 7, salt: 1.1, servingGrams: 45, serving: "1 slice (45g)",
                grade: "a", minutesAgo: 2
            ),
            chocolate: food(
                "Dark chocolate 70%", brand: "Marabou", kcal: 590, protein: 7.8, carbs: 33,
                fat: 43, fiber: 11, salt: 0.02, servingGrams: 20, serving: "2 squares (20g)",
                grade: "d", minutesAgo: 3
            ),
            banana: food(
                "Banana", brand: nil, kcal: 89, protein: 1.1, carbs: 23, fat: 0.3,
                fiber: 2.6, salt: 0, servingGrams: 120, serving: "1 banana (120g)",
                grade: "a", minutesAgo: 4
            ),
            smorrebrod: food(
                "Smørrebrød, salmon", brand: nil, kcal: 220, protein: 12, carbs: 18,
                fat: 11, fiber: 3, salt: 1.2, servingGrams: 160, serving: "1 piece (160g)",
                grade: "b", minutesAgo: 30
            )
        )

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        for daysAgo in [1, 2, 5, 7] {
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { continue }
            context.insert(
                FoodLogEntry(date: day, mealType: .lunch, foodItem: foods.smorrebrod, portionGrams: 160)
            )
        }
        try? context.save()

        _ = try? MealTemplateCommands.saveMeal(
            name: "Office lunch",
            snapshots: [
                FoodLogEntrySnapshot(foodItem: foods.rugbrod, portionGrams: 90, mealType: .lunch),
                FoodLogEntrySnapshot(foodItem: foods.skyr, portionGrams: 150, mealType: .lunch),
                FoodLogEntrySnapshot(foodItem: foods.banana, portionGrams: 120, mealType: .lunch),
            ],
            modelContext: context
        )
        return foods
    }
}
#endif
