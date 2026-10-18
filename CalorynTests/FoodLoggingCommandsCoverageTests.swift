import Foundation
import SwiftData
import Testing
@testable import Caloryn

private func fixedCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}

private func fixedDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
    fixedCalendar().date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

@MainActor
private func makeLoggingContainer() throws -> ModelContainer {
    try ModelContainer(
        for: UserProfile.self,
        FoodItem.self,
        FoodLogEntry.self,
        RecipeIngredient.self,
        MealTemplate.self,
        MealTemplateItem.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
}

/// The user-facing message an error carries, so a test checks both which
/// error was thrown and what the user is told.
@MainActor
private func message<T>(of operation: () throws -> T) -> String? {
    do {
        _ = try operation()
        return nil
    } catch {
        return (error as? LocalizedError)?.errorDescription ?? "\(error)"
    }
}

// MARK: - Favorites

@MainActor
@Suite("Favorite food logging coverage")
struct FavoriteFoodLoggingCoverageTests {
    @Test("A favorite cannot be logged from a plan made for a different food")
    func stalePlanIsRejected() throws {
        let context = ModelContext(try makeLoggingContainer())
        let planned = makeTestFoodItem(name: "Planned", isCustom: true)
        let other = makeTestFoodItem(name: "Other", isCustom: true)
        context.insert(planned)
        context.insert(other)
        let plan = FavoriteFoodLogPlan(
            foodID: planned.id,
            destinationDate: fixedDate(2026, 7, 22, 0),
            destinationMeal: .lunch,
            destinationSnackIndex: 0,
            action: .log(portionGrams: 100)
        )

        #expect(message { try FavoriteFoodLogging.log(plan: plan, food: other, modelContext: context) }
            == "This favorite changed. Please try again.")
        #expect(try context.fetchCount(FetchDescriptor<FoodLogEntry>()) == 0)
    }

    @Test("A favorite with no remembered portion asks for a quantity instead of logging")
    func confirmQuantityPlanIsNotLogged() throws {
        let context = ModelContext(try makeLoggingContainer())
        let food = makeTestFoodItem(name: "Fresh", isCustom: true)
        context.insert(food)
        try context.save()
        let plan = FavoriteFoodLogging.plan(
            for: food,
            destinationMeal: .breakfast,
            destinationDate: fixedDate(2026, 7, 22),
            calendar: fixedCalendar()
        )
        #expect(plan.action == .confirmQuantity)

        #expect(message { try FavoriteFoodLogging.log(plan: plan, food: food, modelContext: context) }
            == "Choose a valid quantity before logging.")
        #expect(try context.fetchCount(FetchDescriptor<FoodLogEntry>()) == 0)
    }

    @Test("An unavailable favorite is never logged, whether it was unavailable when planned or became so after")
    func unavailableFavoritesAreNotLogged() throws {
        let context = ModelContext(try makeLoggingContainer())
        let food = makeTestFoodItem(name: "Soon blank", isCustom: true)
        context.insert(food)
        let unavailableMessage = "This favorite is unavailable. Edit it or remove it from Favorites before logging."

        let unavailablePlan = FavoriteFoodLogPlan(
            foodID: food.id,
            destinationDate: fixedDate(2026, 7, 22, 0),
            destinationMeal: .lunch,
            destinationSnackIndex: 0,
            action: .unavailable
        )
        #expect(message { try FavoriteFoodLogging.log(plan: unavailablePlan, food: food, modelContext: context) }
            == unavailableMessage)

        let readyPlan = FavoriteFoodLogPlan(
            foodID: food.id,
            destinationDate: fixedDate(2026, 7, 22, 0),
            destinationMeal: .lunch,
            destinationSnackIndex: 0,
            action: .log(portionGrams: 100)
        )
        food.name = "   "
        #expect(message { try FavoriteFoodLogging.log(plan: readyPlan, food: food, modelContext: context) }
            == unavailableMessage)
        #expect(try context.fetchCount(FetchDescriptor<FoodLogEntry>()) == 0)
    }

    @Test("A plan carrying an unsafe portion asks for a quantity rather than logging it", arguments: [0.0, -5, 100_000.5])
    func unsafePlannedPortionIsRejected(portion: Double) throws {
        let context = ModelContext(try makeLoggingContainer())
        let food = makeTestFoodItem(name: "Rice", isCustom: true)
        context.insert(food)
        let plan = FavoriteFoodLogPlan(
            foodID: food.id,
            destinationDate: fixedDate(2026, 7, 22, 0),
            destinationMeal: .dinner,
            destinationSnackIndex: 0,
            action: .log(portionGrams: portion)
        )

        #expect(message { try FavoriteFoodLogging.log(plan: plan, food: food, modelContext: context) }
            == "Choose a valid quantity before logging.")
        #expect(try context.fetchCount(FetchDescriptor<FoodLogEntry>()) == 0)
    }

    @Test("A favorite logs its planned portion into the planned meal, with the portion's nutrition")
    func plannedPortionIsLogged() throws {
        let context = ModelContext(try makeLoggingContainer())
        let food = makeTestFoodItem(name: "Skyr", caloriesPer100g: 63, proteinPer100g: 11, isCustom: true)
        context.insert(food)
        let plan = FavoriteFoodLogPlan(
            foodID: food.id,
            destinationDate: fixedDate(2026, 7, 22, 0),
            destinationMeal: .snack,
            destinationSnackIndex: 2,
            action: .log(portionGrams: 170)
        )

        let entry = try FavoriteFoodLogging.log(
            plan: plan,
            food: food,
            modelContext: context,
            now: fixedDate(2026, 7, 22, 15)
        )

        #expect(entry.portionGrams == 170)
        #expect(entry.mealType == .snack)
        #expect(entry.snackIndex == 2)
        // 63 kcal × 1.7 and 11 g × 1.7.
        #expect(abs(entry.calories - 107.1) < 1e-9)
        #expect(abs(entry.proteinG - 18.7) < 1e-9)
        #expect(food.lastUsed == fixedDate(2026, 7, 22, 15))
        #expect(try context.fetchCount(FetchDescriptor<FoodLogEntry>()) == 1)
    }

    @Test("The only-user-created error explains which foods can be favorites")
    func favoriteErrorDescription() {
        #expect(FavoriteFoodLogging.FavoriteError.requiresUserCreatedFood.errorDescription
            == "Only manual entries and recipes can be added to Favorites.")
    }

    @Test("Favorites pinned at the same moment are ordered by name, ignoring case, then by identity")
    func samePinTimeOrdersByNameThenIdentity() throws {
        let pinned = fixedDate(2026, 7, 20, 8)
        let banana = makeTestFoodItem(name: "banana", isCustom: true)
        let apple = makeTestFoodItem(name: "Apple", isCustom: true)
        let cherryB = makeTestFoodItem(name: "Cherry", isCustom: true)
        cherryB.id = try #require(UUID(uuidString: "00000000-0000-0000-0000-0000000000BB"))
        let cherryA = makeTestFoodItem(name: "cherry", isCustom: true)
        cherryA.id = try #require(UUID(uuidString: "00000000-0000-0000-0000-0000000000AA"))
        let newest = makeTestFoodItem(name: "Zucchini", isCustom: true)
        let notFavorite = makeTestFoodItem(name: "Aardvark", isCustom: true)
        for food in [banana, apple, cherryB, cherryA] {
            food.setFavorite(true, at: pinned)
        }
        newest.setFavorite(true, at: fixedDate(2026, 7, 21, 8))

        let sorted = FavoriteFoodLogging.sortedFavorites(from: [banana, cherryB, notFavorite, apple, newest, cherryA])

        let sortedIDs: [UUID] = sorted.map(\.id)
        let expectedIDs: [UUID] = [newest.id, apple.id, banana.id, cherryA.id, cherryB.id]
        #expect(sortedIDs == expectedIDs)
    }

    @Test("Six favorites collapse to five with one hidden, and expand to all six")
    func favoritesDisclosureCounts() {
        let foods = (0..<6).map { index -> FoodItem in
            let food = makeTestFoodItem(name: "Food \(index)", isCustom: true)
            food.setFavorite(true, at: fixedDate(2026, 7, 1 + index, 8))
            return food
        }

        #expect(FavoriteFoodLogging.visibleFavorites(from: foods, showsAll: false).map(\.name)
            == ["Food 5", "Food 4", "Food 3", "Food 2", "Food 1"])
        #expect(FavoriteFoodLogging.hiddenFavoriteCount(from: foods, showsAll: false) == 1)
        #expect(FavoriteFoodLogging.visibleFavorites(from: foods, showsAll: true).count == 6)
        #expect(FavoriteFoodLogging.hiddenFavoriteCount(from: foods, showsAll: true) == 0)
        #expect(FavoriteFoodLogging.hiddenFavoriteCount(from: Array(foods.prefix(3)), showsAll: false) == 0)
    }

    @Test(
        "A portion is safe when it is finite, positive and at most 100 kg",
        arguments: [
            (0.0, false), (-1, false), (0.001, true), (1, true),
            (100_000, true), (100_000.001, false), (.infinity, false), (.nan, false),
        ]
    )
    func portionSafety(portion: Double, isSafe: Bool) {
        #expect(FavoriteFoodLogging.isSafePortion(portion) == isSafe)
    }

    @Test("A food is unavailable with a blank name or any negative or non-finite core nutrient")
    func availabilityRules() {
        #expect(FavoriteFoodLogging.isAvailableForLogging(makeTestFoodItem(name: "Fine")))
        #expect(!FavoriteFoodLogging.isAvailableForLogging(makeTestFoodItem(name: " \n")))
        #expect(!FavoriteFoodLogging.isAvailableForLogging(makeTestFoodItem(caloriesPer100g: .nan)))
        #expect(!FavoriteFoodLogging.isAvailableForLogging(makeTestFoodItem(proteinPer100g: -0.1)))
        #expect(!FavoriteFoodLogging.isAvailableForLogging(makeTestFoodItem(carbsPer100g: .infinity)))
        #expect(!FavoriteFoodLogging.isAvailableForLogging(makeTestFoodItem(fatPer100g: -1)))
        #expect(!FavoriteFoodLogging.isAvailableForLogging(makeTestFoodItem(fiberPer100g: -2)))
        #expect(FavoriteFoodLogging.isAvailableForLogging(makeTestFoodItem(caloriesPer100g: 0)))
    }

    @Test("A recipe is available only with ingredients and a safe total weight")
    func recipeAvailability() {
        // An ingredient belongs to one recipe, so each recipe gets its own.
        func ingredient() -> RecipeIngredient {
            RecipeIngredient(
                name: "Rice", portionGrams: 200, caloriesPer100g: 130,
                proteinPer100g: 2.7, carbsPer100g: 28, fatPer100g: 0.3, sortOrder: 0
            )
        }
        let complete = makeTestFoodItem(name: "Bowl", defaultServingG: 200, isRecipe: true)
        complete.recipeIngredients = [ingredient()]
        let noWeight = makeTestFoodItem(name: "Bowl", isRecipe: true)
        noWeight.recipeIngredients = [ingredient()]
        let tooHeavy = makeTestFoodItem(name: "Bowl", defaultServingG: 200_000, isRecipe: true)
        tooHeavy.recipeIngredients = [ingredient()]
        let noIngredients = makeTestFoodItem(name: "Bowl", defaultServingG: 200, isRecipe: true)
        noIngredients.recipeIngredients = nil

        #expect(FavoriteFoodLogging.isAvailableForLogging(complete))
        #expect(!FavoriteFoodLogging.isAvailableForLogging(noWeight))
        #expect(!FavoriteFoodLogging.isAvailableForLogging(tooHeavy))
        #expect(!FavoriteFoodLogging.isAvailableForLogging(noIngredients))
    }

    @Test("A favorite's plan reuses the last portion logged by the end of the destination day, not one dated the next midnight")
    func planStopsAtTheNextMidnight() throws {
        let context = ModelContext(try makeLoggingContainer())
        let food = makeTestFoodItem(name: "Porridge", isCustom: true)
        context.insert(food)
        // Dates are set after construction, because the initialiser snaps them
        // to the machine's own start of day.
        let sameDay = makeTestEntry(foodItem: food, portionGrams: 200)
        sameDay.date = fixedDate(2026, 7, 22, 0)
        sameDay.createdAt = fixedDate(2026, 7, 22, 8)
        let nextMidnight = makeTestEntry(foodItem: food, portionGrams: 300)
        nextMidnight.date = fixedDate(2026, 7, 23, 0)
        nextMidnight.createdAt = fixedDate(2026, 7, 21, 8)
        context.insert(sameDay)
        context.insert(nextMidnight)
        try context.save()

        let plan = FavoriteFoodLogging.plan(
            for: food,
            destinationMeal: .lunch,
            destinationDate: fixedDate(2026, 7, 22, 9),
            calendar: fixedCalendar()
        )

        #expect(plan.action == .log(portionGrams: 200))
        #expect(plan.destinationDate == fixedDate(2026, 7, 22, 0))

        let nextDayPlan = FavoriteFoodLogging.plan(
            for: food,
            destinationMeal: .lunch,
            destinationDate: fixedDate(2026, 7, 23, 9),
            calendar: fixedCalendar()
        )
        #expect(nextDayPlan.action == .log(portionGrams: 300))
    }

    @Test("The most recently created log's portion is reused, whatever its meal or date")
    func mostRecentPortionIgnoresMealAndDate() throws {
        let context = ModelContext(try makeLoggingContainer())
        let food = makeTestFoodItem(name: "Coffee", isCustom: true)
        context.insert(food)
        let olderButLaterDay = makeTestEntry(date: fixedDate(2026, 7, 25), mealType: .dinner, foodItem: food, portionGrams: 300)
        olderButLaterDay.createdAt = fixedDate(2026, 7, 20, 8)
        let newest = makeTestEntry(date: fixedDate(2026, 7, 18), mealType: .breakfast, foodItem: food, portionGrams: 240)
        newest.createdAt = fixedDate(2026, 7, 21, 8)
        context.insert(olderButLaterDay)
        context.insert(newest)
        try context.save()

        #expect(FavoriteFoodLogging.mostRecentlyLoggedSafePortion(for: food) == 240)
    }

    @Test("Logs created at the same instant agree on a portion only when they match")
    func sameInstantLogsMustAgree() throws {
        let context = ModelContext(try makeLoggingContainer())
        let instant = fixedDate(2026, 7, 21, 8)
        let agreeing = makeTestFoodItem(name: "Agreeing", isCustom: true)
        let disagreeing = makeTestFoodItem(name: "Disagreeing", isCustom: true)
        context.insert(agreeing)
        context.insert(disagreeing)
        for (food, portions) in [(agreeing, [150.0, 150.0]), (disagreeing, [150.0, 90.0])] {
            for portion in portions {
                let entry = makeTestEntry(foodItem: food, portionGrams: portion)
                entry.createdAt = instant
                context.insert(entry)
            }
        }
        try context.save()

        #expect(FavoriteFoodLogging.mostRecentlyLoggedSafePortion(for: agreeing) == 150)
        #expect(FavoriteFoodLogging.mostRecentlyLoggedSafePortion(for: disagreeing) == nil)
        #expect(FavoriteFoodLogging.mostRecentlyLoggedSafePortion(for: makeTestFoodItem()) == nil)
    }
}

