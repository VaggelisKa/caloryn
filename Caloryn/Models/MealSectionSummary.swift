import Foundation

/// What one meal's section on Today says about itself.
///
/// Takes each entry's four macro figures rather than the entries, because that
/// is all a header total depends on. Every "is this shown" here is a rule about
/// the data, not about layout: a macro with nothing in it is omitted rather than
/// printed as "0.0g P", so an empty meal's header stays quiet.
struct MealSectionSummary: Equatable {
    /// The facts about one logged entry that a section header depends on.
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

    // MARK: - Title

    /// An explicit override wins; otherwise a snack names its slot and every
    /// other meal is simply itself.
    var title: String {
        if let titleOverride { return titleOverride }
        return mealType == .snack ? mealType.displayName(snackIndex: snackIndex) : mealType.displayName
    }

    var addAccessibilityLabel: String {
        "Add food or meal to \(title)"
    }

    // MARK: - Rows

    /// At most one entry is drawn through the cross-fading single-row slot, so
    /// deleting the last item can fade into the empty state instead of the row
    /// vanishing under the swipe.
    var usesSingleRowTransition: Bool {
        entryCount <= 1
    }

    // MARK: - Header totals

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
