import Foundation
import Testing
@testable import Caloryn

/// Covers the rules the meal form applies, which until now were only
/// reachable by driving the form.
@MainActor
@Suite("Meal form draft")
struct MealFormDraftTests {

    // MARK: - Save gating

    @Test("A blank name blocks saving even with items")
    func blankNameBlocksSave() {
        var draft = MealFormDraft()
        draft.name = "   "
        draft.components = [makeComponent(portionGrams: 100)]

        #expect(!draft.canSave)
    }

    @Test("No items blocks saving even with a name")
    func emptyComponentsBlocksSave() {
        var draft = MealFormDraft()
        draft.name = "Breakfast"

        #expect(!draft.canSave)
    }

    @Test("A zero or negative portion on any component blocks saving")
    func nonPositivePortionBlocksSave() {
        var draft = MealFormDraft()
        draft.name = "Breakfast"
        draft.components = [
            makeComponent(portionGrams: 100),
            makeComponent(portionGrams: 0),
        ]

        #expect(!draft.canSave)
    }

    @Test("A named meal with at least one positively-portioned item may be saved")
    func validDraftCanSave() {
        var draft = MealFormDraft()
        draft.name = "Breakfast"
        draft.components = [makeComponent(portionGrams: 100)]

        #expect(draft.canSave)
    }

    // MARK: - Totals

    @Test("Total nutrition sums every component's snapshot")
    func totalNutritionSumsComponents() {
        var draft = MealFormDraft()
        draft.components = [
            makeComponent(portionGrams: 100, caloriesPer100g: 100),
            makeComponent(portionGrams: 100, caloriesPer100g: 50),
        ]

        #expect(draft.totalNutrition.calories == 150)
    }

    @Test("Total nutrition of an empty draft is zero")
    func totalNutritionEmptyIsZero() {
        let draft = MealFormDraft()

        #expect(draft.totalNutrition == .zero)
    }

    // MARK: - Editing components

    @Test("Upserting an unknown id appends a new component")
    func upsertAppendsNewComponent() {
        var draft = MealFormDraft()
        let component = makeComponent(portionGrams: 100)

        draft.upsert(component)

        #expect(draft.components.map(\.id) == [component.id])
    }

    @Test("Upserting a known id replaces that component in place")
    func upsertReplacesExistingComponent() {
        var draft = MealFormDraft()
        let original = makeComponent(portionGrams: 100)
        let other = makeComponent(portionGrams: 50)
        draft.components = [original, other]

        let updated = original.updatingPortion(to: 200)
        draft.upsert(updated)

        #expect(draft.components.count == 2)
        #expect(draft.components.first { $0.id == original.id }?.snapshot.portionGrams == 200)
        #expect(draft.components.first { $0.id == other.id }?.snapshot.portionGrams == 50)
    }

    @Test("Deleting removes only the matching component")
    func deleteRemovesMatchingComponent() {
        var draft = MealFormDraft()
        let toKeep = makeComponent(portionGrams: 100)
        let toDelete = makeComponent(portionGrams: 50)
        draft.components = [toKeep, toDelete]

        draft.delete(toDelete)

        #expect(draft.components.map(\.id) == [toKeep.id])
    }

    // MARK: - Seeding from an existing meal

    @Test("Seeding from an existing meal copies its name and decodes its items")
    func seedsNameAndComponentsFromExistingMeal() throws {
        let firstSnapshot = FoodLogEntrySnapshot(foodItem: makeTestFoodItem(name: "Oats"), portionGrams: 80)
        let secondSnapshot = FoodLogEntrySnapshot(foodItem: makeTestFoodItem(name: "Milk"), portionGrams: 200)
        let meal = try makeMealTemplate(
            name: "Weekday Breakfast",
            snapshots: [firstSnapshot, secondSnapshot]
        )

        let draft = MealFormDraft(existingMeal: meal)

        #expect(draft.name == "Weekday Breakfast")
        #expect(draft.components.map(\.snapshot.foodName) == ["Oats", "Milk"])
        #expect(draft.components.map(\.snapshot.portionGrams) == [80, 200])
    }

    @Test("Seeding drops items whose stored snapshot fails to decode")
    func seedingDropsUndecodableItems() throws {
        let goodSnapshot = FoodLogEntrySnapshot(foodItem: makeTestFoodItem(name: "Oats"), portionGrams: 80)
        let meal = try makeMealTemplate(name: "Breakfast", snapshots: [goodSnapshot])
        let corruptItem = MealTemplateItem(
            snapshotData: Data("not json".utf8),
            sourceFoodID: nil,
            sortOrder: 1
        )
        meal.items = (meal.items ?? []) + [corruptItem]

        let draft = MealFormDraft(existingMeal: meal)

        #expect(draft.components.map(\.snapshot.foodName) == ["Oats"])
    }

    // MARK: - Helpers

    private func makeComponent(portionGrams: Double, caloriesPer100g: Double = 100) -> MealComponentDraft {
        let food = makeTestFoodItem(caloriesPer100g: caloriesPer100g)
        return MealComponentDraft(foodItem: food).updatingPortion(to: portionGrams)
    }

    private func makeMealTemplate(
        name: String,
        snapshots: [FoodLogEntrySnapshot]
    ) throws -> MealTemplate {
        let meal = MealTemplate(
            name: name,
            defaultMeal: .breakfast,
            defaultSnackIndex: 0,
            creationOperationID: UUID(),
            creationFingerprint: ""
        )
        meal.items = try snapshots.enumerated().map { offset, snapshot in
            let item = MealTemplateItem(
                snapshotData: try JSONEncoder().encode(snapshot),
                sourceFoodID: snapshot.sourceFoodID,
                sortOrder: offset
            )
            item.template = meal
            return item
        }
        return meal
    }
}
