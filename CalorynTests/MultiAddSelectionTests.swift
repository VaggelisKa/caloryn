import XCTest
@testable import Caloryn

@MainActor
final class MultiAddSelectionTests: XCTestCase {
    func testOnlyLoggingModeSupportsMultiSelection() {
        XCTAssertTrue(FoodSearchMode.logging.supportsMultiSelection)
        XCTAssertFalse(
            FoodSearchMode.ingredientSelection { _ in }.supportsMultiSelection
        )
        XCTAssertFalse(
            FoodSearchMode.mealComponentSelection { _ in }.supportsMultiSelection
        )
    }

    func testMultiSelectControlRequiresAnOptionUnlessSelectionModeIsActive() {
        XCTAssertFalse(
            FoodSearchMode.logging.isMultiSelectionControlEnabled(
                isSelectingMultiple: false,
                selectableOptionCount: 0
            )
        )
        XCTAssertTrue(
            FoodSearchMode.logging.isMultiSelectionControlEnabled(
                isSelectingMultiple: false,
                selectableOptionCount: 1
            )
        )
        XCTAssertTrue(
            FoodSearchMode.logging.isMultiSelectionControlEnabled(
                isSelectingMultiple: true,
                selectableOptionCount: 0
            )
        )
    }

    func testIngredientAndMealComponentModesRemainSingleSelectWithFinalMainBehavior() {
        let ingredient = FoodSearchMode.ingredientSelection { _ in }
        let mealComponent = FoodSearchMode.mealComponentSelection { _ in }

        XCTAssertTrue(ingredient.isSelection)
        XCTAssertTrue(ingredient.isIngredientSelection)
        XCTAssertFalse(ingredient.includesRecipes)
        XCTAssertTrue(ingredient.allowsManualEntryCreation)

        XCTAssertTrue(mealComponent.isSelection)
        XCTAssertFalse(mealComponent.isIngredientSelection)
        XCTAssertTrue(mealComponent.includesRecipes)
        XCTAssertFalse(mealComponent.allowsManualEntryCreation)
        XCTAssertFalse(ingredient.supportsMultiSelection)
        XCTAssertFalse(mealComponent.supportsMultiSelection)
    }

    func testSavedFoodDraftUsesResolvedPortionAndDestinationSnapshot() throws {
        let food = makeTestFoodItem(
            name: "Oats",
            caloriesPer100g: 380,
            proteinPer100g: 12
        )
        let group = MultiAddSelectionGroup.savedFood(
            food,
            portionGrams: 75,
            meal: .snack,
            snackIndex: 3
        )
        let item = try XCTUnwrap(group.items.first)

        XCTAssertEqual(group.id, .food(food.id))
        XCTAssertEqual(group.title, "Oats")
        XCTAssertEqual(item.snapshot.sourceFoodID, food.id)
        XCTAssertEqual(item.snapshot.portionGrams, 75)
        XCTAssertEqual(item.snapshot.mealType, .snack)
        XCTAssertEqual(item.snapshot.snackIndex, 3)
        XCTAssertEqual(item.snapshot.nutrition.calories, 285)
        XCTAssertEqual(item.snapshot.nutrition.proteinG, 9)
    }

    func testAuthoredMealDraftExpandsEverySnapshotInStableOrder() {
        let meal = MealTemplate(
            name: "Lunch set",
            defaultMeal: .lunch,
            defaultSnackIndex: 0,
            creationOperationID: UUID(),
            creationFingerprint: "selection-test"
        )
        let firstFood = makeTestFoodItem(name: "Soup")
        let secondFood = makeTestFoodItem(name: "Bread")
        let snapshots = [
            FoodLogEntrySnapshot(
                foodItem: firstFood,
                portionGrams: 300,
                mealType: .lunch,
                snackIndex: 0
            ),
            FoodLogEntrySnapshot(
                foodItem: secondFood,
                portionGrams: 60,
                mealType: .lunch,
                snackIndex: 0
            ),
        ]

        let group = MultiAddSelectionGroup.meal(meal, snapshots: snapshots)

        XCTAssertEqual(group.id, .meal(meal.id))
        XCTAssertEqual(group.items.map(\.snapshot.foodName), ["Soup", "Bread"])
        XCTAssertEqual(group.items.map(\.snapshot.portionGrams), [300, 60])
        XCTAssertTrue(group.items.allSatisfy { $0.source == .local })
        XCTAssertEqual(group.items.map(\.originMealID), [meal.id, meal.id])
        XCTAssertEqual(group.items.map(\.originMealName), ["Lunch set", "Lunch set"])
    }

