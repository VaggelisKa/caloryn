import SwiftUI

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