// MARK: - Daily log commands

@MainActor
@Suite("Daily food log commands coverage")
struct DailyFoodLogCommandsCoverageTests {
    private func makeFavorite(_ name: String = "Favorite") -> FoodItem {
        let food = makeTestFoodItem(name: name, caloriesPer100g: 120, isCustom: true)
        food.setFavorite(true, at: fixedDate(2026, 7, 1))
        return food
    }

    @Test("A missing entry error explains that the entry is gone")
    func missingEntryDescription() {
        #expect(DailyFoodLogCommands.CommandError.missingEntry.errorDescription == "This log entry is no longer available.")
    }

    @Test("Saving an edit to an entry that was never stored fails and stores nothing")
    func savingUnstoredSnapshotEntryFails() throws {
        let container = try makeLoggingContainer()
        let context = ModelContext(container)
        let source = makeTestEntry(foodItem: makeTestFoodItem(name: "Soup"), portionGrams: 250)
        let unstored = FoodLogEntry(
            date: fixedDate(2026, 7, 22),
            mealType: .lunch,
            foodItem: nil,
            snapshot: FoodLogEntrySnapshot(entry: source),
            snackIndex: 0
        )

        #expect(throws: DailyFoodLogCommands.CommandError.missingEntry) {
            try DailyFoodLogCommands.saveSnapshotEntry(
                unstored,
                date: fixedDate(2026, 7, 23),
                mealType: .dinner,
                portionGrams: 100,
                modelContext: context
            )
        }
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<FoodLogEntry>()) == 0)
    }

    @Test("Only an entry whose food is gone, at safe old and new portions, is edited from its snapshot")
    func snapshotEditGuards() throws {
        let food = makeTestFoodItem(name: "Live soup")
        let linked = makeTestEntry(foodItem: food, portionGrams: 250)
        #expect(throws: MealTemplateCommands.CommandError.invalidSnapshot("Live soup")) {
            try DailyFoodLogCommands.updateSnapshotEntry(linked, date: fixedDate(2026, 7, 22), mealType: .lunch, portionGrams: 100)
        }

        let orphan = FoodLogEntry(
            date: fixedDate(2026, 7, 22),
            mealType: .lunch,
            foodItem: nil,
            snapshot: FoodLogEntrySnapshot(entry: linked),
            snackIndex: 0
        )
        #expect(throws: MealTemplateCommands.CommandError.invalidSnapshot("Live soup")) {
            try DailyFoodLogCommands.updateSnapshotEntry(orphan, date: fixedDate(2026, 7, 22), mealType: .lunch, portionGrams: 0)
        }
        #expect(orphan.portionGrams == 250, "a rejected edit leaves the entry untouched")

        orphan.portionGrams = .infinity
        #expect(throws: MealTemplateCommands.CommandError.invalidSnapshot("Live soup")) {
            try DailyFoodLogCommands.updateSnapshotEntry(orphan, date: fixedDate(2026, 7, 22), mealType: .lunch, portionGrams: 100)
        }
    }

    @Test("Editing a snapshot entry rescales its recorded nutrition and normalises its slot")
    func snapshotEditRescales() throws {
        let food = makeTestFoodItem(name: "Soup", caloriesPer100g: 80, proteinPer100g: 4)
        let source = makeTestEntry(foodItem: food, portionGrams: 250)
        let orphan = FoodLogEntry(
            date: fixedDate(2026, 7, 22),
            mealType: .lunch,
            foodItem: nil,
            snapshot: FoodLogEntrySnapshot(entry: source),
            snackIndex: 0
        )

        try DailyFoodLogCommands.updateSnapshotEntry(orphan, date: fixedDate(2026, 7, 22), mealType: .snack, portionGrams: 125, snackIndex: 0)

        #expect(orphan.portionGrams == 125)
        #expect(orphan.mealType == .snack)
        #expect(orphan.snackIndex == 1)
        // 80 kcal/100 g × 125 g, and 4 g × 1.25.
        #expect(abs(orphan.calories - 100) < 1e-9)
        #expect(abs(orphan.proteinG - 5) < 1e-9)
    }

    @Test("Copying a favorite's entries copies them with their recorded portions")
    func copyingFavoriteEntries() throws {
        let context = ModelContext(try makeLoggingContainer())
        let favorite = makeFavorite()
        context.insert(favorite)
        let entry = makeTestEntry(mealType: .dinner, foodItem: favorite, portionGrams: 150)
        context.insert(entry)

        let copies = DailyFoodLogCommands.copyLoggedEntries([entry], to: fixedDate(2026, 7, 23), modelContext: context)

        #expect(copies.count == 1)
        #expect(copies.first?.foodItem?.id == favorite.id)
        #expect(copies.first?.portionGrams == 150)
        #expect(copies.first?.mealType == .dinner)
        #expect(abs((copies.first?.calories ?? 0) - 180) < 1e-9)
        #expect(try context.fetchCount(FetchDescriptor<FoodLogEntry>()) == 2)
    }

    @Test("Updating an entry to a favorite food reprices it and stamps the food as used")
    func updatingToFavorite() throws {
        let context = ModelContext(try makeLoggingContainer())
        let original = makeTestFoodItem(name: "Original", caloriesPer100g: 50)
        let favorite = makeFavorite()
        context.insert(original)
        context.insert(favorite)
        let entry = makeTestEntry(mealType: .lunch, foodItem: original, portionGrams: 100)
        context.insert(entry)

        DailyFoodLogCommands.updateLoggedEntry(
            entry,
            date: fixedDate(2026, 7, 22),
            mealType: .lunch,
            foodItem: favorite,
            portionGrams: 50,
            now: fixedDate(2026, 7, 22, 13)
        )

        #expect(entry.foodItem?.id == favorite.id)
        #expect(entry.foodName == "Favorite")
        #expect(abs(entry.calories - 60) < 1e-9)
        #expect(favorite.lastUsed == fixedDate(2026, 7, 22, 13))
    }

    @Test("Deleting a favorite's entry removes the entry and keeps the favorite")
    func deletingFavoriteEntry() throws {
        let context = ModelContext(try makeLoggingContainer())
        let favorite = makeFavorite()
        context.insert(favorite)
        let entry = makeTestEntry(foodItem: favorite, portionGrams: 100)
        context.insert(entry)
        try context.save()

        DailyFoodLogCommands.deleteLoggedEntry(entry, modelContext: context)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<FoodLogEntry>()) == 0)
        let foods = try context.fetch(FetchDescriptor<FoodItem>())
        #expect(foods.map(\.isFavorite) == [true])
    }
}

