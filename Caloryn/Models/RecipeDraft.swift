import Foundation

/// The editable state of the recipe form, and every rule that acts on it.
///
/// A recipe is a name plus an ordered list of ingredient amounts, and all the
/// form really does with them is arithmetic and bookkeeping: keep the order
/// contiguous as rows come and go, total the ingredients up for the summary
/// card, decide whether the recipe may be saved, and seed itself from a saved
/// recipe exactly once. None of that needs a view, so none of it lives in one.
struct RecipeDraft: Equatable {
    /// What seeding did, so the view knows whether to take focus.
    enum SeedOutcome: Equatable {
        /// The form already holds ingredients — `onAppear` can fire more than
        /// once, and re-seeding would discard what the user has typed.
        case alreadySeeded
        /// A brand-new recipe: nothing to load, so the name field is next.
        case startedEmpty
        /// Loaded from a saved recipe.
        case populated
    }

    var name = ""

    /// Mutated only through the methods below, because every change has to
    /// leave the sort order contiguous.
    private(set) var ingredients: [RecipeIngredientDraft] = []

    init() {}

    // MARK: - Ordering

    var sortedIngredients: [RecipeIngredientDraft] {
        ingredients.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// The ingredients as they will be written, each renumbered to its position
    /// so a saved recipe's order never depends on the order rows were added.
    var ingredientsForSaving: [RecipeIngredientDraft] {
        sortedIngredients.enumerated().map { index, draft in
            var renumbered = draft
            renumbered.sortOrder = index
            return renumbered
        }
    }

    // MARK: - Totals

    var totalGrams: Double { ingredients.reduce(0) { $0 + $1.portionGrams } }
    var totalCalories: Double { ingredients.reduce(0) { $0 + $1.calories } }
    var totalProtein: Double { ingredients.reduce(0) { $0 + $1.proteinG } }
    var totalCarbs: Double { ingredients.reduce(0) { $0 + $1.carbsG } }
    var totalFat: Double { ingredients.reduce(0) { $0 + $1.fatG } }
    var totalFiber: Double { ingredients.reduce(0) { $0 + $1.fiberG } }

    /// The caption under the calorie figure. The yield is only stated once
    /// there is one, so an empty form reads "calories" rather than "in 0g".
    var totalCaloriesCaption: String {
        totalGrams > 0 ? "calories in \(Self.yieldText(forGrams: totalGrams))g" : "calories"
    }

    /// How a yield is written. Whole grams from a gram upwards, because that is
    /// the precision a recipe is cooked at; below that the figure keeps a
    /// decimal, because a savable recipe must never claim to weigh nothing —
    /// rounding 0.4g to "0g" contradicted the form that had just accepted it.
    static func yieldText(forGrams grams: Double) -> String {
        guard grams.isFinite else { return "0" }
        if grams.rounded() >= 1 { return "\(grams.rounded().truncatedSafely)" }
        if grams >= 0.05 { return String(format: "%.1f", grams) }
        return "<0.1"
    }

    // MARK: - Validation

    var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    /// A recipe needs a name and some actual food in it. The gram total is
    /// checked as well as the count, because ingredients that all weigh nothing
    /// would divide by zero when the per-100g nutrition is derived.
    var canSave: Bool {
        !trimmedName.isEmpty && totalGrams > 0 && !ingredients.isEmpty
    }

    // MARK: - Editing ingredients

    /// Saves an amount for an ingredient: replacing the row when it is already
    /// in the recipe, appending it at the end when it is not.
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

    /// Keeps the order contiguous from zero, so a deletion in the middle does
    /// not leave a gap that a later append could collide with.
    private mutating func normalizeSortOrder() {
        for index in ingredients.indices {
            ingredients[index].sortOrder = index
        }
    }

    // MARK: - Loading an existing recipe

    mutating func seed(from recipe: FoodItem?) -> SeedOutcome {
        guard let recipe else { return seed(name: nil, ingredients: []) }
        return seed(
            name: recipe.name,
            ingredients: (recipe.recipeIngredients ?? []).map(RecipeIngredientDraft.init(from:))
        )
    }

    /// Seeds from the facts of a saved recipe. The ingredients arrive in
    /// whatever order the store handed them over, so they are put back in their
    /// saved order here rather than trusted.
    mutating func seed(name recipeName: String?, ingredients savedIngredients: [RecipeIngredientDraft]) -> SeedOutcome {
        guard ingredients.isEmpty else { return .alreadySeeded }
        guard let recipeName else { return .startedEmpty }

        name = recipeName
        ingredients = savedIngredients.sorted { $0.sortOrder < $1.sortOrder }
        return .populated
    }
}
