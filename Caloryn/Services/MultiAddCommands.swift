import Foundation
import SwiftData

struct MultiAddCommitPlan: Identifiable, Equatable {
    let replicationPlan: MealTemplateLogPlan
    let items: [MultiAddDraftItem]

    var id: UUID { replicationPlan.id }

    fileprivate init(
        replicationPlan: MealTemplateLogPlan,
        items: [MultiAddDraftItem]
    ) {
        self.replicationPlan = replicationPlan
        self.items = items
    }
}

struct MultiAddPartialBatch: Equatable {
    let operationID: UUID
    let expectedCount: Int
    let persistedCount: Int
    let persistedIndices: [Int]
    let missingIndices: [Int]
}

@MainActor
enum MultiAddCommands {
    enum RecoveryAction {
        case removeAndRetry
        case keepAddedAndContinue
    }

    enum CommitOutcome: Equatable {
        case completed(entryIDs: [UUID], alreadyCommitted: Bool)
        case needsRecovery(MultiAddPartialBatch)
    }

    enum CommandError: LocalizedError, Equatable {
        case inconsistentRemoteSource
        case unavailableRemoteFood(String)

        var errorDescription: String? {
            switch self {
            case .inconsistentRemoteSource:
                "A selected search result changed. Remove it and select it again."
            case .unavailableRemoteFood(let name):
                "\(name) has values that can’t be logged."
            }
        }
    }

    static func plan(
        items: [MultiAddDraftItem],
        destinationDate: Date,
        destinationMeal: MealType,
        destinationSnackIndex: Int = 0,
        operationID: UUID = UUID(),
        calendar: Calendar = .current
    ) throws -> MultiAddCommitPlan {
        for item in items {
            if case .remote(let foodID, _) = item.source,
               item.snapshot.sourceFoodID != foodID {
                throw CommandError.inconsistentRemoteSource
            }
        }
        let replicationPlan = try MealTemplateCommands.plan(
            sourceName: items.count == 1 ? "1 selected item" : "\(items.count) selected items",
            snapshots: items.map(\.snapshot),
            destinationDate: destinationDate,
            destinationMeal: destinationMeal,
            destinationSnackIndex: destinationSnackIndex,
            operationID: operationID,
            calendar: calendar
        )
        return MultiAddCommitPlan(replicationPlan: replicationPlan, items: items)
    }

    /// Delegates the transaction to #74's isolated-context command path so an
    /// unrelated pending view edit is never saved or rolled back with a batch.
    static func commit(
        plan: MultiAddCommitPlan,
        modelContainer: ModelContainer,
        recoveryAction: RecoveryAction? = nil,
        now: Date = Date(),
        save: (ModelContext) throws -> Void = { try $0.save() }
    ) throws -> CommitOutcome {
        let sourceContext = ModelContext(modelContainer)
        sourceContext.autosaveEnabled = false
        let state = try MealTemplateCommands.replicationState(
            for: plan.replicationPlan,
            modelContext: sourceContext
        )

        if state.isComplete {
            return .completed(
                entryIDs: state.entryIDs,
                alreadyCommitted: true
            )
        }

        if !state.isEmpty, recoveryAction == nil {
            return .needsRecovery(
                partialState(operationID: plan.id, replicationState: state)
            )
        }

        let policy: MealTemplateCommands.ExistingBatchPolicy
        switch recoveryAction {
        case nil:
            policy = .rejectPartial
        case .removeAndRetry:
            policy = .replacePartial
        case .keepAddedAndContinue:
            policy = .completePartial
        }

        do {
            let logged = try MealTemplateCommands.log(
                plan: plan.replicationPlan,
                availableFoods: [],
                modelContext: sourceContext,
                existingBatchPolicy: policy,
                now: now,
                save: save,
                transactionFoodResolver: { transactionContext in
                    try resolveFoods(
                        for: plan,
                        modelContext: transactionContext,
                        now: now
                    )
                }
            )
            return .completed(
                entryIDs: logged.map(\.id),
                alreadyCommitted: false
            )
        } catch MealTemplateCommands.CommandError.partialDuplicate {
            let refreshed = try MealTemplateCommands.replicationState(
                for: plan.replicationPlan,
                modelContext: sourceContext
            )
            guard !refreshed.isEmpty else {
                throw MealTemplateCommands.CommandError.partialDuplicate
            }
            return .needsRecovery(
                partialState(operationID: plan.id, replicationState: refreshed)
            )
        }
    }

    private static func resolveFoods(
        for plan: MultiAddCommitPlan,
        modelContext: ModelContext,
        now: Date
    ) throws -> [FoodItem] {
        let sourceIDs = Set(plan.items.compactMap(\.snapshot.sourceFoodID))
        var foodsByID: [UUID: FoodItem] = [:]
        for foodID in sourceIDs {
            var descriptor = FetchDescriptor<FoodItem>(
                predicate: #Predicate { food in food.id == foodID }
            )
            descriptor.fetchLimit = 1
            if let food = try modelContext.fetch(descriptor).first {
                foodsByID[foodID] = food
            }
        }

        for item in plan.items {
            guard case .remote(let foodID, let product) = item.source,
                  foodsByID[foodID] == nil else {
                continue
            }
            let food = FoodSearchService().createFoodItem(from: product)
            food.id = foodID
            guard FavoriteFoodLogging.isAvailableForLogging(food) else {
                throw CommandError.unavailableRemoteFood(food.name)
            }
            modelContext.insert(food)
            foodsByID[foodID] = food
        }

        for food in foodsByID.values {
            food.lastUsed = now
        }
        return Array(foodsByID.values)
    }

    private static func partialState(
        operationID: UUID,
        replicationState: MealTemplateReplicationState
    ) -> MultiAddPartialBatch {
        let expectedIndices = Set(0..<replicationState.expectedCount)
        let actualIndices = Set(replicationState.persistedIndices)
        return MultiAddPartialBatch(
            operationID: operationID,
            expectedCount: replicationState.expectedCount,
            persistedCount: replicationState.entryIDs.count,
            persistedIndices: actualIndices.sorted(),
            missingIndices: expectedIndices.subtracting(actualIndices).sorted()
        )
    }
}

/// This allowlisted envelope is intentionally incapable of carrying food,
/// barcode, nutrition, meal, time, weekday, score, or identifier data.
struct MultiAddAnalyticsEvent: Equatable {
    enum Kind: String, CaseIterable {
        case suggestionsShown = "multi_add_suggestions_shown"
        case reviewShown = "multi_add_review_shown"
        case commitSucceeded = "multi_add_commit_succeeded"
        case commitFailed = "multi_add_commit_failed"
        case recoveryChosen = "multi_add_recovery_chosen"
    }

    enum ItemCountBand: String {
        case one
        case twoToFive = "2_5"
        case sixOrMore = "6_plus"

        init(count: Int) {
            switch count {
            case ...1: self = .one
            case 2...5: self = .twoToFive
            default: self = .sixOrMore
            }
        }
    }

    let kind: Kind
    let itemCountBand: ItemCountBand

    init(kind: Kind, itemCount: Int) {
        self.kind = kind
        itemCountBand = ItemCountBand(count: itemCount)
    }

    var payload: [String: String] {
        ["event": kind.rawValue, "item_count_band": itemCountBand.rawValue]
    }
}
