import SwiftData
import XCTest
@testable import Caloryn

@MainActor
final class FavoriteFoodLoggingTests: XCTestCase {
    func testLegacyNilStorageMigratesAsNotFavorited() {
        let food = makeTestFoodItem(name: "Legacy Food")

        XCTAssertNil(food.isPinnedRaw)
        XCTAssertFalse(food.isFavorite)
        XCTAssertNil(food.pinnedAt)
    }

    func testFavoriteStatePersistsAcrossModelContexts() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let food = makeTestFoodItem(name: "Persistent Favorite", isCustom: true)
        let favoritedAt = makeTestDate(year: 2026, month: 7, day: 20, hour: 8)
        context.insert(food)
        try FavoriteFoodLogging.setFavorite(
            true,
            for: food,
            modelContext: context,
            at: favoritedAt
        )

        let reloadedContext = ModelContext(container)
        let reloadedFoods = try reloadedContext.fetch(FetchDescriptor<FoodItem>())
        let reloaded = try XCTUnwrap(reloadedFoods.first { $0.id == food.id })

        XCTAssertTrue(reloaded.isFavorite)
        XCTAssertEqual(reloaded.pinnedAt, favoritedAt)
    }

    func testRemovingFavoriteClearsOrderingMetadata() {
        let food = makeTestFoodItem(isCustom: true)
        food.setFavorite(true, at: makeTestDate(year: 2026, month: 7, day: 20))

        food.setFavorite(false)

        XCTAssertFalse(food.isFavorite)
        XCTAssertNil(food.pinnedAt)
    }

    func testOnlyUserCreatedFoodsCanBecomeFavorites() throws {
        let context = ModelContext(try makeContainer())
        let catalogFood = makeTestFoodItem(name: "Catalog Food")
        context.insert(catalogFood)

        XCTAssertThrowsError(
            try FavoriteFoodLogging.setFavorite(
                true,
                for: catalogFood,
                modelContext: context
            )
        ) { error in
            XCTAssertEqual(
                error as? FavoriteFoodLogging.FavoriteError,
                .requiresUserCreatedFood
            )
        }
        XCTAssertFalse(catalogFood.isFavorite)
        XCTAssertNil(catalogFood.isPinnedRaw)
        XCTAssertNil(catalogFood.pinnedAt)
    }

    func testLegacyCatalogSelectionIsNotExposedAsFavorite() {
        let catalogFood = makeTestFoodItem(name: "Legacy Catalog Food")
        catalogFood.isPinnedRaw = true
        catalogFood.pinnedAt = makeTestDate(year: 2026, month: 7, day: 20)

        XCTAssertFalse(catalogFood.isFavorite)
        XCTAssertTrue(
            FavoriteFoodLogging.sortedFavorites(from: [catalogFood]).isEmpty
        )
    }

    func testRecipesAndManualEntriesAreEligibleFavorites() {
        let manualEntry = makeTestFoodItem(name: "Manual", isCustom: true)
        let recipe = makeTestFoodItem(name: "Recipe", isRecipe: true)
        manualEntry.setFavorite(true)
        recipe.setFavorite(true)

        let favorites = FavoriteFoodLogging.sortedFavorites(
            from: [manualEntry, recipe]
        )

        XCTAssertEqual(Set(favorites.map(\.id)), Set([manualEntry.id, recipe.id]))
    }

    func testFavoriteDisclosureShowsFiveUntilExpanded() {
        let favorites = (0..<7).map { index in
            let food = makeTestFoodItem(
                name: "Favorite \(index)",
                isCustom: true
            )
            food.setFavorite(
                true,
                at: makeTestDate(
                    year: 2026,
                    month: 7,
                    day: 20,
                    hour: index
                )
            )
            return food
        }

        let collapsed = FavoriteFoodLogging.visibleFavorites(
            from: favorites,
            showsAll: false
        )
        let expanded = FavoriteFoodLogging.visibleFavorites(
            from: favorites,
            showsAll: true
        )

        XCTAssertEqual(collapsed.count, 5)
        XCTAssertEqual(collapsed.map(\.name), [
            "Favorite 6",
            "Favorite 5",
            "Favorite 4",
            "Favorite 3",
            "Favorite 2",
        ])
        XCTAssertEqual(
            FavoriteFoodLogging.hiddenFavoriteCount(
                from: favorites,
                showsAll: false
            ),
            2
        )
        XCTAssertEqual(expanded.count, 7)
        XCTAssertEqual(
            FavoriteFoodLogging.hiddenFavoriteCount(
                from: favorites,
                showsAll: true
            ),
            0
        )
    }

    func testPlanUsesLatestPortionOnOrBeforeDestinationAndIgnoresFutureLogs() throws {
        let context = ModelContext(try makeContainer())
        let food = makeTestFoodItem(name: "Skyr")
        context.insert(food)
        let older = makeTestEntry(
            date: makeTestDate(year: 2026, month: 7, day: 18),
            mealType: .breakfast,
            foodItem: food,
            portionGrams: 120
        )
        older.createdAt = makeTestDate(year: 2026, month: 7, day: 18, hour: 9)
        let latestEligible = makeTestEntry(
            date: makeTestDate(year: 2026, month: 7, day: 20),
            mealType: .snack,
            foodItem: food,
            portionGrams: 170
        )
        latestEligible.createdAt = makeTestDate(year: 2026, month: 7, day: 20, hour: 18)
        let future = makeTestEntry(
            date: makeTestDate(year: 2026, month: 7, day: 22),
            mealType: .dinner,
            foodItem: food,
            portionGrams: 300
        )
        future.createdAt = makeTestDate(year: 2026, month: 7, day: 21, hour: 7)
        [older, latestEligible, future].forEach(context.insert)
        try context.save()

        let destination = makeTestDate(year: 2026, month: 7, day: 21, hour: 14)
        let plan = FavoriteFoodLogging.plan(
            for: food,
            destinationMeal: .lunch,
            destinationDate: destination
        )

        XCTAssertEqual(plan.action, .log(portionGrams: 170))
        XCTAssertEqual(plan.destinationDate, destination.startOfDay)
        XCTAssertEqual(plan.destinationMeal, .lunch)
    }

    func testPlanUsesCreationTimeToBreakSameDayTies() throws {
        let context = ModelContext(try makeContainer())
        let food = makeTestFoodItem(name: "Coffee")
        context.insert(food)
        let first = makeTestEntry(
            date: makeTestDate(year: 2026, month: 7, day: 20),
            foodItem: food,
            portionGrams: 200
        )
        first.createdAt = makeTestDate(year: 2026, month: 7, day: 20, hour: 8)
        let second = makeTestEntry(
            date: makeTestDate(year: 2026, month: 7, day: 20),
            foodItem: food,
            portionGrams: 250
        )
        second.createdAt = makeTestDate(year: 2026, month: 7, day: 20, hour: 10)
        context.insert(first)
        context.insert(second)
        try context.save()

        let plan = FavoriteFoodLogging.plan(
            for: food,
            destinationMeal: .breakfast,
            destinationDate: makeTestDate(year: 2026, month: 7, day: 20)
        )

        XCTAssertEqual(plan.action, .log(portionGrams: 250))
    }

    func testExactRecencyTieWithDifferentPortionsRequiresConfirmation() throws {
        let context = ModelContext(try makeContainer())
        let food = makeTestFoodItem(name: "Ambiguous Favorite")
        context.insert(food)
        let sharedDate = makeTestDate(year: 2026, month: 7, day: 20)
        let sharedCreatedAt = makeTestDate(year: 2026, month: 7, day: 20, hour: 10)
        let first = makeTestEntry(date: sharedDate, foodItem: food, portionGrams: 100)
        first.createdAt = sharedCreatedAt
        let second = makeTestEntry(date: sharedDate, foodItem: food, portionGrams: 200)
        second.createdAt = sharedCreatedAt
        context.insert(first)
        context.insert(second)
        try context.save()

        let plan = FavoriteFoodLogging.plan(
            for: food,
            destinationMeal: .breakfast,
            destinationDate: sharedDate
        )

        XCTAssertEqual(plan.action, .confirmQuantity)
    }

    func testPlanRequestsConfirmationWhenThereIsNoPreviousPortion() throws {
        let context = ModelContext(try makeContainer())
        let food = makeTestFoodItem(name: "New Favorite", defaultServingG: 45)
        context.insert(food)
        try context.save()

        let plan = FavoriteFoodLogging.plan(
            for: food,
            destinationMeal: .dinner,
            destinationDate: makeTestDate(year: 2026, month: 7, day: 20)
        )

        XCTAssertEqual(plan.action, .confirmQuantity)
    }

    func testInvalidLatestPortionDoesNotSilentlyFallBackToOlderHistory() throws {
        let context = ModelContext(try makeContainer())
        let food = makeTestFoodItem(name: "Corrupted History")
        context.insert(food)
        let older = makeTestEntry(
            date: makeTestDate(year: 2026, month: 7, day: 18),
            foodItem: food,
            portionGrams: 100
        )
        let latest = makeTestEntry(
            date: makeTestDate(year: 2026, month: 7, day: 19),
            foodItem: food,
            portionGrams: 200
        )
        latest.portionGrams = 0
        context.insert(older)
        context.insert(latest)
        try context.save()

        let plan = FavoriteFoodLogging.plan(
            for: food,
            destinationMeal: .lunch,
            destinationDate: makeTestDate(year: 2026, month: 7, day: 20)
        )

        XCTAssertEqual(plan.action, .confirmQuantity)
    }

    func testOneTapLogUsesExplicitDestinationRatherThanHistoricalMealAndDate() throws {
        let context = ModelContext(try makeContainer())
        let food = makeTestFoodItem(name: "Repeat Lunch")
        context.insert(food)
        let previous = makeTestEntry(
            date: makeTestDate(year: 2026, month: 7, day: 18),
            mealType: .breakfast,
            foodItem: food,
            portionGrams: 135
        )
        context.insert(previous)
        try context.save()
        let destination = makeTestDate(year: 2026, month: 7, day: 21, hour: 17)
        let now = makeTestDate(year: 2026, month: 7, day: 21, hour: 17, minute: 30)
        let plan = FavoriteFoodLogging.plan(
            for: food,
            destinationMeal: .dinner,
            destinationDate: destination
        )

        let logged = try FavoriteFoodLogging.log(
            plan: plan,
            food: food,
            modelContext: context,
            now: now
        )

        XCTAssertEqual(logged.portionGrams, 135)
        XCTAssertEqual(logged.date, destination.startOfDay)
        XCTAssertEqual(logged.mealType, .dinner)
        XCTAssertEqual(logged.snackIndex, 0)
        XCTAssertEqual(food.lastUsed, now)
    }

    func testOneTapLogPreservesExplicitSnackSlot() throws {
        let context = ModelContext(try makeContainer())
        let food = makeTestFoodItem(name: "Afternoon Snack")
        context.insert(food)
        let previous = makeTestEntry(
            date: makeTestDate(year: 2026, month: 7, day: 18),
            mealType: .snack,
            foodItem: food,
            portionGrams: 80,
            snackIndex: 1
        )
        context.insert(previous)
        try context.save()
        let destination = makeTestDate(year: 2026, month: 7, day: 21)
        let plan = FavoriteFoodLogging.plan(
            for: food,
            destinationMeal: .snack,
            destinationDate: destination,
            destinationSnackIndex: 3
        )

        let logged = try FavoriteFoodLogging.log(
            plan: plan,
            food: food,
            modelContext: context
        )

        XCTAssertEqual(plan.destinationSnackIndex, 3)
        XCTAssertEqual(logged.mealType, .snack)
        XCTAssertEqual(logged.snackIndex, 3)
    }

    func testEditingLatestLogImmediatelyChangesNextFavoritePortion() throws {
        let context = ModelContext(try makeContainer())
        let food = makeTestFoodItem(name: "Editable Favorite")
        let entry = makeTestEntry(
            date: makeTestDate(year: 2026, month: 7, day: 20),
            foodItem: food,
            portionGrams: 100
        )
        context.insert(food)
        context.insert(entry)
        try context.save()

        DailyFoodLogCommands.updateLoggedEntry(
            entry,
            date: entry.date,
            mealType: .snack,
            foodItem: food,
            portionGrams: 225
        )

        let plan = FavoriteFoodLogging.plan(
            for: food,
            destinationMeal: .lunch,
            destinationDate: makeTestDate(year: 2026, month: 7, day: 21)
        )
        XCTAssertEqual(plan.action, .log(portionGrams: 225))
    }

    func testDeletingLatestLogFallsBackToPreviousLiveLog() throws {
        let context = ModelContext(try makeContainer())
        let food = makeTestFoodItem(name: "Deletion Favorite")
        context.insert(food)
        let older = makeTestEntry(
            date: makeTestDate(year: 2026, month: 7, day: 18),
            foodItem: food,
            portionGrams: 90
        )
        let latest = makeTestEntry(
            date: makeTestDate(year: 2026, month: 7, day: 20),
            foodItem: food,
            portionGrams: 180
        )
        context.insert(older)
        context.insert(latest)
        try context.save()

        DailyFoodLogCommands.deleteLoggedEntry(latest, modelContext: context)
        try context.save()

        let plan = FavoriteFoodLogging.plan(
            for: food,
            destinationMeal: .breakfast,
            destinationDate: makeTestDate(year: 2026, month: 7, day: 21)
        )
        XCTAssertEqual(plan.action, .log(portionGrams: 90))
    }

    func testDeletingFavoriteCannotLeaveBrokenFavoriteRecord() throws {
        let context = ModelContext(try makeContainer())
        let food = makeTestFoodItem(name: "Delete Me", isCustom: true)
        context.insert(food)
        food.setFavorite(true)
        try context.save()

        food.deletePreservingLogEntrySnapshots(from: context)
        try context.save()

        let remainingFoods = try context.fetch(FetchDescriptor<FoodItem>())
        XCTAssertTrue(FavoriteFoodLogging.sortedFavorites(from: remainingFoods).isEmpty)
    }

    func testDuplicateNamesRemainSeparateFavoritesWithStableIdentity() {
        let first = makeTestFoodItem(name: "Oatmeal", brand: "Brand A", isCustom: true)
        let second = makeTestFoodItem(name: "Oatmeal", brand: "Brand B", isCustom: true)
        first.setFavorite(true, at: makeTestDate(year: 2026, month: 7, day: 20, hour: 8))
        second.setFavorite(true, at: makeTestDate(year: 2026, month: 7, day: 20, hour: 9))

        let favorites = FavoriteFoodLogging.sortedFavorites(from: [first, second])

        XCTAssertEqual(favorites.map(\.id), [second.id, first.id])
        XCTAssertEqual(Set(favorites.map(\.id)).count, 2)
    }

    func testUnavailableRecipeIsSurfacedInsteadOfLogged() {
        let recipe = makeTestFoodItem(
            name: "Unavailable Recipe",
            caloriesPer100g: 0,
            proteinPer100g: 0,
            carbsPer100g: 0,
            fatPer100g: 0,
            isRecipe: true
        )
        recipe.recipeIngredients = []

        let plan = FavoriteFoodLogging.plan(
            for: recipe,
            destinationMeal: .dinner,
            destinationDate: makeTestDate(year: 2026, month: 7, day: 20)
        )

        XCTAssertEqual(plan.action, .unavailable)
    }

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: UserProfile.self,
            FoodItem.self,
            FoodLogEntry.self,
            RecipeIngredient.self,
            configurations: configuration
        )
    }
}
