import CryptoKit
import Foundation
import SwiftData

struct MealTemplateLogPlan: Identifiable, Equatable {
    struct Item: Equatable {
        let snapshot: FoodLogEntrySnapshot
    }

    let id: UUID
    let sourceName: String
    let destinationDate: Date
    let destinationMeal: MealType
    let destinationSnackIndex: Int
    let items: [Item]
    let fingerprint: String
}

@MainActor
enum MealTemplateCommands {
    enum CommandError: LocalizedError, Equatable {
        case emptyName
        case emptySelection
        case invalidSnapshot(String)
        case incompleteTemplate
        case partialDuplicate
        case operationConflict

        var errorDescription: String? {
            switch self {
            case .emptyName:
                "Name this meal before saving it."
            case .emptySelection:
                "Select at least one logged item."
            case .invalidSnapshot(let name):
                "\(name) has saved values that can’t be reused."
            case .incompleteTemplate:
                "This meal template is incomplete and can’t be logged."
            case .partialDuplicate:
                "This meal was only partly logged. Review the destination before trying again."
            case .operationConflict:
                "This save request was already used for different meal details. Review and try again."
            }
        }
    }

    static func suggestedMeal(for entries: [FoodLogEntry]) -> MealType {
        let meals = Set(entries.map(\.mealType))
        if meals.count == 1, let onlyMeal = meals.first {
            return onlyMeal
        }
        return entries.first?.mealType ?? .breakfast
    }

    static func suggestedSnackIndex(
        for entries: [FoodLogEntry],
        meal: MealType
    ) -> Int {
        let requestedIndex = entries.first { $0.mealType == meal }?.snackIndex
        return DailyFoodLogCommands.normalizedSnackIndex(
            for: meal,
            requestedSnackIndex: requestedIndex
        )
    }

    @discardableResult
    static func createTemplate(
        name: String,
        entries: [FoodLogEntry],
        defaultMeal: MealType,
        defaultSnackIndex: Int = 0,
        modelContext: ModelContext,
        operationID: UUID = UUID(),
        now: Date = Date(),
        save: (ModelContext) throws -> Void = { try $0.save() }
    ) throws -> MealTemplate {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else { throw CommandError.emptyName }
        guard !entries.isEmpty else { throw CommandError.emptySelection }

        let snapshots = entries.map(FoodLogEntrySnapshot.init(entry:))
        try snapshots.forEach(validate)
        let normalizedSnackIndex = DailyFoodLogCommands.normalizedSnackIndex(
            for: defaultMeal,
            requestedSnackIndex: defaultSnackIndex
        )
        let creationFingerprint = try fingerprint(
            for: TemplateCreationFingerprintPayload(
                name: normalizedName,
                defaultMeal: defaultMeal,
                defaultSnackIndex: normalizedSnackIndex,
                snapshots: snapshots
            )
        )
        let transactionContext = makeTransactionContext(from: modelContext)

        let existing = try transactionContext.fetch(
            FetchDescriptor<MealTemplate>(
                predicate: #Predicate { template in
                    template.creationOperationID == operationID
                }
            )
        )
        if let existing = existing.first {
            guard existing.creationFingerprint == creationFingerprint else {
                throw CommandError.operationConflict
            }
            return existing
        }

        let template = MealTemplate(
            name: normalizedName,
            defaultMeal: defaultMeal,
            defaultSnackIndex: normalizedSnackIndex,
            creationOperationID: operationID,
            creationFingerprint: creationFingerprint,
            createdAt: now
        )
        let items = try snapshots.enumerated().map { offset, snapshot in
            let item = MealTemplateItem(
                snapshotData: try JSONEncoder().encode(snapshot),
                sourceFoodID: snapshot.sourceFoodID,
                sortOrder: offset,
                createdAt: now.addingTimeInterval(Double(offset) / 1_000)
            )
            item.template = template
            return item
        }

        transactionContext.insert(template)
        items.forEach(transactionContext.insert)
        template.items = items

