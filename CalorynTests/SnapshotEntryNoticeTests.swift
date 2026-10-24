import Foundation
import SwiftData
import Testing
@testable import Caloryn

@MainActor
@Suite("Snapshot entry notice")
struct SnapshotEntryNoticeTests {
    private static let importedNotice =
        "This food was imported, so it isn’t saved in My Foods. Editing uses the nutrition values recorded in this log entry."
    private static let missingFoodNotice =
        "The original saved food is missing. Editing uses the nutrition and quality values recorded in this log entry."

    @Test("An imported entry reads as imported rather than as a lost food")
    func importedEntry() {
        #expect(SnapshotEntryNotice.message(for: .linkImport) == Self.importedNotice)
    }

    @Test(
        "An entry whose saved food is gone says the food is missing",
        arguments: [
            FoodDataSource.calorynCatalog,
            .openFoodFactsCommunity,
            .userEntered,
            .mixed,
            .unknown,
        ]
    )
    func orphanedEntry(source: FoodDataSource) {
        #expect(SnapshotEntryNotice.message(for: source) == Self.missingFoodNotice)
    }

    @Test("An imported entry and an entry whose food was deleted get different notices")
    func entriesFromTheLog() throws {
        let context = ModelContext(
            try ModelContainer(
                for: FoodItem.self,
                FoodLogEntry.self,
                RecipeIngredient.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        )
        let imported = try DailyFoodLogCommands.logImported(
            name: "Greek yogurt",
            calories: 150,
            portionGrams: 170,
            proteinG: 15,
            carbsG: nil,
            fatG: 4,
            mealType: .lunch,
            snackIndex: nil,
            logDate: makeTestDate(year: 2026, month: 10, day: 24),
            modelContext: context
        )
        let food = makeTestFoodItem(name: "Archived soup")
        let orphaned = DailyFoodLogCommands.logFood(
            foodItem: food,
            portionGrams: 250,
            mealType: .dinner,
            logDate: makeTestDate(year: 2026, month: 10, day: 24),
            isNewFood: true,
            modelContext: context
        )
        try context.save()
        food.deletePreservingLogEntrySnapshots(from: context)
        try context.save()

        #expect(imported.foodItem == nil)
        #expect(orphaned.foodItem == nil)
        #expect(SnapshotEntryNotice.message(for: imported.historicalProvenance.source) == Self.importedNotice)
        #expect(SnapshotEntryNotice.message(for: orphaned.historicalProvenance.source) == Self.missingFoodNotice)
    }
}
