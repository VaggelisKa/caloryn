import Foundation

/// Why the food search screen was opened, and what that permits.
///
/// The screen is reached three ways — logging a food, picking an ingredient for
/// a recipe, and picking a component for a meal — and each one turns a
/// different set of affordances on. Those flags gate what the user can *do*, so
/// they live here rather than inline in the view where only a UI test could
/// reach them.
///
/// The associated closure is the caller's "I'll take it from here" handler; it
/// is deliberately not part of any policy below, which is why every property
/// here can be answered without calling it.
enum FoodSearchMode {
    /// Opened from the day's log: results go to the portion picker, and the
    /// user may tick several rows and review them together.
    case logging

    /// Opened from the recipe form: the chosen food is handed back, and the
    /// user may create a manual entry when nothing matches.
    case ingredientSelection((FoodItem) -> Void)

    /// Opened from the meal form: the chosen food is handed back.
    case mealComponentSelection((FoodItem) -> Void)

    var title: String {
        switch self {
        case .logging: "Add Food"
        case .ingredientSelection: "Add Ingredient"
        case .mealComponentSelection: "Add Meal Item"
        }
    }

    /// Whether the screen hands its result back to a caller instead of logging
    /// it. Selection modes also list the user's own recipes and manual entries
    /// while at rest, because picking one of those is the common case.
    var isSelection: Bool {
        switch self {
        case .logging: false
        case .ingredientSelection, .mealComponentSelection: true
        }
    }

    /// Whether recipes are candidates at all. A recipe cannot be an ingredient
    /// of another recipe, so ingredient selection excludes them.
    var includesRecipes: Bool {
        switch self {
        case .logging, .mealComponentSelection: true
        case .ingredientSelection: false
        }
    }

    /// Whether section headings scroll away with their rows rather than
    /// pinning to the top of the list.
    var usesNonStickySectionTitles: Bool {
        switch self {
        case .logging, .mealComponentSelection: true
        case .ingredientSelection: false
        }
    }

    /// Whether the toolbar offers "create a manual entry". Only recipe
    /// ingredients are commonly missing from the catalogue, so only that mode
    /// pays for the extra control.
    var allowsManualEntryCreation: Bool {
        switch self {
        case .ingredientSelection: true
        case .logging, .mealComponentSelection: false
        }
    }

    /// Whether the user can tick several rows and review them in one sheet.
    /// A caller expecting a single food back cannot receive a batch.
    var supportsMultiSelection: Bool {
        switch self {
        case .logging: true
        case .ingredientSelection, .mealComponentSelection: false
        }
    }

    /// Whether the Select/Cancel toolbar control is tappable.
    ///
    /// Entering selection mode with nothing to tick is a dead end, so the
    /// control stays disabled until there is at least one option — but once the
    /// user is *in* selection mode it must stay live, or a query that matches
    /// nothing would strand them there with no way out.
    func isMultiSelectionControlEnabled(
        isSelectingMultiple: Bool,
        selectableOptionCount: Int
    ) -> Bool {
        supportsMultiSelection
            && (isSelectingMultiple || selectableOptionCount > 0)
    }

    var isIngredientSelection: Bool {
        switch self {
        case .ingredientSelection: true
        case .logging, .mealComponentSelection: false
        }
    }
}