        try save(transactionContext)
        return template
    }

    static func snapshots(for template: MealTemplate) throws -> [FoodLogEntrySnapshot] {
        let sortedItems = template.sortedItems
        let snapshots: [FoodLogEntrySnapshot] = sortedItems.compactMap { item in
            guard let snapshotData = item.snapshotData else { return nil }
            return try? JSONDecoder().decode(FoodLogEntrySnapshot.self, from: snapshotData)
        }
        guard !snapshots.isEmpty, snapshots.count == sortedItems.count else {
            throw CommandError.incompleteTemplate
        }
        try snapshots.forEach(validate)
        return snapshots
    }

    static func plan(
        sourceName: String,
        snapshots: [FoodLogEntrySnapshot],
        destinationDate: Date,
        destinationMeal: MealType,
        destinationSnackIndex: Int = 0,
        operationID: UUID = UUID(),
        calendar: Calendar = .current
    ) throws -> MealTemplateLogPlan {
        guard !snapshots.isEmpty else { throw CommandError.emptySelection }
        try snapshots.forEach(validate)

        let normalizedDestinationDate = calendar.startOfDay(for: destinationDate)
        let normalizedSnackIndex = DailyFoodLogCommands.normalizedSnackIndex(
            for: destinationMeal,
            requestedSnackIndex: destinationSnackIndex
        )
        let fingerprint = try fingerprint(
            for: LogFingerprintPayload(
                destinationMillisecondsSince1970: Int64(
                    (normalizedDestinationDate.timeIntervalSince1970 * 1_000).rounded()
                ),
                destinationMeal: destinationMeal,
                destinationSnackIndex: normalizedSnackIndex,
                snapshots: snapshots
            )
        )

        return MealTemplateLogPlan(
            id: operationID,
            sourceName: sourceName,
            destinationDate: normalizedDestinationDate,
            destinationMeal: destinationMeal,
            destinationSnackIndex: normalizedSnackIndex,
            items: snapshots.map { MealTemplateLogPlan.Item(snapshot: $0) },
            fingerprint: fingerprint
        )
    }

    @discardableResult
    static func log(
        plan: MealTemplateLogPlan,
        availableFoods: [FoodItem],
        modelContext: ModelContext,
        now: Date = Date(),
        save: (ModelContext) throws -> Void = { try $0.save() }
    ) throws -> [FoodLogEntry] {
        let operationID = plan.id
        let transactionContext = makeTransactionContext(from: modelContext)
        let existing = try transactionContext.fetch(
            FetchDescriptor<FoodLogEntry>(
                predicate: #Predicate { entry in
                    entry.replicationOperationID == operationID
                },
                sortBy: [SortDescriptor(\.replicationItemIndex)]
            )
        )

        if !existing.isEmpty {
            guard existing.allSatisfy({ $0.replicationPlanFingerprint == plan.fingerprint }) else {
                throw CommandError.operationConflict
            }
            let expectedIndices = Set(plan.items.indices)
            let actualIndices = Set(existing.compactMap(\.replicationItemIndex))
            guard existing.count == plan.items.count,
                  actualIndices == expectedIndices else {
                throw CommandError.partialDuplicate
            }
            return existing
        }

        let availableFoodIDs = Set(availableFoods.map(\.id))
        let foodsByID = Dictionary(
            uniqueKeysWithValues: try transactionContext.fetch(FetchDescriptor<FoodItem>())
                .filter { availableFoodIDs.contains($0.id) }
                .map { ($0.id, $0) }
        )
        let entries = plan.items.enumerated().map { offset, item in
            let sourceFood = item.snapshot.sourceFoodID.flatMap { foodsByID[$0] }
            let entry = FoodLogEntry(
                date: plan.destinationDate,
                mealType: plan.destinationMeal,
                foodItem: sourceFood,
                snapshot: item.snapshot,
                snackIndex: plan.destinationSnackIndex,
                createdAt: now.addingTimeInterval(Double(offset) / 1_000),
                replicationOperationID: plan.id,
                replicationItemIndex: offset,
                replicationPlanFingerprint: plan.fingerprint
            )
            transactionContext.insert(entry)
            return entry
        }

        try save(transactionContext)
        return entries
    }

    static func missingSourceCount(
        in snapshots: [FoodLogEntrySnapshot],
        availableFoods: [FoodItem]
    ) -> Int {
        let availableIDs = Set(availableFoods.map(\.id))
        return snapshots.count { snapshot in
            guard let sourceFoodID = snapshot.sourceFoodID else { return true }
            return !availableIDs.contains(sourceFoodID)
        }
    }

    static func delete(
        _ template: MealTemplate,
        modelContext: ModelContext,
        save: (ModelContext) throws -> Void = { try $0.save() }
    ) throws {
        let templateID = template.id
        let transactionContext = makeTransactionContext(from: modelContext)
        let storedTemplate = try transactionContext.fetch(
            FetchDescriptor<MealTemplate>(
                predicate: #Predicate { candidate in
                    candidate.id == templateID
                }
            )
        ).first
        guard let storedTemplate else { throw CommandError.incompleteTemplate }
        transactionContext.delete(storedTemplate)
        try save(transactionContext)
    }

    private struct TemplateCreationFingerprintPayload: Encodable {
        let name: String
        let defaultMeal: MealType
        let defaultSnackIndex: Int
        let snapshots: [FoodLogEntrySnapshot]
    }

    private struct LogFingerprintPayload: Encodable {
        let destinationMillisecondsSince1970: Int64
        let destinationMeal: MealType
        let destinationSnackIndex: Int
        let snapshots: [FoodLogEntrySnapshot]
    }

    private static func fingerprint<Payload: Encodable>(for payload: Payload) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let digest = SHA256.hash(data: try encoder.encode(payload))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func makeTransactionContext(from sourceContext: ModelContext) -> ModelContext {
        // Commands must not save or roll back unrelated edits pending in the
        // shared SwiftUI environment context.
        let context = ModelContext(sourceContext.container)
        context.autosaveEnabled = false
        return context
    }

    private static func validate(_ snapshot: FoodLogEntrySnapshot) throws {
        let values: [Double?] = [
            snapshot.portionGrams,
            snapshot.nutrition.calories,
            snapshot.nutrition.proteinG,
            snapshot.nutrition.carbsG,
            snapshot.nutrition.fatG,
            snapshot.nutrition.fiberG,
            snapshot.nutrition.sugarsG,
            snapshot.nutrition.addedSugarsG,
            snapshot.nutrition.sucroseG,
            snapshot.nutrition.glucoseG,
            snapshot.nutrition.fructoseG,
            snapshot.nutrition.lactoseG,
            snapshot.nutrition.maltoseG,
            snapshot.nutrition.maltodextrinsG,
            snapshot.nutrition.starchG,
            snapshot.nutrition.polyolsG,
            snapshot.nutrition.saturatedFatG,
            snapshot.nutrition.transFatG,
            snapshot.nutrition.monounsaturatedFatG,
            snapshot.nutrition.polyunsaturatedFatG,
            snapshot.nutrition.omega3FatG,
            snapshot.nutrition.omega6FatG,
            snapshot.nutrition.omega9FatG,
            snapshot.nutrition.saltG,
            snapshot.nutrition.sodiumG,
            snapshot.nutrition.cholesterolG,
            snapshot.nutrition.solubleFiberG,
            snapshot.nutrition.insolubleFiberG,
            snapshot.nutrition.caseinG,
            snapshot.nutrition.serumProteinsG,
            snapshot.nutrition.alcoholG,
        ]
        guard !snapshot.foodName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              FavoriteFoodLogging.isSafePortion(snapshot.portionGrams),
              values.compactMap({ $0 }).allSatisfy({ $0.isFinite && $0 >= 0 }) else {
            throw CommandError.invalidSnapshot(snapshot.foodName.isEmpty ? "This item" : snapshot.foodName)
        }
    }
}
