import SwiftData
import XCTest
@testable import Caloryn

@MainActor
final class MealTemplateCommandsTests: XCTestCase {
    func testSaveMealCreatesFromFoodRecipeAndManualEntrySnapshots() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let catalogFood = makeTestFoodItem(name: "Banana", caloriesPer100g: 90)
        let recipe = makeTestFoodItem(
            name: "Protein shake",
            caloriesPer100g: 120,
            isRecipe: true
        )
        let manualEntry = makeTestFoodItem(
            name: "Coffee",
            caloriesPer100g: 15,
            isCustom: true
        )
        [catalogFood, recipe, manualEntry].forEach(context.insert)
        try context.save()

        let snapshots = [
            FoodLogEntrySnapshot(foodItem: catalogFood, portionGrams: 110),
            FoodLogEntrySnapshot(foodItem: recipe, portionGrams: 300),
            FoodLogEntrySnapshot(foodItem: manualEntry, portionGrams: 250),
        ]
        let meal = try MealTemplateCommands.saveMeal(
            name: "  Weekday breakfast  ",
            snapshots: snapshots,
            modelContext: context
        )

        let reloadedContext = ModelContext(container)
        let reloaded = try XCTUnwrap(
            reloadedContext.fetch(FetchDescriptor<MealTemplate>())
                .first { $0.id == meal.id }
        )
        let savedSnapshots = try MealTemplateCommands.snapshots(for: reloaded)

