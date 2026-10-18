import SwiftUI

enum WidgetTheme {
    static func mealFill(_ meal: WidgetMeal) -> Color {
        switch meal {
        case .breakfast: CalorynTheme.mealBreakfast
        case .lunch: CalorynTheme.mealLunch
        case .dinner: CalorynTheme.mealDinner
        case .snack: CalorynTheme.mealSnack
        }
    }

    static func mealInk(_ meal: WidgetMeal) -> Color {
        switch meal {
        case .breakfast: CalorynTheme.mealBreakfastInk
        case .lunch: CalorynTheme.mealLunchInk
        case .dinner: CalorynTheme.mealDinnerInk
        case .snack: CalorynTheme.mealSnackInk
        }
    }

    static func mealWash(_ meal: WidgetMeal) -> Color {
        mealFill(meal).opacity(0.16)
    }
}
