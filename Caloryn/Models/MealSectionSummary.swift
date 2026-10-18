import Foundation

struct MealSectionSummary: Equatable {
    struct Entry: Equatable {
        let calories: Double
        let proteinG: Double
        let carbsG: Double
        let fatG: Double

        init(calories: Double, proteinG: Double, carbsG: Double, fatG: Double) {
            self.calories = calories
            self.proteinG = proteinG
            self.carbsG = carbsG
            self.fatG = fatG
        }
    }

    let mealType: MealType
    let snackIndex: Int
    let titleOverride: String?
    let entryCount: Int
    let totalCalories: Double
    let totalProtein: Double
    let totalCarbs: Double
    let totalFat: Double

    init(
        mealType: MealType,
        snackIndex: Int = 0,
        titleOverride: String? = nil,
        entries: [Entry]
    ) {
        self.mealType = mealType
        self.snackIndex = snackIndex
        self.titleOverride = titleOverride
        entryCount = entries.count
        totalCalories = entries.reduce(0) { $0 + $1.calories }
        totalProtein = entries.reduce(0) { $0 + $1.proteinG }
        totalCarbs = entries.reduce(0) { $0 + $1.carbsG }
        totalFat = entries.reduce(0) { $0 + $1.fatG }
    }

    var title: String {
        if let titleOverride { return titleOverride }
        return mealType == .snack ? mealType.displayName(snackIndex: snackIndex) : mealType.displayName
    }

    var addAccessibilityLabel: String {
        "Add food or meal to \(title)"
    }

    var usesSingleRowTransition: Bool {
        entryCount <= 1
    }

    var showsCalories: Bool {
        !totalCalories.isZero
    }

    var showsMacroBreakdown: Bool {
        entryCount > 0
    }

    var showsProtein: Bool {
        !totalProtein.isZero
    }

    var showsCarbs: Bool {
        !totalCarbs.isZero
    }

    var showsFat: Bool {
        !totalFat.isZero
    }

    var caloriesText: String {
        totalCalories.kcalFormatted
    }

    var isEmpty: Bool {
        entryCount == 0
    }

    func headerTotalText(locale: Locale = .current) -> String {
        guard !isEmpty else { return "nothing yet" }
        return "\(totalCalories.roundedCalories.formatted(.number.locale(locale))) kcal"
    }

    func emptyRowText(canCopyYesterday: Bool) -> String {
        let add = "Add \(mealType == .snack ? "a snack" : mealType.displayName.lowercased())"
        return canCopyYesterday ? "\(add), or copy yesterday's." : "\(add)."
    }

    var proteinText: String {
        "\(totalProtein.macroFormatted) P"
    }

    var carbsText: String {
        "\(totalCarbs.macroFormatted) C"
    }

    var fatText: String {
        "\(totalFat.macroFormatted) F"
    }
}