        XCTAssertEqual(reloaded.name, "Weekday breakfast")
        XCTAssertEqual(savedSnapshots.map(\.foodName), ["Banana", "Protein shake", "Coffee"])
        XCTAssertEqual(savedSnapshots.map(\.portionGrams), [110, 300, 250])
        XCTAssertEqual(
            savedSnapshots.map(\.sourceFoodID),
            [catalogFood.id, recipe.id, manualEntry.id]
        )
    }

    func testSaveMealEditReplacesComponentsWithoutLeavingOldItems() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let firstFood = makeTestFoodItem(name: "First", caloriesPer100g: 100)
        let secondFood = makeTestFoodItem(name: "Second", caloriesPer100g: 200)
        [firstFood, secondFood].forEach(context.insert)
        try context.save()

        let created = try MealTemplateCommands.saveMeal(
            name: "Original",
            snapshots: [
                FoodLogEntrySnapshot(foodItem: firstFood, portionGrams: 50),
                FoodLogEntrySnapshot(foodItem: secondFood, portionGrams: 75),
            ],
            modelContext: context
        )
        _ = try MealTemplateCommands.saveMeal(
            name: "Updated",
            snapshots: [
                FoodLogEntrySnapshot(foodItem: secondFood, portionGrams: 125),
            ],
            existingMealID: created.id,
            modelContext: context
        )

        let reloadedContext = ModelContext(container)
        let reloaded = try XCTUnwrap(
            reloadedContext.fetch(FetchDescriptor<MealTemplate>())
                .first { $0.id == created.id }
        )
        let snapshots = try MealTemplateCommands.snapshots(for: reloaded)

        XCTAssertEqual(reloaded.name, "Updated")
        XCTAssertEqual(snapshots.map(\.foodName), ["Second"])
        XCTAssertEqual(snapshots.map(\.portionGrams), [125])
        XCTAssertEqual(try reloadedContext.fetchCount(FetchDescriptor<MealTemplateItem>()), 1)
    }

    func testSavedMealLogsComponentsAsOrdinaryEntriesAtExplicitDestination() throws {
        let context = ModelContext(try makeContainer())
        let recipe = makeTestFoodItem(
            name: "Overnight oats",
            caloriesPer100g: 150,
            isRecipe: true
        )
        let fruit = makeTestFoodItem(name: "Blueberries", caloriesPer100g: 60)
        [recipe, fruit].forEach(context.insert)
        try context.save()
        let meal = try MealTemplateCommands.saveMeal(
            name: "Breakfast",
            snapshots: [
                FoodLogEntrySnapshot(foodItem: recipe, portionGrams: 200),
                FoodLogEntrySnapshot(foodItem: fruit, portionGrams: 100),
            ],
            modelContext: context
        )
        let destination = makeTestDate(year: 2026, month: 7, day: 25)
        let plan = try MealTemplateCommands.plan(
            sourceName: meal.name,
            snapshots: MealTemplateCommands.snapshots(for: meal),
            destinationDate: destination,
            destinationMeal: .snack,
            destinationSnackIndex: 4
        )

        let entries = try MealTemplateCommands.log(
            plan: plan,
            availableFoods: [recipe, fruit],
            modelContext: context
        )

        XCTAssertEqual(entries.map(\.foodName), ["Overnight oats", "Blueberries"])
        XCTAssertEqual(entries.map(\.portionGrams), [200, 100])
        XCTAssertEqual(entries.map(\.mealType), [.snack, .snack])
        XCTAssertEqual(entries.map(\.snackIndex), [4, 4])
        XCTAssertEqual(entries.map(\.calories), [300, 60])
    }

    func testFailedMealCreationPreservesUnrelatedPendingEditAndPersistsNothing() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let pendingFood = makeTestFoodItem(name: "Original")
        context.insert(pendingFood)
        try context.save()
        pendingFood.name = "Pending edit"
        let snapshot = FoodLogEntrySnapshot(foodItem: pendingFood, portionGrams: 100)

        XCTAssertThrowsError(
            try MealTemplateCommands.saveMeal(
                name: "Failed meal",
                snapshots: [snapshot],
                modelContext: context,
                save: { _ in throw InjectedFailure.save }
            )
        )

        XCTAssertEqual(pendingFood.name, "Pending edit")
        let reloadedContext = ModelContext(container)
        XCTAssertEqual(
            try XCTUnwrap(reloadedContext.fetch(FetchDescriptor<FoodItem>()).first).name,
            "Original"
        )
        XCTAssertEqual(try reloadedContext.fetchCount(FetchDescriptor<MealTemplate>()), 0)
        XCTAssertEqual(try reloadedContext.fetchCount(FetchDescriptor<MealTemplateItem>()), 0)
    }

    func testFailedMealEditKeepsStoredMealAndPendingMainContextEdit() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let food = makeTestFoodItem(name: "Food")
        context.insert(food)
        try context.save()
        let meal = try MealTemplateCommands.saveMeal(
            name: "Stored meal",
            snapshots: [FoodLogEntrySnapshot(foodItem: food, portionGrams: 100)],
            modelContext: context
        )
        food.name = "Pending food edit"

        XCTAssertThrowsError(
            try MealTemplateCommands.saveMeal(
                name: "Uncommitted meal edit",
                snapshots: [FoodLogEntrySnapshot(foodItem: food, portionGrams: 200)],
                existingMealID: meal.id,
                modelContext: context,
                save: { _ in throw InjectedFailure.save }
            )
        )

        XCTAssertEqual(food.name, "Pending food edit")
        let reloadedContext = ModelContext(container)
        let reloadedMeal = try XCTUnwrap(
            reloadedContext.fetch(FetchDescriptor<MealTemplate>())
                .first { $0.id == meal.id }
        )
        XCTAssertEqual(reloadedMeal.name, "Stored meal")
        XCTAssertEqual(
            try MealTemplateCommands.snapshots(for: reloadedMeal).map(\.portionGrams),
            [100]
        )
        XCTAssertEqual(try reloadedContext.fetchCount(FetchDescriptor<MealTemplateItem>()), 1)
    }

    func testCreateTemplatePreservesSelectedEntriesOrderPortionsAndSuggestedMeal() throws {
        let context = ModelContext(try makeContainer())
        let toast = makeTestFoodItem(name: "Toast", caloriesPer100g: 250)
        let eggs = makeTestFoodItem(name: "Eggs", caloriesPer100g: 140)
        let toastEntry = makeTestEntry(mealType: .breakfast, foodItem: toast, portionGrams: 80)
        let eggsEntry = makeTestEntry(mealType: .breakfast, foodItem: eggs, portionGrams: 120)
        [toast, eggs].forEach(context.insert)
        [toastEntry, eggsEntry].forEach(context.insert)

        let template = try MealTemplateCommands.createTemplate(
            name: "  Weekend breakfast  ",
            entries: [eggsEntry, toastEntry],
            defaultMeal: MealTemplateCommands.suggestedMeal(for: [eggsEntry, toastEntry]),
            modelContext: context,
            operationID: UUID(uuidString: "00000000-0000-0000-0000-000000000074")!
        )
        let snapshots = try MealTemplateCommands.snapshots(for: template)

        XCTAssertEqual(template.name, "Weekend breakfast")
        XCTAssertEqual(template.defaultMeal, .breakfast)
        XCTAssertEqual(template.sortedItems.map(\.sortOrder), [0, 1])
        XCTAssertEqual(snapshots.map(\.foodName), ["Eggs", "Toast"])
        XCTAssertEqual(snapshots.map(\.portionGrams), [120, 80])
        XCTAssertEqual(snapshots.map(\.sourceFoodID), [eggs.id, toast.id])
    }

    func testCreateTemplateIsIdempotentForSameOperationID() throws {
        let context = ModelContext(try makeContainer())
        let food = makeTestFoodItem(name: "Skyr")
        let entry = makeTestEntry(foodItem: food)
        context.insert(food)
        context.insert(entry)
        let operationID = UUID()

        let first = try MealTemplateCommands.createTemplate(
            name: "First name",
            entries: [entry],
            defaultMeal: .breakfast,
            modelContext: context,
            operationID: operationID
        )
        let repeated = try MealTemplateCommands.createTemplate(
            name: "First name",
            entries: [entry],
            defaultMeal: .breakfast,
            modelContext: context,
            operationID: operationID
        )

        XCTAssertEqual(first.id, repeated.id)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MealTemplate>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MealTemplateItem>()), 1)
    }

    func testCreateTemplateRejectsSameOperationIDForDifferentPlan() throws {
        let context = ModelContext(try makeContainer())
        let food = makeTestFoodItem(name: "Skyr")
        let entry = makeTestEntry(foodItem: food)
        context.insert(food)
        context.insert(entry)
        try context.save()
        let operationID = UUID()

        _ = try MealTemplateCommands.createTemplate(
            name: "Breakfast",
            entries: [entry],
            defaultMeal: .breakfast,
            modelContext: context,
            operationID: operationID
        )

        XCTAssertThrowsError(
            try MealTemplateCommands.createTemplate(
                name: "Different breakfast",
                entries: [entry],
                defaultMeal: .breakfast,
                modelContext: context,
                operationID: operationID
            )
        ) { error in
            XCTAssertEqual(error as? MealTemplateCommands.CommandError, .operationConflict)
        }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MealTemplate>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MealTemplateItem>()), 1)
    }

    func testTemplateAndEncodedSnapshotPersistAcrossModelContexts() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let food = makeTestFoodItem(name: "Persistent snack", caloriesPer100g: 220)
        let entry = makeTestEntry(
            mealType: .snack,
            foodItem: food,
            portionGrams: 40,
            snackIndex: 2
        )
        context.insert(food)
        context.insert(entry)
        let created = try MealTemplateCommands.createTemplate(
            name: "Persistent meal",
            entries: [entry],
            defaultMeal: .snack,
            defaultSnackIndex: 2,
            modelContext: context
        )

        let reloadedContext = ModelContext(container)
        let reloaded = try XCTUnwrap(
            reloadedContext.fetch(FetchDescriptor<MealTemplate>()).first { $0.id == created.id }
        )
        let snapshot = try XCTUnwrap(MealTemplateCommands.snapshots(for: reloaded).first)

        XCTAssertEqual(reloaded.name, "Persistent meal")
        XCTAssertEqual(reloaded.defaultMeal, .snack)
        XCTAssertEqual(reloaded.defaultSnackIndex, 2)
        XCTAssertEqual(snapshot.foodName, "Persistent snack")
        XCTAssertEqual(snapshot.portionGrams, 40)
        XCTAssertEqual(snapshot.nutrition.calories, 88)
    }

    func testTemplateSnapshotSurvivesSourceEditsAndDeletion() throws {
        let context = ModelContext(try makeContainer())
        let food = makeTestFoodItem(
            name: "Original yogurt",
            caloriesPer100g: 120,
            proteinPer100g: 9,
            nutriscoreGrade: "a",
            produceKind: .fruit
        )
        let entry = makeTestEntry(mealType: .lunch, foodItem: food, portionGrams: 200)
        context.insert(food)
        context.insert(entry)
        let template = try MealTemplateCommands.createTemplate(
            name: "Lunch",
            entries: [entry],
            defaultMeal: .lunch,
            modelContext: context
        )

        food.name = "Edited yogurt"
        food.nutritionPer100g = .zero
        food.deletePreservingLogEntrySnapshots(from: context)
        try context.save()

        let snapshots = try MealTemplateCommands.snapshots(for: template)
        XCTAssertEqual(snapshots.first?.foodName, "Original yogurt")
        XCTAssertEqual(snapshots.first?.portionGrams, 200)
        XCTAssertEqual(snapshots.first?.nutrition.calories, 240)
        XCTAssertEqual(snapshots.first?.nutriscoreGradeSnapshot, "a")
        XCTAssertEqual(MealTemplateCommands.missingSourceCount(in: snapshots, availableFoods: []), 1)
    }

    func testPlanAndLogUseExplicitDestinationForPartialSelection() throws {
        let context = ModelContext(try makeContainer())
        let firstFood = makeTestFoodItem(name: "First", caloriesPer100g: 100)
        let skippedFood = makeTestFoodItem(name: "Skipped")
        let lastFood = makeTestFoodItem(name: "Last", caloriesPer100g: 300)
        let first = makeTestEntry(mealType: .breakfast, foodItem: firstFood, portionGrams: 50)
        _ = makeTestEntry(mealType: .lunch, foodItem: skippedFood, portionGrams: 60)
        let last = makeTestEntry(mealType: .dinner, foodItem: lastFood, portionGrams: 70)
        [firstFood, skippedFood, lastFood].forEach(context.insert)
        [first, last].forEach(context.insert)
        let destination = makeTestDate(year: 2026, month: 7, day: 24, hour: 18)
        let operationID = UUID()
        let snapshots = [first, last].map(FoodLogEntrySnapshot.init(entry:))

        let plan = try MealTemplateCommands.plan(
            sourceName: "2 selected items",
            snapshots: snapshots,
            destinationDate: destination,
            destinationMeal: .snack,
            operationID: operationID
        )
        let logged = try MealTemplateCommands.log(
            plan: plan,
            availableFoods: [firstFood, skippedFood, lastFood],
            modelContext: context,
            now: destination
        )

        XCTAssertEqual(plan.destinationDate, destination.startOfDay)
        XCTAssertEqual(logged.map(\.foodName), ["First", "Last"])
        XCTAssertEqual(logged.map(\.mealType), [.snack, .snack])
        XCTAssertEqual(logged.map(\.snackIndex), [1, 1])
        XCTAssertEqual(logged.map(\.portionGrams), [50, 70])
        XCTAssertEqual(logged.map(\.calories), [50, 210])
        XCTAssertEqual(logged.map(\.replicationOperationID), [operationID, operationID])
        XCTAssertEqual(logged.map(\.replicationItemIndex), [0, 1])
    }

    func testProviderProvenanceRoundTripsThroughMealAtExplicitDestination() throws {
        let context = ModelContext(try makeContainer())
        let provenance = FoodProvenance(
            provider: .openFoodFacts,
            source: .openFoodFactsCommunity,
            completeness: .partial,
            recoveredByFallback: true
        )
        let food = makeTestFoodItem(
            name: "Fallback component",
            provenance: provenance
        )
        context.insert(food)
        try context.save()
        let meal = try MealTemplateCommands.saveMeal(
            name: "Provider meal",
            snapshots: [
                FoodLogEntrySnapshot(
                    foodItem: food,
                    portionGrams: 140,
                    mealType: .breakfast
                ),
            ],
            modelContext: context
        )
        let storedSnapshot = try XCTUnwrap(
            MealTemplateCommands.snapshots(for: meal).first
        )
        food.provenance = .userEntered
        try context.save()
        let destination = makeTestDate(year: 2026, month: 7, day: 28, hour: 20)
        let plan = try MealTemplateCommands.plan(
            sourceName: meal.name,
            snapshots: [storedSnapshot],
            destinationDate: destination,
            destinationMeal: .snack,
            destinationSnackIndex: 4
        )

        let logged = try MealTemplateCommands.log(
            plan: plan,
            availableFoods: [food],
            modelContext: context
        )
        let entry = try XCTUnwrap(logged.first)

        XCTAssertEqual(entry.date, destination.startOfDay)
        XCTAssertEqual(entry.mealType, .snack)
        XCTAssertEqual(entry.snackIndex, 4)
        XCTAssertEqual(entry.historicalProvenance, provenance)
        XCTAssertEqual(entry.foodItem?.provenance, .userEntered)
    }

    func testTemplateAndReusePlanPreserveExplicitSnackSlots() throws {
        let context = ModelContext(try makeContainer())
        let food = makeTestFoodItem(name: "Afternoon fruit")
        let source = makeTestEntry(
            mealType: .snack,
            foodItem: food,
            portionGrams: 90,
            snackIndex: 3
        )
        context.insert(food)
        context.insert(source)

        let template = try MealTemplateCommands.createTemplate(
            name: "Late snack",
            entries: [source],
            defaultMeal: .snack,
            defaultSnackIndex: 3,
            modelContext: context
        )
        let plan = try MealTemplateCommands.plan(
            sourceName: template.name,
            snapshots: MealTemplateCommands.snapshots(for: template),
            destinationDate: makeTestDate(year: 2026, month: 7, day: 25),
            destinationMeal: .snack,
            destinationSnackIndex: 4
        )
        let logged = try MealTemplateCommands.log(
            plan: plan,
            availableFoods: [food],
            modelContext: context
        )

        XCTAssertEqual(template.defaultSnackIndex, 3)
        XCTAssertEqual(plan.destinationSnackIndex, 4)
        XCTAssertEqual(logged.first?.mealType, .snack)
        XCTAssertEqual(logged.first?.snackIndex, 4)
    }

    func testLoggingTemplateUsesSnapshotWhenLiveSourceWasEdited() throws {
        let context = ModelContext(try makeContainer())
        let food = makeTestFoodItem(name: "Recorded food", caloriesPer100g: 150, proteinPer100g: 10)
        let entry = makeTestEntry(foodItem: food, portionGrams: 200)
        context.insert(food)
        context.insert(entry)
        try context.save()
        let snapshot = FoodLogEntrySnapshot(entry: entry)
        food.name = "Current food"
        food.nutritionPer100g = .zero
        let plan = try MealTemplateCommands.plan(
            sourceName: "Saved meal",
            snapshots: [snapshot],
            destinationDate: makeTestDate(year: 2026, month: 7, day: 25),
            destinationMeal: .dinner
        )

        let logged = try MealTemplateCommands.log(
            plan: plan,
            availableFoods: [food],
            modelContext: context
        )

        XCTAssertEqual(logged.first?.foodItem?.id, food.id)
        XCTAssertEqual(logged.first?.foodName, "Recorded food")
        XCTAssertEqual(logged.first?.calories, 300)
        XCTAssertEqual(logged.first?.proteinG, 20)
    }

    func testLoggingTemplateRecoversWhenSourceWasDeleted() throws {
        let context = ModelContext(try makeContainer())
        let food = makeTestFoodItem(name: "Deleted source", caloriesPer100g: 175)
        let source = makeTestEntry(foodItem: food, portionGrams: 120)
        let snapshot = FoodLogEntrySnapshot(entry: source)
        let plan = try MealTemplateCommands.plan(
            sourceName: "Offline meal",
            snapshots: [snapshot],
            destinationDate: makeTestDate(year: 2026, month: 7, day: 25),
            destinationMeal: .lunch
        )

        let logged = try MealTemplateCommands.log(
            plan: plan,
            availableFoods: [],
            modelContext: context
        )

        XCTAssertNil(logged.first?.foodItem)
        XCTAssertEqual(logged.first?.foodName, "Deleted source")
        XCTAssertEqual(logged.first?.calories, 210)
    }

    func testLogIsIdempotentForRepeatedCommit() throws {
        let context = ModelContext(try makeContainer())
        let food = makeTestFoodItem(name: "Rice")
        let entry = makeTestEntry(foodItem: food)
        context.insert(food)
        context.insert(entry)
        let plan = try MealTemplateCommands.plan(
            sourceName: "Dinner",
            snapshots: [FoodLogEntrySnapshot(entry: entry)],
            destinationDate: makeTestDate(year: 2026, month: 7, day: 25),
            destinationMeal: .dinner,
            operationID: UUID()
        )

        let first = try MealTemplateCommands.log(
            plan: plan,
            availableFoods: [food],
            modelContext: context
        )
        let repeated = try MealTemplateCommands.log(
            plan: plan,
            availableFoods: [food],
            modelContext: context
        )

        XCTAssertEqual(first.map(\.id), repeated.map(\.id))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FoodLogEntry>()), 2)
    }

    func testLogRejectsEveryCompletePlanMismatchWithoutWrites() throws {
        let context = ModelContext(try makeContainer())
        let firstFood = makeTestFoodItem(name: "Rice")
        let secondFood = makeTestFoodItem(name: "Beans")
        let firstEntry = makeTestEntry(foodItem: firstFood, portionGrams: 100)
        let secondEntry = makeTestEntry(foodItem: secondFood, portionGrams: 80)
        [firstFood, secondFood].forEach(context.insert)
        [firstEntry, secondEntry].forEach(context.insert)
        try context.save()
        let operationID = UUID()
        let date = makeTestDate(year: 2026, month: 7, day: 25)
        let originalSnapshots = [firstEntry, secondEntry].map(FoodLogEntrySnapshot.init(entry:))
        let originalPlan = try MealTemplateCommands.plan(
            sourceName: "Snack",
            snapshots: originalSnapshots,
            destinationDate: date,
            destinationMeal: .snack,
            destinationSnackIndex: 3,
            operationID: operationID
        )
        let original = try MealTemplateCommands.log(
            plan: originalPlan,
            availableFoods: [firstFood, secondFood],
            modelContext: context
        )

        var differentSource = originalSnapshots
        differentSource[0].sourceFoodID = UUID()
        var differentPayload = originalSnapshots
        differentPayload[0].portionGrams += 1
        let mismatches: [(String, [FoodLogEntrySnapshot], Date, MealType, Int)] = [
            ("source food", differentSource, date, .snack, 3),
            ("snapshot payload", differentPayload, date, .snack, 3),
            ("date", originalSnapshots, date.addingTimeInterval(86_400), .snack, 3),
            ("meal", originalSnapshots, date, .dinner, 0),
            ("snack slot", originalSnapshots, date, .snack, 4),
            ("order", Array(originalSnapshots.reversed()), date, .snack, 3),
            ("count", [originalSnapshots[0]], date, .snack, 3),
        ]

        for (name, snapshots, destinationDate, meal, snackIndex) in mismatches {
            let mismatchedPlan = try MealTemplateCommands.plan(
                sourceName: "Snack",
                snapshots: snapshots,
                destinationDate: destinationDate,
                destinationMeal: meal,
                destinationSnackIndex: snackIndex,
                operationID: operationID
            )
            XCTAssertThrowsError(
                try MealTemplateCommands.log(
                    plan: mismatchedPlan,
                    availableFoods: [firstFood, secondFood],
                    modelContext: context
                ),
                name
            ) { error in
                XCTAssertEqual(error as? MealTemplateCommands.CommandError, .operationConflict, name)
            }
        }

        let stored = try ModelContext(context.container).fetch(
            FetchDescriptor<FoodLogEntry>(
                predicate: #Predicate { entry in
                    entry.replicationOperationID == operationID
                }
            )
        )
        XCTAssertEqual(Set(stored.map(\.id)), Set(original.map(\.id)))
        XCTAssertEqual(stored.count, 2)
    }

    func testExactLogRetryAfterReconstructedContextReturnsOriginalIDs() throws {
        let container = try makeContainer()
        let firstContext = ModelContext(container)
        let food = makeTestFoodItem(name: "Rice")
        let source = makeTestEntry(foodItem: food)
        firstContext.insert(food)
        firstContext.insert(source)
        try firstContext.save()
        let operationID = UUID()
        let snapshots = [FoodLogEntrySnapshot(entry: source)]
        let destination = makeTestDate(year: 2026, month: 7, day: 25, hour: 18)
        let firstPlan = try MealTemplateCommands.plan(
            sourceName: "Dinner",
            snapshots: snapshots,
            destinationDate: destination,
            destinationMeal: .snack,
            destinationSnackIndex: 4,
            operationID: operationID
        )
        let original = try MealTemplateCommands.log(
            plan: firstPlan,
            availableFoods: [food],
            modelContext: firstContext
        )

        let relaunchedContext = ModelContext(container)
        let relaunchedFoods = try relaunchedContext.fetch(FetchDescriptor<FoodItem>())
        let reconstructedPlan = try MealTemplateCommands.plan(
            sourceName: "Dinner",
            snapshots: snapshots,
            destinationDate: destination,
            destinationMeal: .snack,
            destinationSnackIndex: 4,
            operationID: operationID
        )
        let repeated = try MealTemplateCommands.log(
            plan: reconstructedPlan,
            availableFoods: relaunchedFoods,
            modelContext: relaunchedContext
        )

        XCTAssertEqual(reconstructedPlan.fingerprint, firstPlan.fingerprint)
        XCTAssertEqual(repeated.map(\.id), original.map(\.id))
        XCTAssertEqual(repeated.first?.snackIndex, 4)
    }

    func testLogRejectsPartiallyPersistedDuplicateBatch() throws {
        let context = ModelContext(try makeContainer())
        let food = makeTestFoodItem(name: "Rice")
        let first = makeTestEntry(foodItem: food)
        let second = makeTestEntry(foodItem: food, portionGrams: 200)
        let snapshots = [first, second].map(FoodLogEntrySnapshot.init(entry:))
        let operationID = UUID()
        let plan = try MealTemplateCommands.plan(
            sourceName: "Dinner",
            snapshots: snapshots,
            destinationDate: makeTestDate(year: 2026, month: 7, day: 25),
            destinationMeal: .dinner,
            operationID: operationID
        )
        let partial = FoodLogEntry(
            date: plan.destinationDate,
            mealType: plan.destinationMeal,
            foodItem: nil,
            snapshot: snapshots[0],
            snackIndex: 0,
            replicationOperationID: operationID,
            replicationItemIndex: 0,
            replicationPlanFingerprint: plan.fingerprint
        )
        context.insert(partial)
        try context.save()

        XCTAssertThrowsError(
            try MealTemplateCommands.log(
                plan: plan,
                availableFoods: [],
                modelContext: context
            )
        ) { error in
            XCTAssertEqual(error as? MealTemplateCommands.CommandError, .partialDuplicate)
        }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FoodLogEntry>()), 1)
    }

    func testFailedCreateTransactionPreservesUnrelatedPendingEditsAndPersistsNothing() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let food = makeTestFoodItem(name: "Stored food")
        let entry = makeTestEntry(foodItem: food)
        context.insert(food)
        context.insert(entry)
        try context.save()
        food.name = "Pending food edit"
        entry.foodName = "Pending log edit"

        XCTAssertThrowsError(
            try MealTemplateCommands.createTemplate(
                name: "Will fail",
                entries: [entry],
                defaultMeal: .breakfast,
                modelContext: context,
                save: { _ in throw InjectedFailure.save }
            )
        )

        XCTAssertEqual(food.name, "Pending food edit")
        XCTAssertEqual(entry.foodName, "Pending log edit")
        XCTAssertTrue(context.hasChanges)
        let verificationContext = ModelContext(container)
        XCTAssertEqual(try verificationContext.fetchCount(FetchDescriptor<MealTemplate>()), 0)
        XCTAssertEqual(try verificationContext.fetchCount(FetchDescriptor<MealTemplateItem>()), 0)
    }

    func testFailedLogTransactionPreservesUnrelatedPendingEditsAndPersistsNoBatch() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let food = makeTestFoodItem(name: "Stored food")
        let source = makeTestEntry(foodItem: food)
        context.insert(food)
        context.insert(source)
        try context.save()
        let operationID = UUID()
        let plan = try MealTemplateCommands.plan(
            sourceName: "Will fail",
            snapshots: [FoodLogEntrySnapshot(entry: source)],
            destinationDate: makeTestDate(year: 2026, month: 7, day: 25),
            destinationMeal: .lunch,
            operationID: operationID
        )
        food.name = "Pending food edit"
        source.foodName = "Pending log edit"

        XCTAssertThrowsError(
            try MealTemplateCommands.log(
                plan: plan,
                availableFoods: [food],
                modelContext: context,
                save: { _ in throw InjectedFailure.save }
            )
        )

        XCTAssertEqual(food.name, "Pending food edit")
        XCTAssertEqual(source.foodName, "Pending log edit")
        XCTAssertTrue(context.hasChanges)
        let verificationContext = ModelContext(container)
        let replicatedCount = try verificationContext.fetchCount(
            FetchDescriptor<FoodLogEntry>(
                predicate: #Predicate { entry in
                    entry.replicationOperationID == operationID
                }
            )
        )
        XCTAssertEqual(replicatedCount, 0)
        XCTAssertEqual(try verificationContext.fetchCount(FetchDescriptor<FoodLogEntry>()), 1)
    }

    func testFailedDeleteTransactionPreservesUnrelatedPendingEditsAndTemplate() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let food = makeTestFoodItem(name: "Stored food")
        let source = makeTestEntry(foodItem: food)
        context.insert(food)
        context.insert(source)
        try context.save()
        let template = try MealTemplateCommands.createTemplate(
            name: "Keep on failure",
            entries: [source],
            defaultMeal: .breakfast,
            modelContext: context
        )
        food.name = "Pending food edit"
        source.foodName = "Pending log edit"

        XCTAssertThrowsError(
            try MealTemplateCommands.delete(
                template,
                modelContext: context,
                save: { _ in throw InjectedFailure.save }
            )
        )

        XCTAssertEqual(food.name, "Pending food edit")
        XCTAssertEqual(source.foodName, "Pending log edit")
        XCTAssertTrue(context.hasChanges)
        let verificationContext = ModelContext(container)
        XCTAssertEqual(try verificationContext.fetchCount(FetchDescriptor<MealTemplate>()), 1)
        XCTAssertEqual(try verificationContext.fetchCount(FetchDescriptor<MealTemplateItem>()), 1)
    }

    func testMissingSourceEntryCanBeEditedWithoutLiveFood() throws {
        let context = ModelContext(try makeContainer())
        let sourceFood = makeTestFoodItem(name: "Archived soup", caloriesPer100g: 80, proteinPer100g: 4)
        let source = makeTestEntry(foodItem: sourceFood, portionGrams: 250)
        let entry = FoodLogEntry(
            date: makeTestDate(year: 2026, month: 7, day: 25),
            mealType: .lunch,
            foodItem: nil,
            snapshot: FoodLogEntrySnapshot(entry: source),
            snackIndex: 0
        )
        context.insert(entry)

        try DailyFoodLogCommands.updateSnapshotEntry(
            entry,
            date: makeTestDate(year: 2026, month: 7, day: 26, hour: 20),
            mealType: .snack,
            portionGrams: 125,
            snackIndex: 3
        )
        try context.save()

        XCTAssertNil(entry.foodItem)
        XCTAssertEqual(entry.foodName, "Archived soup")
        XCTAssertEqual(entry.date, makeTestDate(year: 2026, month: 7, day: 26).startOfDay)
        XCTAssertEqual(entry.mealType, .snack)
        XCTAssertEqual(entry.snackIndex, 3)
        XCTAssertEqual(entry.portionGrams, 125)
        XCTAssertEqual(entry.calories, 100)
        XCTAssertEqual(entry.proteinG, 5)
    }

    func testDeleteTemplateCascadesItemsWithoutDeletingFoodsOrLogs() throws {
        let context = ModelContext(try makeContainer())
        let food = makeTestFoodItem(name: "Keep me")
        let entry = makeTestEntry(foodItem: food)
        context.insert(food)
        context.insert(entry)
        let template = try MealTemplateCommands.createTemplate(
            name: "Temporary",
            entries: [entry],
            defaultMeal: .breakfast,
            modelContext: context
        )

        try MealTemplateCommands.delete(template, modelContext: context)

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MealTemplate>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MealTemplateItem>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FoodItem>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FoodLogEntry>()), 1)
    }

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: UserProfile.self,
            FoodItem.self,
            FoodLogEntry.self,
            RecipeIngredient.self,
            MealTemplate.self,
            MealTemplateItem.self,
            configurations: configuration
        )
    }

    private enum InjectedFailure: Error {
        case save
    }
}
