import SwiftData
import XCTest
@testable import Caloryn

@MainActor
final class PinnedFoodLoggingTests: XCTestCase {
    func testLegacyNilPinStateMigratesAsUnpinned() {
        let food = makeTestFoodItem(name: "Legacy Food")

        XCTAssertNil(food.isPinnedRaw)
        XCTAssertFalse(food.isPinned)
        XCTAssertNil(food.pinnedAt)
    }

    func testPinStatePersistsAcrossModelContexts() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let food = makeTestFoodItem(name: "Persistent Favorite")
        let pinnedAt = makeTestDate(year: 2026, month: 7, day: 20, hour: 8)
        context.insert(food)
        try PinnedFoodLogging.setPinned(
            true,
            for: food,
            modelContext: context,
            at: pinnedAt
        )

        let reloadedContext = ModelContext(container)
        let reloadedFoods = try reloadedContext.fetch(FetchDescriptor<FoodItem>())
        let reloaded = try XCTUnwrap(reloadedFoods.first { $0.id == food.id })

        XCTAssertTrue(reloaded.isPinned)
        XCTAssertEqual(reloaded.pinnedAt, pinnedAt)
    }

    func testUnpinClearsOrderingMetadata() {
        let food = makeTestFoodItem()
        food.setPinned(true, at: makeTestDate(year: 2026, month: 7, day: 20))

        food.setPinned(false)

        XCTAssertFalse(food.isPinned)
        XCTAssertNil(food.pinnedAt)
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
        let plan = PinnedFoodLogging.plan(
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

        let plan = PinnedFoodLogging.plan(
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

        let plan = PinnedFoodLogging.plan(
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

        let plan = PinnedFoodLogging.plan(
            for: food,
            destinationMeal: .dinner,
            destinationDate: makeTestDate(year: 2026, month: 7, day: 20)
        )

        XCTAssertEqual(plan.action, .confirmQuantity)
        XCTAssertEqual(PinnedFoodLogging.suggestedPortion(for: food), 45)
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

        let plan = PinnedFoodLogging.plan(
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
        let plan = PinnedFoodLogging.plan(
            for: food,
            destinationMeal: .dinner,
            destinationDate: destination
        )

        let logged = try PinnedFoodLogging.log(
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
        let plan = PinnedFoodLogging.plan(
            for: food,
            destinationMeal: .snack,
            destinationDate: destination,
            destinationSnackIndex: 3
        )

        let logged = try PinnedFoodLogging.log(
            plan: plan,
            food: food,
            modelContext: context
        )

        XCTAssertEqual(plan.destinationSnackIndex, 3)
        XCTAssertEqual(logged.mealType, .snack)
        XCTAssertEqual(logged.snackIndex, 3)
    }

    func testLargeSuggestedPortionFitsWithinConfirmationRange() {
        let food = makeTestFoodItem(
            name: "Large Recipe",
            defaultServingG: 1_000
        )

        let suggested = PinnedFoodLogging.suggestedPortion(for: food)
        let maximum = PinnedFoodLogging.maximumConfirmationPortion(for: food)

        XCTAssertEqual(suggested, 1_000)
        XCTAssertEqual(maximum, 4_000)
        XCTAssertLessThanOrEqual(suggested, maximum)
    }

    func testEditingLatestLogImmediatelyChangesNextPinnedPortion() throws {
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

        let plan = PinnedFoodLogging.plan(
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

        let plan = PinnedFoodLogging.plan(
            for: food,
            destinationMeal: .breakfast,
            destinationDate: makeTestDate(year: 2026, month: 7, day: 21)
        )
        XCTAssertEqual(plan.action, .log(portionGrams: 90))
    }

    func testDeletingPinnedFoodCannotLeaveBrokenPinnedRecord() throws {
        let context = ModelContext(try makeContainer())
        let food = makeTestFoodItem(name: "Delete Me", isCustom: true)
        context.insert(food)
        food.setPinned(true)
        try context.save()

        food.deletePreservingLogEntrySnapshots(from: context)
        try context.save()

        let remainingFoods = try context.fetch(FetchDescriptor<FoodItem>())
        XCTAssertTrue(PinnedFoodLogging.sortedPinnedFoods(from: remainingFoods).isEmpty)
    }

    func testDuplicateNamesRemainSeparateFavoritesWithStableIdentity() {
        let first = makeTestFoodItem(name: "Oatmeal", brand: "Brand A")
        let second = makeTestFoodItem(name: "Oatmeal", brand: "Brand B")
        first.setPinned(true, at: makeTestDate(year: 2026, month: 7, day: 20, hour: 8))
        second.setPinned(true, at: makeTestDate(year: 2026, month: 7, day: 20, hour: 9))

        let favorites = PinnedFoodLogging.sortedPinnedFoods(from: [first, second])

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

        let plan = PinnedFoodLogging.plan(
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
