#if DEBUG
import Foundation
import SwiftData

/// Puts the Add Food sheet, or a sheet pushed from it, in a known state so it can be
/// photographed with `xcrun simctl io … screenshot` and no UI test driving the simulator.
/// Compiled out of release builds.
///
/// The sheet itself is opened by the app's own deep link, exactly as the widget opens it,
/// so nothing outside this folder needs a hook:
///
/// ```
/// xcrun simctl launch <udid> www.caloryn -uitest-reset -uitest-seed loggedDay -uitest-present portion
/// xcrun simctl openurl <udid> 'caloryn://add-food?meal=lunch'
/// ```
///
/// `FoodSearchView.onAppear` then seeds the demo foods and moves the open sheet into the
/// requested state. The demo foods exist because no UI-test fixture has a food measured in
/// pots or slices, a Nutri-Score, a lunch habit or a saved meal, and those are exactly what
/// the Add Food rows and the Portion sheet need to show.
///
/// The edit-mode Portion sheet is opened from Today, not from here: photograph it through
/// the journey that taps a logged entry. The barcode states need no case either:
/// `CALORYN_LOOKUP_FIXTURE=barcode-not-found` (and the other values `FoodSearchService`
/// reads) already opens the sheet on a failure. Pass it to `simctl launch` as
/// `SIMCTL_CHILD_CALORYN_LOOKUP_FIXTURE`.
enum FoodLogDebugPresentation: String {
    /// The Add Food sheet at rest: "Usually at lunch", the saved meals, Recent.
    case addFood
    /// The Portion sheet for the demo Skyr at a remembered 160 g, on the grams stepper.
    case portion
    /// The Portion sheet for the demo rye bread, on its serving stepper.
    case portionServing
    /// Add Food in multi-select mode with two foods ticked.
    case select
    /// The multi-add review sheet for those two foods.
    case multiAdd

    /// Followed by a raw value, e.g. `-uitest-present portion`.
    static let flag = "-uitest-present"

    static var requested: FoodLogDebugPresentation? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: flag),
              arguments.indices.contains(index + 1) else {
            return nil
        }
        return FoodLogDebugPresentation(rawValue: arguments[index + 1])
    }

    /// Acts once per launch: `onAppear` runs again every time a pushed screen or a sheet on
    /// top of Add Food is dismissed.
    @MainActor private static var hasPrepared = false

    /// The request for this launch, the first time it is asked for, and never again.
    @MainActor
    static func takeRequest() -> FoodLogDebugPresentation? {
        guard let request = requested, !hasPrepared else { return nil }
        hasPrepared = true
        return request
    }

    /// The foods `seedDemoFoods` inserts, most recently used first.
    struct DemoFoods {
        let skyr: FoodItem
        let rugbrod: FoodItem
        let chocolate: FoodItem
        let banana: FoodItem
        let smorrebrod: FoodItem
    }

    /// Inserts the demo foods, a lunch habit for the smørrebrød and the "Office lunch"
    /// saved meal.
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

        // A lunch habit, so "Usually at lunch" has something to suggest: the smørrebrød
        // on four of the last eight days, logged at this time of day.
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
