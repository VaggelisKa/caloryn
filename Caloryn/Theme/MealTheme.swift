import SwiftUI

/// A meal's colours, read from the meal itself.
///
/// The palette lives in `CalorynTheme`; this only saves call sites a lookup. `fill` is for
/// shapes (donut sectors, the add button, a selected chip), `ink` for text in the meal's
/// colour, `onFill` for a label or glyph drawn on the fill.
extension MealType {
    var fill: Color {
        CalorynTheme.mealFill(self)
    }

    var ink: Color {
        CalorynTheme.mealInk(self)
    }

    var onFill: Color {
        CalorynTheme.mealOnFill(self)
    }
}