// MARK: - Multi-add

@MainActor
@Suite("Multi-add commands coverage")
struct MultiAddCommandsCoverageTests {
    private func makeProduct(name: String) throws -> OpenFoodFactsProduct {
        let json = """
        {
          "code": "lane-4-remote",
          "product_name": "\(name)",
          "nutriments": {
            "energy-kcal_100g": 80,
            "proteins_100g": 9,
            "carbohydrates_100g": 7,
            "fat_100g": 2
          }
        }
        """
        return try JSONDecoder().decode(OpenFoodFactsProduct.self, from: Data(json.utf8))
    }

    @Test("Multi-add errors explain themselves to the user")
    func errorDescriptions() {
        #expect(MultiAddCommands.CommandError.inconsistentRemoteSource.errorDescription
            == "A selected search result changed. Remove it and select it again.")
        #expect(MultiAddCommands.CommandError.unavailableRemoteFood("Yogurt").errorDescription
            == "Yogurt has values that can’t be logged.")
    }

    @Test("A remote selection whose snapshot points at a different food cannot be planned")
    func inconsistentRemoteSourceIsRejected() throws {
        let food = makeTestFoodItem(name: "Yogurt")
        let result = makeTestSearchResult(product: try makeProduct(name: "Yogurt"))
        let item = MultiAddDraftItem(
            source: .remote(foodID: UUID(), result: result),
            snapshot: FoodLogEntrySnapshot(foodItem: food, portionGrams: 150)
        )

        #expect(throws: MultiAddCommands.CommandError.inconsistentRemoteSource) {
            try MultiAddCommands.plan(
                items: [item],
                destinationDate: fixedDate(2026, 7, 22),
                destinationMeal: .lunch,
                calendar: fixedCalendar()
            )
        }
    }

    @Test("A remote product that would be saved without a name is refused, and nothing is stored")
    func unavailableRemoteFoodIsRefused() throws {
        let container = try makeLoggingContainer()
        let food = makeTestFoodItem(name: "Yogurt")
        let result = makeTestSearchResult(product: try makeProduct(name: "   "))
        let item = MultiAddDraftItem(
            source: .remote(foodID: food.id, result: result),
            snapshot: FoodLogEntrySnapshot(foodItem: food, portionGrams: 150)
        )
        let plan = try MultiAddCommands.plan(
            items: [item],
            destinationDate: fixedDate(2026, 7, 22),
            destinationMeal: .lunch,
            calendar: fixedCalendar()
        )

        #expect(throws: MultiAddCommands.CommandError.unavailableRemoteFood("   ")) {
            try MultiAddCommands.commit(plan: plan, modelContainer: container)
        }
        let verify = ModelContext(container)
        #expect(try verify.fetchCount(FetchDescriptor<FoodItem>()) == 0)
        #expect(try verify.fetchCount(FetchDescriptor<FoodLogEntry>()) == 0)
    }

    @Test("A multi-add batch adds each selected portion, so the meal gains their sum")
    func batchTotalsAreTheSumOfItsPortions() throws {
        let container = try makeLoggingContainer()
        let context = ModelContext(container)
        let rice = makeTestFoodItem(name: "Rice", caloriesPer100g: 120, proteinPer100g: 2.5, carbsPer100g: 26, fatPer100g: 0.4)
        let salmon = makeTestFoodItem(name: "Salmon", caloriesPer100g: 208, proteinPer100g: 20, carbsPer100g: 0, fatPer100g: 13)
        context.insert(rice)
        context.insert(salmon)
        try context.save()
        let items = [(rice, 150.0), (salmon, 125.0)].map { food, grams in
            MultiAddDraftItem(source: .local, snapshot: FoodLogEntrySnapshot(foodItem: food, portionGrams: grams))
        }
        let plan = try MultiAddCommands.plan(
            items: items,
            destinationDate: fixedDate(2026, 7, 22, 19),
            destinationMeal: .dinner,
            calendar: fixedCalendar()
        )
        #expect(plan.replicationPlan.sourceName == "2 selected items")

        let outcome = try MultiAddCommands.commit(plan: plan, modelContainer: container, now: fixedDate(2026, 7, 22, 19))

        guard case .completed(let entryIDs, let alreadyCommitted) = outcome else {
            Issue.record("Expected a completed batch, got \(outcome)")
            return
        }
        #expect(!alreadyCommitted)
        #expect(entryIDs.count == 2)
        let logged = try ModelContext(container).fetch(FetchDescriptor<FoodLogEntry>())
        // Rice 150 g: 180 kcal, 3.75 P, 39 C, 0.6 F. Salmon 125 g: 260 kcal, 25 P, 0 C, 16.25 F.
        #expect(abs(logged.reduce(0) { $0 + $1.calories } - 440) < 1e-9)
        #expect(abs(logged.reduce(0) { $0 + $1.proteinG } - 28.75) < 1e-9)
        #expect(abs(logged.reduce(0) { $0 + $1.carbsG } - 39) < 1e-9)
        #expect(abs(logged.reduce(0) { $0 + $1.fatG } - 16.85) < 1e-9)
        #expect(logged.allSatisfy { $0.mealType == .dinner })
    }

    @Test("A single selection is named in the singular")
    func singleSelectionName() throws {
        let food = makeTestFoodItem(name: "Apple")
        let plan = try MultiAddCommands.plan(
            items: [MultiAddDraftItem(source: .local, snapshot: FoodLogEntrySnapshot(foodItem: food, portionGrams: 150))],
            destinationDate: fixedDate(2026, 7, 22),
            destinationMeal: .snack,
            calendar: fixedCalendar()
        )
        #expect(plan.replicationPlan.sourceName == "1 selected item")
        #expect(plan.replicationPlan.destinationSnackIndex == 1)
        #expect(plan.id == plan.replicationPlan.id)
    }
}

