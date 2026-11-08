import Foundation

enum HistoryMealLabel {
    static func rowTitle(for mealType: MealType) -> String {
        mealType == .snack ? "Snacks" : mealType.displayName
    }
}
