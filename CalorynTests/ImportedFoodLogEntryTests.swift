import Foundation
import SwiftData
import Testing
@testable import Caloryn

@MainActor
@Suite("Logging an imported food")
struct ImportedFoodLogEntryTests {
    struct ImportInput: Sendable, CustomTestStringConvertible {
        let description: String
        var name = "Greek yogurt"
        var calories = 150.0
        var portionGrams = 170.0
        var proteinG: Double? = 15
        var carbsG: Double? = 6
        var fatG: Double? = 4

        var testDescription: String { description }
    }

    @Test("Logs exactly one entry with the imported values and no saved food")
    func logsOneSnapshotEntry() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        try DailyFoodLogCommands.logImported(
            name: "Greek yogurt",
            calories: 150,
            portionGrams: 170,
            proteinG: 15,
            carbsG: 6,
            fatG: 4,
            mealType: .lunch,
            snackIndex: nil,
            logDate: makeTestDate(year: 2026, month: 10, day: 24, hour: 13, minute: 20),
            modelContext: context
        )
        try context.save()

        let verificationContext = ModelContext(container)
        let entries = try verificationContext.fetch(FetchDescriptor<FoodLogEntry>())
        let foods = try verificationContext.fetch(FetchDescriptor<FoodItem>())
        #expect(foods.isEmpty)
        #expect(entries.count == 1)
        let entry = try #require(entries.first)
        #expect(entry.foodItem == nil)
        #expect(entry.foodName == "Greek yogurt")
        #expect(entry.portionGrams == 170)
        #expect(entry.calories == 150)
        #expect(entry.proteinG == 15)
        #expect(entry.carbsG == 6)
        #expect(entry.fatG == 4)
        #expect(entry.date == makeTestDate(year: 2026, month: 10, day: 24).startOfDay)
        #expect(entry.mealType == .lunch)
        #expect(entry.snackIndex == 0)
        #expect(entry.historicalNutriscoreGrade == nil)
    }

    @Test("The import source survives a save and reload")
    func sourceRoundTrips() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        try logImported(ImportInput(description: "complete"), into: context)
        try context.save()

        let entry = try #require(
            ModelContext(container).fetch(FetchDescriptor<FoodLogEntry>()).first
        )
        #expect(entry.dataSourceSnapshotRaw == "link_import")
        #expect(
            entry.historicalProvenance
                == FoodProvenance(
                    provider: nil,
                    source: .linkImport,
                    completeness: .complete,
                    recoveredByFallback: false
                )
        )
    }

    @Test(
        "Snack entries keep a snack slot and other meals have none",
        arguments: [
            (MealType.snack, nil, 1),
            (.snack, 3, 3),
            (.snack, 0, 1),
            (.breakfast, 3, 0),
            (.dinner, nil, 0),
        ] as [(MealType, Int?, Int)]
    )
    func snackIndex(mealType: MealType, requested: Int?, expected: Int) throws {
        let context = ModelContext(try makeContainer())

        let entry = try DailyFoodLogCommands.logImported(
            name: "Apple",
            calories: 52,
            portionGrams: 100,
            proteinG: 0.3,
            carbsG: 14,
            fatG: 0.2,
            mealType: mealType,
            snackIndex: requested,
            logDate: makeTestDate(year: 2026, month: 10, day: 24),
            modelContext: context
        )

        #expect(entry.mealType == mealType)
        #expect(entry.snackIndex == expected)
    }

    @Test(
        "Nutrition is partial whenever a macro was not supplied",
        arguments: [
            (15, 6, 4, NutritionCompleteness.complete),
            (0, 0, 0, .complete),
            (nil, 6, 4, .partial),
            (15, nil, 4, .partial),
            (15, 6, nil, .partial),
            (nil, nil, nil, .partial),
        ] as [(Double?, Double?, Double?, NutritionCompleteness)]
    )
    func completeness(
        proteinG: Double?,
        carbsG: Double?,
        fatG: Double?,
        expected: NutritionCompleteness
    ) throws {
        let context = ModelContext(try makeContainer())

        let entry = try logImported(
            ImportInput(description: "macros", proteinG: proteinG, carbsG: carbsG, fatG: fatG),
            into: context
        )

        #expect(entry.historicalProvenance.completeness == expected)
        #expect(entry.historicalProvenance.warrantsNutritionNotice == (expected == .partial))
    }

    @Test(
        "Invalid imported values are rejected and nothing is logged",
        arguments: [
            ImportInput(description: "blank name", name: " \n "),
            ImportInput(description: "negative calories", calories: -1),
            ImportInput(description: "calories above 20000", calories: 20_000.01),
            ImportInput(description: "NaN calories", calories: .nan),
            ImportInput(description: "infinite calories", calories: .infinity),
            ImportInput(description: "zero grams", portionGrams: 0),
            ImportInput(description: "negative grams", portionGrams: -170),
            ImportInput(description: "grams above the safe portion", portionGrams: 100_000.01),
            ImportInput(description: "NaN grams", portionGrams: .nan),
            ImportInput(description: "infinite grams", portionGrams: .infinity),
            ImportInput(description: "negative protein", proteinG: -0.01),
            ImportInput(description: "protein heavier than the portion", proteinG: 170.01),
            ImportInput(description: "carbs heavier than the portion", carbsG: 171),
            ImportInput(description: "fat heavier than the portion", fatG: 200),
            ImportInput(description: "NaN protein", proteinG: .nan),
            ImportInput(description: "infinite carbs", carbsG: .infinity),
            ImportInput(description: "negative infinite fat", fatG: -.infinity),
        ]
    )
    func rejectsInvalidInput(input: ImportInput) throws {
        let context = ModelContext(try makeContainer())

        #expect(throws: DailyFoodLogCommands.CommandError.invalidImportedEntry) {
            try logImported(input, into: context)
        }

        #expect(try context.fetch(FetchDescriptor<FoodLogEntry>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<FoodItem>()).isEmpty)
    }

    @Test(
        "Boundary values are accepted",
        arguments: [
            ImportInput(description: "zero calories", calories: 0),
            ImportInput(description: "20000 calories", calories: 20_000),
            ImportInput(description: "largest safe portion", portionGrams: 100_000),
            ImportInput(description: "macros equal to the portion", proteinG: 170, carbsG: 170, fatG: 170),
            ImportInput(description: "zero macros", proteinG: 0, carbsG: 0, fatG: 0),
        ]
    )
    func acceptsBoundaryInput(input: ImportInput) throws {
        let context = ModelContext(try makeContainer())

        try logImported(input, into: context)

        #expect(try context.fetch(FetchDescriptor<FoodLogEntry>()).count == 1)
    }

    @Test("The rejection explains itself to the user")
    func rejectionMessage() {
        #expect(
            DailyFoodLogCommands.CommandError.invalidImportedEntry.errorDescription
                == "This food can’t be logged because its name, portion or nutrition values aren’t valid."
        )
    }

    @Test("Editing the portion later rescales calories and macros and keeps the import source")
    func portionEditRescales() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let entry = try logImported(
            ImportInput(description: "no carbs", carbsG: nil),
            into: context
        )
        try context.save()

        try DailyFoodLogCommands.saveSnapshotEntry(
            entry,
            date: makeTestDate(year: 2026, month: 10, day: 24),
            mealType: .lunch,
            portionGrams: 340,
            modelContext: context
        )

        let verificationContext = ModelContext(container)
        let edited = try #require(verificationContext.fetch(FetchDescriptor<FoodLogEntry>()).first)
        #expect(edited.foodItem == nil)
        #expect(edited.foodName == "Greek yogurt")
        #expect(edited.portionGrams == 340)
        #expect(edited.calories == 300)
        #expect(edited.proteinG == 30)
        #expect(edited.fatG == 8)
        #expect(
            edited.historicalProvenance
                == FoodProvenance(
                    provider: nil,
                    source: .linkImport,
                    completeness: .partial,
                    recoveredByFallback: false
                )
        )
        #expect(try verificationContext.fetch(FetchDescriptor<FoodItem>()).isEmpty)
    }

    @discardableResult
    private func logImported(_ input: ImportInput, into context: ModelContext) throws -> FoodLogEntry {
        try DailyFoodLogCommands.logImported(
            name: input.name,
            calories: input.calories,
            portionGrams: input.portionGrams,
            proteinG: input.proteinG,
            carbsG: input.carbsG,
            fatG: input.fatG,
            mealType: .lunch,
            snackIndex: nil,
            logDate: makeTestDate(year: 2026, month: 10, day: 24),
            modelContext: context
        )
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: FoodItem.self,
            FoodLogEntry.self,
            RecipeIngredient.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
}
