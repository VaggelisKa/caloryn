import SwiftData
import XCTest
@testable import Caloryn

@MainActor
final class MultiAddCommandsTests: XCTestCase {
    func testAuthoredMealExpandsWithFoodRecipeAndManualEntryIntoCallerDestination() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let oats = makeTestFoodItem(name: "Oats")
        let recipe = makeTestFoodItem(
            name: "Berry Compote",
            defaultServingG: 120,
            isRecipe: true
        )
        let manual = makeTestFoodItem(
            name: "Manual Coffee",
            defaultServingG: 250,
            isCustom: true
        )
        [oats, recipe, manual].forEach(context.insert)
        try context.save()

        let meal = try MealTemplateCommands.saveMeal(
            name: "Breakfast Bowl",
            snapshots: [
                FoodLogEntrySnapshot(
                    foodItem: oats,
                    portionGrams: 80,
                    mealType: .breakfast
                ),
                FoodLogEntrySnapshot(
                    foodItem: recipe,
                    portionGrams: 120,
                    mealType: .breakfast
                ),
            ],
            modelContext: context
        )
        let groups: [MultiAddSelectionGroup] = [
            .meal(
                meal,
                snapshots: try MealTemplateCommands.snapshots(for: meal)
            ),
            .savedFood(
                manual,
                portionGrams: 250,
                meal: .snack,
                snackIndex: 4
            ),
        ]
        let destination = makeTestDate(year: 2026, month: 8, day: 3)
        let plan = try MultiAddCommands.plan(
            items: groups.flatMap(\.items),
            destinationDate: destination,
            destinationMeal: .snack,
            destinationSnackIndex: 4
        )

        _ = try MultiAddCommands.commit(plan: plan, modelContainer: container)

