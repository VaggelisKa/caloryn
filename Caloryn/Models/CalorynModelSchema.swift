import SwiftData

enum CalorynModelSchema {
    static let cloudKitContainerIdentifier = "iCloud.www.caloryn"

    static var models: [any PersistentModel.Type] {
        [
            UserProfile.self,
            FoodItem.self,
            FoodLogEntry.self,
            RecipeIngredient.self,
            DailyGoalSnapshot.self,
            MealTemplate.self,
            MealTemplateItem.self,
        ]
    }
}
