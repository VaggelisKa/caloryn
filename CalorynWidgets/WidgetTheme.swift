import SwiftUI

enum WidgetTheme {
    static let page = Color(.pageBackground)
    static let ink = Color(.textPrimary)
    static let secondary = Color(.textSecondary)
    static let tertiary = Color(.textTertiary)
    static let hairline = Color(.hairline)
    static let eaten = Color(.historyEaten)

    static func mealFill(_ meal: WidgetMeal) -> Color {
        switch meal {
        case .breakfast: Color(.mealBreakfast)
        case .lunch: Color(.mealLunch)
        case .dinner: Color(.mealDinner)
        case .snack: Color(.mealSnack)
        }
    }

    static func mealInk(_ meal: WidgetMeal) -> Color {
        switch meal {
        case .breakfast: Color(.mealBreakfastInk)
        case .lunch: Color(.mealLunchInk)
        case .dinner: Color(.mealDinnerInk)
        case .snack: Color(.mealSnackInk)
        }
    }

    static func mealWash(_ meal: WidgetMeal) -> Color {
        mealFill(meal).opacity(0.16)
    }
}