        let entries = try replicatedEntries(plan.id, context: ModelContext(container))
        XCTAssertEqual(
            entries.map(\.foodName),
            ["Oats", "Berry Compote", "Manual Coffee"]
        )
        XCTAssertEqual(
            entries.map(\.foodItem?.id),
            [oats.id, recipe.id, manual.id]
        )
        XCTAssertTrue(entries.allSatisfy { $0.date == destination.startOfDay })
        XCTAssertTrue(entries.allSatisfy { $0.mealType == .snack })
        XCTAssertTrue(entries.allSatisfy { $0.snackIndex == 4 })
    }

    func testCommitIsAtomicAndIdempotentThroughMealTemplateReplicationIdentity() throws {
        let container = try makeContainer()
        let setup = ModelContext(container)
        let oats = makeTestFoodItem(name: "Oats", caloriesPer100g: 380)
        let berries = makeTestFoodItem(name: "Berries", caloriesPer100g: 50)
        setup.insert(oats)
        setup.insert(berries)
        try setup.save()
        let operationID = UUID()
        let plan = try makePlan(
            foods: [(oats, 80), (berries, 120)],
            operationID: operationID
        )

        let first = try MultiAddCommands.commit(
            plan: plan,
            modelContainer: container
        )
        let repeated = try MultiAddCommands.commit(
            plan: plan,
            modelContainer: container
        )
        let verify = ModelContext(container)
        let entries = try replicatedEntries(operationID, context: verify)

        guard case .completed(let firstIDs, false) = first else {
            return XCTFail("Expected a new completed batch")
        }
        guard case .completed(let repeatedIDs, true) = repeated else {
            return XCTFail("Expected an idempotent completed batch")
        }
        XCTAssertEqual(firstIDs, repeatedIDs)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries.map(\.replicationItemIndex), [0, 1])
        XCTAssertEqual(entries.map(\.foodName), ["Oats", "Berries"])
        XCTAssertEqual(entries.map(\.portionGrams), [80, 120])
    }

    func testDedicatedContextDoesNotSaveUnrelatedPendingViewEdits() throws {
        let container = try makeContainer()
        let viewContext = ModelContext(container)
        viewContext.autosaveEnabled = false
        let selected = makeTestFoodItem(name: "Selected")
        let unrelated = makeTestFoodItem(name: "Stored name")
        viewContext.insert(selected)
        viewContext.insert(unrelated)
        try viewContext.save()
        let plan = try makePlan(foods: [(selected, 100)])

        unrelated.name = "Unsaved view edit"
        _ = try MultiAddCommands.commit(plan: plan, modelContainer: container)

        let verify = ModelContext(container)
        let persistedUnrelated = try XCTUnwrap(
            verify.fetch(FetchDescriptor<FoodItem>()).first { $0.id == unrelated.id }
        )
        XCTAssertEqual(persistedUnrelated.name, "Stored name")
        XCTAssertEqual(try replicatedEntries(plan.id, context: verify).count, 1)
    }

    func testPartialBatchRequiresExplicitRecoveryAndKeepContinuePreservesExistingEntry() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let firstFood = makeTestFoodItem(name: "First")
        let secondFood = makeTestFoodItem(name: "Second")
        context.insert(firstFood)
        context.insert(secondFood)
        try context.save()
        let plan = try makePlan(foods: [(firstFood, 70), (secondFood, 90)])
        let partial = FoodLogEntry(
            date: plan.replicationPlan.destinationDate,
            mealType: plan.replicationPlan.destinationMeal,
            foodItem: firstFood,
            snapshot: plan.items[0].snapshot,
            snackIndex: plan.replicationPlan.destinationSnackIndex,
            replicationOperationID: plan.id,
            replicationItemIndex: 0,
            replicationPlanFingerprint: plan.replicationPlan.fingerprint
        )
        context.insert(partial)
        try context.save()

        let initial = try MultiAddCommands.commit(
            plan: plan,
            modelContainer: container
        )
        guard case .needsRecovery(let state) = initial else {
            return XCTFail("Expected recovery state")
        }
        XCTAssertEqual(state.persistedIndices, [0])
        XCTAssertEqual(state.missingIndices, [1])

        let recovered = try MultiAddCommands.commit(
            plan: plan,
            modelContainer: container,
            recoveryAction: .keepAddedAndContinue
        )
        guard case .completed(let entryIDs, false) = recovered else {
            return XCTFail("Expected completed recovery")
        }
        let entries = try replicatedEntries(plan.id, context: ModelContext(container))
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries.first?.id, partial.id)
        XCTAssertEqual(Set(entryIDs), Set(entries.map(\.id)))
    }

    func testRemoveAndRetryReplacesPartialEntriesInOneCommit() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let firstFood = makeTestFoodItem(name: "First")
        let secondFood = makeTestFoodItem(name: "Second")
        context.insert(firstFood)
        context.insert(secondFood)
        try context.save()
        let plan = try makePlan(foods: [(firstFood, 60), (secondFood, 80)])
        let partial = FoodLogEntry(
            date: plan.replicationPlan.destinationDate,
            mealType: plan.replicationPlan.destinationMeal,
            foodItem: firstFood,
            snapshot: plan.items[0].snapshot,
            snackIndex: plan.replicationPlan.destinationSnackIndex,
            replicationOperationID: plan.id,
            replicationItemIndex: 0,
            replicationPlanFingerprint: plan.replicationPlan.fingerprint
        )
        context.insert(partial)
        try context.save()

        _ = try MultiAddCommands.commit(
            plan: plan,
            modelContainer: container,
            recoveryAction: .removeAndRetry
        )

        let entries = try replicatedEntries(plan.id, context: ModelContext(container))
        XCTAssertEqual(entries.count, 2)
        XCTAssertFalse(entries.map(\.id).contains(partial.id))
        XCTAssertEqual(entries.map(\.replicationItemIndex), [0, 1])
    }

    func testInvalidPartialIndicesCannotBeContinuedButCanBeReplaced() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let food = makeTestFoodItem(name: "Rice")
        context.insert(food)
        try context.save()
        let plan = try makePlan(foods: [(food, 100), (food, 200)])
        let invalid = FoodLogEntry(
            date: plan.replicationPlan.destinationDate,
            mealType: plan.replicationPlan.destinationMeal,
            foodItem: food,
            snapshot: plan.items[0].snapshot,
            snackIndex: 0,
            replicationOperationID: plan.id,
            replicationItemIndex: 9,
            replicationPlanFingerprint: plan.replicationPlan.fingerprint
        )
        context.insert(invalid)
        try context.save()

        let keepOutcome = try MultiAddCommands.commit(
            plan: plan,
            modelContainer: container,
            recoveryAction: .keepAddedAndContinue
        )
        guard case .needsRecovery(let state) = keepOutcome else {
            return XCTFail("An invalid partial index must remain recoverable")
        }
        XCTAssertEqual(state.persistedIndices, [9])
        XCTAssertEqual(state.missingIndices, [0, 1])

        _ = try MultiAddCommands.commit(
            plan: plan,
            modelContainer: container,
            recoveryAction: .removeAndRetry
        )
        XCTAssertEqual(
            try replicatedEntries(plan.id, context: ModelContext(container))
                .map(\.replicationItemIndex),
            [0, 1]
        )
    }

    func testInvalidPlanPreflightWritesNothing() throws {
        let container = try makeContainer()
        let food = makeTestFoodItem(name: "Unsafe")
        var snapshot = FoodLogEntrySnapshot(
            foodItem: food,
            portionGrams: 100,
            mealType: .lunch,
            snackIndex: 0
        )
        snapshot.portionGrams = 0

        XCTAssertThrowsError(
            try MultiAddCommands.plan(
                items: [MultiAddDraftItem(source: .local, snapshot: snapshot)],
                destinationDate: .now,
                destinationMeal: .lunch
            )
        )
        let verify = ModelContext(container)
        XCTAssertEqual(try verify.fetchCount(FetchDescriptor<FoodLogEntry>()), 0)
        XCTAssertEqual(try verify.fetchCount(FetchDescriptor<FoodItem>()), 0)
    }

    func testRemoteProductIsInsertedAtomicallyAndNotDuplicatedOnRetry() throws {
        let container = try makeContainer()
        let product = try makeRemoteProduct()
        let result = makeTestSearchResult(product: product)
        let group = MultiAddSelectionGroup.remoteProduct(
            result,
            searchService: FoodSearchService(),
            meal: .snack,
            snackIndex: 2
        )
        let plan = try MultiAddCommands.plan(
            items: group.items,
            destinationDate: makeTestDate(year: 2026, month: 7, day: 22),
            destinationMeal: .snack,
            destinationSnackIndex: 2
        )

        _ = try MultiAddCommands.commit(plan: plan, modelContainer: container)
        _ = try MultiAddCommands.commit(plan: plan, modelContainer: container)

        let verify = ModelContext(container)
        XCTAssertEqual(try verify.fetchCount(FetchDescriptor<FoodItem>()), 1)
        XCTAssertEqual(try verify.fetchCount(FetchDescriptor<FoodLogEntry>()), 1)
        let entry = try XCTUnwrap(try replicatedEntries(plan.id, context: verify).first)
        XCTAssertEqual(entry.foodName, "Remote yogurt")
        XCTAssertEqual(entry.snackIndex, 2)
        XCTAssertEqual(entry.foodItem?.id, plan.items.first?.snapshot.sourceFoodID)
        XCTAssertEqual(entry.foodItem?.provenance, result.provenance)
        XCTAssertEqual(entry.historicalProvenance, result.provenance)

        entry.foodItem?.provenance = .userEntered
        XCTAssertEqual(entry.foodItem?.provenance.source, .userEntered)
        XCTAssertEqual(entry.historicalProvenance, result.provenance)
    }

    func testSameOperationIDRejectsEveryDifferentCompletePlan() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let food = makeTestFoodItem(name: "Rice")
        context.insert(food)
        try context.save()
        let operationID = UUID()
        let original = try makePlan(
            foods: [(food, 100)],
            operationID: operationID
        )
        _ = try MultiAddCommands.commit(plan: original, modelContainer: container)
        let different = try makePlan(
            foods: [(food, 125)],
            operationID: operationID
        )

        XCTAssertThrowsError(
            try MultiAddCommands.commit(plan: different, modelContainer: container)
        ) { error in
            XCTAssertEqual(
                error as? MealTemplateCommands.CommandError,
                .operationConflict
            )
        }
        XCTAssertEqual(
            try replicatedEntries(operationID, context: ModelContext(container)).count,
            1
        )
    }

    func testPartialOperationRejectsRecoveryWithDifferentPlanFingerprint() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let food = makeTestFoodItem(name: "Rice")
        context.insert(food)
        try context.save()
        let operationID = UUID()
        let original = try makePlan(
            foods: [(food, 100), (food, 200)],
            operationID: operationID
        )
        let partial = FoodLogEntry(
            date: original.replicationPlan.destinationDate,
            mealType: original.replicationPlan.destinationMeal,
            foodItem: food,
            snapshot: original.items[0].snapshot,
            snackIndex: 0,
            replicationOperationID: operationID,
            replicationItemIndex: 0,
            replicationPlanFingerprint: original.replicationPlan.fingerprint
        )
        context.insert(partial)
        try context.save()
        let different = try makePlan(
            foods: [(food, 100), (food, 225)],
            operationID: operationID
        )

        XCTAssertThrowsError(
            try MultiAddCommands.commit(
                plan: different,
                modelContainer: container,
                recoveryAction: .keepAddedAndContinue
            )
        ) { error in
            XCTAssertEqual(
                error as? MealTemplateCommands.CommandError,
                .operationConflict
            )
        }
        XCTAssertEqual(
            try replicatedEntries(operationID, context: ModelContext(container)).map(\.id),
            [partial.id]
        )
    }

    func testInjectedSaveFailurePersistsNeitherRemoteFoodNorBatch() throws {
        let container = try makeContainer()
        let viewContext = ModelContext(container)
        viewContext.autosaveEnabled = false
        let unrelated = makeTestFoodItem(name: "Stored name")
        viewContext.insert(unrelated)
        try viewContext.save()
        unrelated.name = "Pending view edit"
        let result = makeTestSearchResult(product: try makeRemoteProduct())
        let group = MultiAddSelectionGroup.remoteProduct(
            result,
            searchService: FoodSearchService(),
            meal: .lunch,
            snackIndex: 0
        )
        let plan = try MultiAddCommands.plan(
            items: group.items,
            destinationDate: makeTestDate(year: 2026, month: 7, day: 22),
            destinationMeal: .lunch
        )

        XCTAssertThrowsError(
            try MultiAddCommands.commit(
                plan: plan,
                modelContainer: container,
                save: { _ in throw InjectedFailure.save }
            )
        )

        XCTAssertEqual(unrelated.name, "Pending view edit")
        XCTAssertTrue(viewContext.hasChanges)
        let verify = ModelContext(container)
        XCTAssertEqual(try verify.fetchCount(FetchDescriptor<FoodItem>()), 1)
        XCTAssertEqual(try verify.fetchCount(FetchDescriptor<FoodLogEntry>()), 0)
        XCTAssertEqual(try verify.fetch(FetchDescriptor<FoodItem>()).first?.name, "Stored name")
    }

    func testFailedReplaceRecoveryLeavesOriginalPartialStateUntouched() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let food = makeTestFoodItem(name: "Rice")
        context.insert(food)
        try context.save()
        let plan = try makePlan(foods: [(food, 100), (food, 200)])
        let partial = FoodLogEntry(
            date: plan.replicationPlan.destinationDate,
            mealType: plan.replicationPlan.destinationMeal,
            foodItem: food,
            snapshot: plan.items[0].snapshot,
            snackIndex: 0,
            replicationOperationID: plan.id,
            replicationItemIndex: 0,
            replicationPlanFingerprint: plan.replicationPlan.fingerprint
        )
        context.insert(partial)
        try context.save()

        XCTAssertThrowsError(
            try MultiAddCommands.commit(
                plan: plan,
                modelContainer: container,
                recoveryAction: .removeAndRetry,
                save: { _ in throw InjectedFailure.save }
            )
        )

        let persisted = try replicatedEntries(plan.id, context: ModelContext(container))
        XCTAssertEqual(persisted.map(\.id), [partial.id])
        XCTAssertEqual(persisted.map(\.replicationItemIndex), [0])
    }

    func testAnalyticsPayloadIsStrictlyAllowlistedAndCountBucketed() {
        let event = MultiAddAnalyticsEvent(kind: .commitFailed, itemCount: 12)

        XCTAssertEqual(
            event.payload,
            [
                "event": "multi_add_commit_failed",
                "item_count_band": "6_plus",
            ]
        )
        XCTAssertEqual(Set(event.payload.keys), ["event", "item_count_band"])
    }

    private func makePlan(
        foods: [(FoodItem, Double)],
        operationID: UUID = UUID()
    ) throws -> MultiAddCommitPlan {
        let items = foods.map { food, portion in
            MultiAddDraftItem(
                source: .local,
                snapshot: FoodLogEntrySnapshot(
                    foodItem: food,
                    portionGrams: portion,
                    mealType: .lunch,
                    snackIndex: 0
                )
            )
        }
        return try MultiAddCommands.plan(
            items: items,
            destinationDate: makeTestDate(year: 2026, month: 7, day: 22),
            destinationMeal: .lunch,
            operationID: operationID
        )
    }

    private func replicatedEntries(
        _ operationID: UUID,
        context: ModelContext
    ) throws -> [FoodLogEntry] {
        try context.fetch(
            FetchDescriptor<FoodLogEntry>(
                predicate: #Predicate { entry in
                    entry.replicationOperationID == operationID
                },
                sortBy: [SortDescriptor(\.replicationItemIndex)]
            )
        )
    }

    private func makeRemoteProduct() throws -> OpenFoodFactsProduct {
        let json = """
        {
          "code": "issue-77-remote",
          "product_name": "Remote yogurt",
          "brands": "Test",
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

    private func makeContainer() throws -> ModelContainer {
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

    private enum InjectedFailure: Error {
        case save
    }
}
