import SwiftUI

/// Widget-side names for the shared palette (`docs/design/plate-market.md`).
///
/// The colours themselves live in `CalorynShared/SharedColors.xcassets`, which is a member of
/// both the app and the widget target — so these resolve to the same Color Sets the app uses
/// and cannot drift from it. Add colours there, never as literals here.
enum WidgetTheme {
    /// Paper: the widget's container background, the same canvas as every page in the app.
    static let page = Color(.pageBackground)
    /// Ink: titles, figures, the over sector of the plate.
    static let ink = Color(.textPrimary)
    /// Captions, units, the legend's meal names.
    static let secondary = Color(.textSecondary)
    /// The legend's "not yet". Placeholder-only: below 4.5:1 on the page in light.
    static let tertiary = Color(.textTertiary)
    /// Row separators and the unfilled part of the plate.
    static let hairline = Color(.hairline)
    /// Eaten but not attributed to a meal: a snapshot from before meals were recorded.
    static let eaten = Color(.historyEaten)

    /// The meal's colour for shapes: a plate sector, a legend key.
    static func mealFill(_ meal: WidgetMeal) -> Color {
        switch meal {
        case .breakfast: Color(.mealBreakfast)
        case .lunch: Color(.mealLunch)
        case .dinner: Color(.mealDinner)
        case .snack: Color(.mealSnack)
        }
    }

    /// The meal's colour for text: dark enough for 4.5:1 on the page in light mode.
    static func mealInk(_ meal: WidgetMeal) -> Color {
        switch meal {
        case .breakfast: Color(.mealBreakfastInk)
        case .lunch: Color(.mealLunchInk)
        case .dinner: Color(.mealDinnerInk)
        case .snack: Color(.mealSnackInk)
        }
    }

    /// A soft wash of the meal's fill under its ink: the log row's plus, as the app's meal
    /// header draws it. The same 16% for all four meals.
    static func mealWash(_ meal: WidgetMeal) -> Color {
        mealFill(meal).opacity(0.16)
    }
}
