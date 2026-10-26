import Foundation

enum FoodSearchMode {
    case logging

    case ingredientSelection((FoodItem) -> Void)

    case mealComponentSelection((FoodItem) -> Void)

    var title: String {
        switch self {
        case .logging: "Add food"
        case .ingredientSelection: "Add ingredient"
        case .mealComponentSelection: "Add meal item"
        }
    }

    var isSelection: Bool {
        switch self {
        case .logging: false
        case .ingredientSelection, .mealComponentSelection: true
        }
    }

    var includesRecipes: Bool {
        switch self {
        case .logging, .mealComponentSelection: true
        case .ingredientSelection: false
        }
    }

    var usesNonStickySectionTitles: Bool {
        switch self {
        case .logging, .mealComponentSelection: true
        case .ingredientSelection: false
        }
    }

    var allowsManualEntryCreation: Bool {
        switch self {
        case .ingredientSelection: true
        case .logging, .mealComponentSelection: false
        }
    }

    var supportsMultiSelection: Bool {
        switch self {
        case .logging: true
        case .ingredientSelection, .mealComponentSelection: false
        }
    }

    func isMultiSelectionControlEnabled(
        isSelectingMultiple: Bool,
        selectableOptionCount: Int
    ) -> Bool {
        supportsMultiSelection
            && (isSelectingMultiple || selectableOptionCount > 0)
    }

    func offersChatbotPaste(
        on screenContent: FoodSearchScreenContent,
        isSelectingMultiple: Bool
    ) -> Bool {
        guard case .logging = self else { return false }
        return screenContent == .recent && !isSelectingMultiple
    }

    var isIngredientSelection: Bool {
        switch self {
        case .ingredientSelection: true
        case .logging, .mealComponentSelection: false
        }
    }
}