// MARK: - Contextual suggestions

@MainActor
@Suite("Contextual suggestion ranking coverage")
struct ContextualSuggestionRankingCoverageTests {
    private let calendar = fixedCalendar()

    private func observation(_ foodID: UUID, logDate: Date, createdAt: Date? = nil, meal: MealType = .lunch) -> ContextualSuggestionObservation {
        ContextualSuggestionObservation(
            entryID: UUID(),
            foodID: foodID,
            logDate: logDate,
            createdAt: createdAt ?? logDate,
            meal: meal
        )
    }

    private func rank(_ foodIDs: [UUID], _ observations: [ContextualSuggestionObservation], now: Date, meal: MealType = .lunch) -> [ContextualFoodSuggestion] {
        ContextualFoodSuggestionRanker.rank(
            candidates: foodIDs.map { ContextualSuggestionCandidate(foodID: $0, isAvailable: true, resolvedPortionGrams: 100) },
            observations: observations,
            destinationDate: now,
            destinationMeal: meal,
            now: now,
            calendar: calendar
        )
    }

    @Test(
        "Each suggestion reason reads as a sentence",
        arguments: [
            (ContextualFoodSuggestion.Reason.sameMeal, "Often logged for this meal"),
            (.usualTime, "Often logged around this time"),
            (.sameWeekday, "Often logged on this weekday"),
            (.recentlyUsed, "Logged recently"),
            (.frequentlyUsed, "Logged on several days"),
        ]
    )
    func reasonDisplayNames(reason: ContextualFoodSuggestion.Reason, text: String) {
        #expect(reason.displayName == text)
    }

