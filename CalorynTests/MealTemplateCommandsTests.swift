import SwiftData
import XCTest
@testable import Caloryn

@MainActor
final class MealTemplateCommandsTests: XCTestCase {
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
            name: "Delayed second tap",
            entries: [entry],
            defaultMeal: .lunch,
            modelContext: context,
            operationID: operationID
        )

        XCTAssertEqual(first.id, repeated.id)
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

        XCTAssertTrue(logged.first?.foodItem === food)
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
            replicationItemIndex: 0
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
}
