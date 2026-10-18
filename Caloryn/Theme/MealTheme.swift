import SwiftUI

/// A meal's colours, read from the meal itself.
///
/// The palette lives in `CalorynTheme`; this only saves call sites a lookup. `fill` is for
/// shapes (donut sectors, a selected chip), `ink` for text in the meal's colour, and `wash`
/// for the fill as a light background with ink on it (the header's add button). A label
/// drawn on the fill reads `CalorynTheme.mealOnFill(_:)`.
extension MealType {
    var fill: Color {
        CalorynTheme.mealFill(self)
    }

    var ink: Color {
        CalorynTheme.mealInk(self)
    }

    var wash: Color {
        CalorynTheme.mealWash(self)
    }
}