    func testRemoteDraftKeepsStableFoodIdentityForReviewAndCommit() throws {
        let product = try makeRemoteProduct()
        let result = makeTestSearchResult(product: product)
        let group = MultiAddSelectionGroup.remoteProduct(
            result,
            searchService: FoodSearchService(),
            meal: .dinner,
            snackIndex: 0
        )
        let item = try XCTUnwrap(group.items.first)

        guard case .remote(let foodID, let storedResult) = item.source else {
            return XCTFail("Expected remote source")
        }
        XCTAssertEqual(group.id, .remoteProduct(product.id))
        XCTAssertEqual(storedResult, result)
        XCTAssertEqual(item.snapshot.sourceFoodID, foodID)
        XCTAssertEqual(item.snapshot.portionGrams, 150)
        XCTAssertEqual(item.snapshot.mealType, .dinner)
        XCTAssertEqual(
            item.snapshot.dataSourceSnapshotRaw,
            FoodDataSource.openFoodFactsCommunity.rawValue
        )
        XCTAssertEqual(
            item.snapshot.nutritionCompletenessSnapshotRaw,
            NutritionCompleteness.complete.rawValue
        )
        XCTAssertEqual(item.snapshot.recoveredByFallbackSnapshotRaw, true)
    }

    func testReviewPortionScalingPreservesSnapshotIdentityAndScalesNutrition() {
        let food = makeTestFoodItem(
            name: "Skyr",
            caloriesPer100g: 80,
            proteinPer100g: 10
        )
        let original = FoodLogEntrySnapshot(
            foodItem: food,
            portionGrams: 100,
            mealType: .breakfast,
            snackIndex: 0
        )

        let scaled = original.scaled(toPortionGrams: 250)

        XCTAssertEqual(scaled.sourceFoodID, original.sourceFoodID)
        XCTAssertEqual(scaled.foodName, original.foodName)
        XCTAssertEqual(scaled.portionGrams, 250)
        XCTAssertEqual(scaled.nutrition.calories, 200)
        XCTAssertEqual(scaled.nutrition.proteinG, 25)
    }

    func testSelectionStateTogglesGroupsAndCountsExpandedMealItems() {
        let food = makeTestFoodItem(name: "Oats")
        let direct = MultiAddSelectionGroup.savedFood(
            food,
            portionGrams: 80,
            meal: .breakfast,
            snackIndex: 0
        )
        let meal = MealTemplate(
            name: "Breakfast set",
            defaultMeal: .breakfast,
            defaultSnackIndex: 0,
            creationOperationID: UUID(),
            creationFingerprint: "selection-state"
        )
        let authoredMeal = MultiAddSelectionGroup.meal(
            meal,
            snapshots: [direct.items[0].snapshot, direct.items[0].snapshot]
        )
        var state = MultiAddSelectionState()

        state.toggle(direct)
        state.toggle(authoredMeal)
        XCTAssertEqual(state.groups.map(\.id), [direct.id, authoredMeal.id])
        XCTAssertEqual(state.itemCount, 3)

        state.toggle(direct)
        XCTAssertFalse(state.contains(direct.id))
        XCTAssertEqual(state.itemCount, 2)

        state.removeAll()
        XCTAssertTrue(state.groups.isEmpty)
        XCTAssertEqual(state.itemCount, 0)
    }

    private func makeRemoteProduct() throws -> OpenFoodFactsProduct {
        let json = """
        {
          "code": "selection-product",
          "product_name": "Remote yogurt",
          "serving_quantity": 150,
          "nutriments": {
            "energy-kcal_100g": 80,
            "proteins_100g": 9,
            "carbohydrates_100g": 7,
            "fat_100g": 2,
            "fiber_100g": 0
          }
        }
        """
        return try JSONDecoder().decode(
            OpenFoodFactsProduct.self,
            from: Data(json.utf8)
        )
    }
}