    @Test(
        "Time of day counts only when the history falls in the same part of the day as now",
        arguments: [
            (4, 9, 15.0), (3, 4, 0), (3, 23, 15), (9, 10, 0), (10, 14, 15),
            (14, 15, 0), (15, 20, 15), (20, 21, 0), (21, 2, 15), (12, 12, 15),
        ]
    )
    func timeOfDayBuckets(nowHour: Int, historyHour: Int, expectedTimeScore: Double) throws {
        let food = UUID()
        let now = fixedDate(2026, 7, 22, nowHour)
        let observations = (0..<3).map { daysAgo in
            let day = calendar.date(byAdding: .day, value: -daysAgo, to: fixedDate(2026, 7, 22, 0))!
            return observation(food, logDate: day, createdAt: calendar.date(byAdding: .hour, value: historyHour, to: day)!)
        }

        let suggestion = try #require(rank([food], observations, now: now).first)

        #expect(suggestion.score.time == expectedTimeScore)
        #expect(suggestion.reasons.contains(.usualTime) == (expectedTimeScore > 0))
    }

    @Test(
        "Recency fades in steps with the days since the food was last logged",
        arguments: [
            (0, 25.0), (1, 24), (2, 21), (3, 21), (4, 17), (7, 17), (8, 12),
            (14, 12), (15, 7), (30, 7), (31, 3), (60, 3), (61, 1), (87, 1),
        ]
    )
    func recencySteps(daysAgo: Int, expectedRecency: Double) throws {
        let food = UUID()
        let today = fixedDate(2026, 10, 18, 0)
        let now = fixedDate(2026, 10, 18, 12)
        let observations = (0..<3).map { offset in
            let day = calendar.date(byAdding: .day, value: -(daysAgo + offset), to: today)!
            return observation(food, logDate: day, createdAt: calendar.date(byAdding: .hour, value: 12, to: day)!)
        }

        let suggestion = try #require(rank([food], observations, now: now).first)

        #expect(suggestion.score.recency == expectedRecency)
        #expect(suggestion.reasons.contains(.recentlyUsed) == (expectedRecency >= 12))
        #expect(suggestion.id == food)
    }

