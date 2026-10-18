import SwiftUI

/// The meal lookups for the widget's own `WidgetMeal`. Every other colour the widget draws
/// is a `CalorynTheme` token from `CalorynShared/CalorynThemeColors.swift`, the same names
/// the app uses (`docs/theme.md`).
enum WidgetTheme {
    /// The meal's colour for shapes: a plate sector, a legend key.
    static func mealFill(_ meal: WidgetMeal) -> Color {
        switch meal {
        case .breakfast: CalorynTheme.mealBreakfast
        case .lunch: CalorynTheme.mealLunch
        case .dinner: CalorynTheme.mealDinner
        case .snack: CalorynTheme.mealSnack
        }
    }

    /// The meal's colour for text: dark enough for 4.5:1 on the page in light mode.
    static func mealInk(_ meal: WidgetMeal) -> Color {
        switch meal {
        case .breakfast: CalorynTheme.mealBreakfastInk
        case .lunch: CalorynTheme.mealLunchInk
        case .dinner: CalorynTheme.mealDinnerInk
        case .snack: CalorynTheme.mealSnackInk
        }
    }

    /// A soft wash of the meal's fill under its ink: the log row's plus, as the app's meal
    /// header draws it. The same 16% for all four meals.
    static func mealWash(_ meal: WidgetMeal) -> Color {
        mealFill(meal).opacity(0.16)
    }
}
