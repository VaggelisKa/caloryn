import Foundation

struct RecipeDraft: Equatable {
    enum SeedOutcome: Equatable {
        case alreadySeeded
        case startedEmpty
        case populated
    }

    var name = ""

    private(set) var ingredients: [RecipeIngredientDraft] = []

    init() {}

    var sortedIngredients: [RecipeIngredientDraft] {
        ingredients.sorted { $0.sortOrder < $1.sortOrder }
    }

    var ingredientsForSaving: [RecipeIngredientDraft] {
        sortedIngredients.enumerated().map { index, draft in
            var renumbered = draft
            renumbered.sortOrder = index
            return renumbered
        }
    }

    var totalGrams: Double { ingredients.reduce(0) { $0 + $1.portionGrams } }
    var totalCalories: Double { ingredients.reduce(0) { $0 + $1.calories } }
    var totalProtein: Double { ingredients.reduce(0) { $0 + $1.proteinG } }
    var totalCarbs: Double { ingredients.reduce(0) { $0 + $1.carbsG } }
    var totalFat: Double { ingredients.reduce(0) { $0 + $1.fatG } }
    var totalFiber: Double { ingredients.reduce(0) { $0 + $1.fiberG } }

    var totalCaloriesCaption: String {
        totalCaloriesCaption(locale: .current)
    }

    func totalCaloriesCaption(locale: Locale) -> String {
        totalGrams > 0 ? "calories in \(Self.yieldText(forGrams: totalGrams, locale: locale))" : "calories"
    }

    static func yieldText(forGrams grams: Double, locale: Locale = .current) -> String {
        guard grams.isFinite else { return 0.0.spacedMacroFormatted(locale: locale) }
        if grams.rounded() >= 1 { return grams.rounded().spacedMacroFormatted(locale: locale) }
        if grams >= 0.05 { return grams.spacedMacroFormatted(locale: locale) }
        return "<\(0.1.spacedMacroFormatted(locale: locale))"
    }

    var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    var canSave: Bool {
        !trimmedName.isEmpty && totalGrams > 0 && !ingredients.isEmpty
    }

    mutating func upsert(_ ingredient: RecipeIngredientDraft) {
        if let index = ingredients.firstIndex(where: { $0.id == ingredient.id }) {
            ingredients[index] = ingredient
        } else {
            var newIngredient = ingredient
            newIngredient.sortOrder = ingredients.count
            ingredients.append(newIngredient)
        }
        normalizeSortOrder()
    }

    mutating func remove(_ ingredient: RecipeIngredientDraft) {
        ingredients.removeAll { $0.id == ingredient.id }
        normalizeSortOrder()
    }

    private mutating func normalizeSortOrder() {
        for index in ingredients.indices {
            ingredients[index].sortOrder = index
        }
    }

    mutating func seed(from recipe: FoodItem?) -> SeedOutcome {
        guard let recipe else { return seed(name: nil, ingredients: []) }
        return seed(
            name: recipe.name,
            ingredients: (recipe.recipeIngredients ?? []).map(RecipeIngredientDraft.init(from:))
        )
    }

    mutating func seed(name recipeName: String?, ingredients savedIngredients: [RecipeIngredientDraft]) -> SeedOutcome {
        guard ingredients.isEmpty else { return .alreadySeeded }
        guard let recipeName else { return .startedEmpty }

        name = recipeName
        ingredients = savedIngredients.sorted { $0.sortOrder < $1.sortOrder }
        return .populated
    }
}