    @Test("A food logged only once is not suggested even when the history is rich")
    func singleOccurrenceIsNotSuggested() {
        let regular = UUID()
        let once = UUID()
        let now = fixedDate(2026, 7, 22, 12)
        let observations = (0..<3).map { observation(regular, logDate: fixedDate(2026, 7, 20 + $0, 12)) }
            + [observation(once, logDate: fixedDate(2026, 7, 22, 12))]

        #expect(rank([regular, once], observations, now: now).map(\.foodID) == [regular])
    }

    @Test("A higher-scoring suggestion ranks first")
    func higherScoreRanksFirst() throws {
        let alwaysLunch = UUID()
        let sometimesLunch = UUID()
        let now = fixedDate(2026, 7, 22, 12)
        let observations = (0..<3).map { observation(alwaysLunch, logDate: fixedDate(2026, 7, 20 + $0, 12)) }
            + [
                observation(sometimesLunch, logDate: fixedDate(2026, 7, 20, 12)),
                observation(sometimesLunch, logDate: fixedDate(2026, 7, 21, 12)),
                observation(sometimesLunch, logDate: fixedDate(2026, 7, 22, 12), meal: .dinner),
            ]

        let result = rank([sometimesLunch, alwaysLunch], observations, now: now)

        #expect(result.map(\.foodID) == [alwaysLunch, sometimesLunch])
        let first = try #require(result.first)
        let second = try #require(result.last)
        // Meal share 3/3 of 40 against 2/3 of 40; everything else equal.
        #expect(abs(first.score.meal - 40) < 1e-9)
        #expect(abs(second.score.meal - 80.0 / 3) < 1e-9)
        #expect(first.score.total > second.score.total)
    }

    @Test("Equal scores rank the food logged later in the day first")
    func equalScoresRankByLastLogTime() {
        let earlier = UUID()
        let later = UUID()
        let now = fixedDate(2026, 7, 22, 12)
        // Both in the midday bucket on the same three days; only the clock time differs.
        let observations = (0..<3).flatMap { offset in
            [
                observation(earlier, logDate: fixedDate(2026, 7, 20 + offset, 11)),
                observation(later, logDate: fixedDate(2026, 7, 20 + offset, 13)),
            ]
        }

        let result = rank([earlier, later], observations, now: now)

        #expect(result.map(\.foodID) == [later, earlier])
        #expect(result.first?.score == result.last?.score)
    }
}
