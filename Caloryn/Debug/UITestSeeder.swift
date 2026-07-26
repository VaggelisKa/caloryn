#if DEBUG
import Foundation
import SwiftData

/// Populates an in-memory store with a known fixture before the UI appears.
///
/// Seeding is deliberately synchronous and happens during app start-up so the
/// first `@Query` a view runs already sees the fixture. Dates are derived from
/// the current day so "today" means today from the test's point of view.
enum UITestSeeder {
    static func seed(_ fixture: UITestConfiguration.Fixture, into context: ModelContext) throws {
        switch fixture {
        case .empty:
            break
        case .profileOnly:
            insertProfile(into: context)
        case .loggedDay:
            insertProfile(into: context)
            let oats = insertOats(into: context)
            context.insert(
                FoodLogEntry(date: today, mealType: .breakfast, foodItem: oats, portionGrams: 100)
            )
        case .customFoods:
            insertProfile(into: context)
            let smoothie = FoodItem(
                name: "Morning Smoothie",
                caloriesPer100g: 60,
                proteinPer100g: 2,
                carbsPer100g: 11,
                fatPer100g: 1,
                fiberPer100g: 2,
                defaultServingG: 250,
                isCustom: true
            )
            context.insert(smoothie)
            smoothie.setFavorite(true)

            context.insert(
                FoodItem(
                    name: "House Salad",
                    caloriesPer100g: 45,
                    proteinPer100g: 2,
                    carbsPer100g: 6,
                    fatPer100g: 1.5,
                    fiberPer100g: 3,
                    defaultServingG: 180,
                    isCustom: true
                )
            )
        case .history:
            insertProfile(into: context)
            let oats = insertOats(into: context)
            let calendar = Calendar.current
            // Thirty consecutive logged days with a deterministic calorie pattern,
            // so History assertions can rely on exact totals.
            for dayOffset in 0..<30 {
                guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else {
                    continue
                }
                let portion = 100.0 + Double((dayOffset % 5) * 50)
                context.insert(
                    FoodLogEntry(date: date, mealType: .breakfast, foodItem: oats, portionGrams: portion)
                )
            }
        case .historyPattern:
            HistoryPreviewFixtures.seedRecurringInsight(in: context)
        case .historyNoPattern:
            HistoryPreviewFixtures.seedNoRecurringInsight(in: context)
        }

        try context.save()
    }

    private static var today: Date {
        Calendar.current.startOfDay(for: Date())
    }

    @discardableResult
    private static func insertProfile(into context: ModelContext) -> UserProfile {
        let profile = UserProfile(
            age: 30,
            sex: .male,
            heightCm: 180,
            weightKg: 80,
            activityLevel: .moderatelyActive,
            dailyCalorieTarget: 2_000,
            manualOverride: true
        )
        context.insert(profile)
        return profile
    }

    @discardableResult
    private static func insertOats(into context: ModelContext) -> FoodItem {
        let oats = FoodItem(
            name: "Rolled Oats",
            brand: "Test Brand",
            caloriesPer100g: 380,
            proteinPer100g: 13,
            carbsPer100g: 60,
            fatPer100g: 7,
            fiberPer100g: 10,
            defaultServingG: 50
        )
        context.insert(oats)
        return oats
    }
}
#endif
