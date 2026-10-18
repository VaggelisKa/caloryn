import Foundation
import Testing
@testable import Caloryn

@MainActor
@Suite("History refresh ID legacy coverage")
struct HistoryRefreshIDLegacyCoverageTests {
    @Test("given a legacy entry, when its saved food changes produce kind, then its signature changes so the produce count reruns")
    func aLegacyProduceKindChangeChangesTheSignature() {
        let food = makeTestFoodItem(name: "Apple", produceKind: .fruit)
        let legacy = makeLegacyTestEntry(foodItem: food, portionGrams: 120)
        let before = HistoryEntrySignature(entry: legacy)

        food.produceKind = .unclassified

        #expect(HistoryEntrySignature(entry: legacy) != before)
        #expect(ProduceVarietySummary(entries: [legacy]).totalCount == 0)
    }

    @Test("given a legacy entry, when its saved food is renamed, then the produce summary and the signature both follow the new name")
    func aLegacyRenameIsReadByProduceAndBySignature() {
        let banana = makeTestEntry(foodItem: makeTestFoodItem(name: "Banana", produceKind: .fruit), portionGrams: 100)
        let food = makeTestFoodItem(name: "Apple", produceKind: .fruit)
        let legacy = makeLegacyTestEntry(foodItem: food, portionGrams: 120)
        let before = HistoryEntrySignature(entry: legacy)
        #expect(ProduceVarietySummary(entries: [banana, legacy]).items.map(\.name) == ["Apple", "Banana"])

        food.name = "Banana"

        #expect(ProduceVarietySummary(entries: [banana, legacy]).items.map(\.name) == ["Banana"])
        #expect(HistoryEntrySignature(entry: legacy) != before)
    }

    @Test(
        "given a legacy recipe entry, when an ingredient is renamed, reclassified or zeroed, then its signature changes",
        arguments: ["rename", "reclassify", "zero"]
    )
    func aLegacyRecipeIngredientEditChangesTheSignature(edit: String) throws {
        let recipe = makeTestFoodItem(name: "Stew", produceKind: .unclassified, isRecipe: true)
        recipe.recipeIngredients = [
            RecipeIngredient(
                name: "Carrots", portionGrams: 80, caloriesPer100g: 40, proteinPer100g: 1,
                carbsPer100g: 8, fatPer100g: 0.2, sortOrder: 0, produceKind: .vegetable
            )
        ]
        let legacy = makeLegacyTestEntry(foodItem: recipe, portionGrams: 80)
        let before = HistoryEntrySignature(entry: legacy)
        let carrots = try #require(recipe.recipeIngredients?.first)

        switch edit {
        case "rename": carrots.name = "Parsnips"
        case "reclassify": carrots.produceKind = .unclassified
        default: carrots.portionGrams = 0
        }

        #expect(HistoryEntrySignature(entry: legacy) != before)
    }
}
