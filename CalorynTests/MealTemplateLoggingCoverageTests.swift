import Foundation
import SwiftData
import Testing
@testable import Caloryn

@MainActor
private func utcCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}

@MainActor
private func utcDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
    utcCalendar().date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

@MainActor
private func makeMealContainer() throws -> ModelContainer {
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

@MainActor
@Suite("Meal type naming coverage")
struct MealTypeNamingCoverageTests {
    @Test(
        "Each meal has its icon and position in the day",
        arguments: [
            (MealType.breakfast, "sunrise.fill", 0),
            (MealType.lunch, "sun.max.fill", 1),
            (MealType.snack, "leaf.fill", 2),
            (MealType.dinner, "moon.fill", 3),
        ]
    )
    func mealNamingAndOrder(meal: MealType, icon: String, order: Int) {
        #expect(meal.iconName == icon)
        #expect(meal.sortOrder == order)
    }

    @Test("Every widget meal maps back to the meal of the same name, and round-trips")
    func widgetMealRoundTrips() {
        for widgetMeal in WidgetMeal.allCases {
            let meal = MealType(widgetMeal: widgetMeal)
            #expect(meal.rawValue == widgetMeal.rawValue)
            #expect(meal.widgetMeal == widgetMeal)
        }
        for meal in MealType.allCases {
            #expect(MealType(widgetMeal: meal.widgetMeal) == meal)
        }
    }

    @Test("Only a snack names its slot")
    func onlySnacksNameTheirSlot() {
        #expect(MealType.snack.displayName(snackIndex: 2) == "Snack 2")
        #expect(MealType.lunch.displayName(snackIndex: 2) == "Lunch")
    }
}

@MainActor
@Suite("Snack index normalisation coverage")
struct SnackIndexNormalisationCoverageTests {
    @Test(
        "A snack slot is at least 1 and a core meal has none",
        arguments: [
            (MealType.snack, Int?.none, 1),
            (MealType.snack, Int?.some(0), 1),
            (MealType.snack, Int?.some(-4), 1),
            (MealType.snack, Int?.some(1), 1),
            (MealType.snack, Int?.some(3), 3),
            (MealType.breakfast, Int?.some(3), 0),
            (MealType.lunch, Int?.none, 0),
            (MealType.dinner, Int?.some(-1), 0),
        ]
    )
    func normalisedSnackIndex(meal: MealType, requested: Int?, expected: Int) {
        #expect(DailyFoodLogCommands.normalizedSnackIndex(for: meal, requestedSnackIndex: requested) == expected)
    }

    @Test("Without a requested slot a snack goes to slot 1")
    func defaultSnackSlot() {
        #expect(DailyFoodLogCommands.normalizedSnackIndex(for: .snack) == 1)
        #expect(DailyFoodLogCommands.normalizedSnackIndex(for: .dinner) == 0)
    }

    @Test(
        "A saved meal's default snack slot is normalised when created",
        arguments: [
            (MealType.snack, 0, 1),
            (MealType.snack, 2, 2),
            (MealType.lunch, 3, 0),
        ]
    )
    func templateInitNormalisesSnackSlot(meal: MealType, requested: Int, expected: Int) {
        let template = MealTemplate(
            name: "Meal",
            defaultMeal: meal,
            defaultSnackIndex: requested,
            creationOperationID: UUID(),
            creationFingerprint: ""
        )
        #expect(template.defaultSnackIndex == expected)
        #expect(template.defaultSnackIndexRaw == expected)
    }

    @Test("Changing a saved meal's default meal and slot keeps the slot rules")
    func templateSettersKeepSlotRules() {
        let template = MealTemplate(
            name: "Meal",
            defaultMeal: .lunch,
            defaultSnackIndex: 0,
            creationOperationID: UUID(),
            creationFingerprint: ""
        )

        template.defaultSnackIndex = 4
        #expect(template.defaultSnackIndex == 0, "a lunch has no snack slot")
        #expect(template.defaultSnackIndexRaw == 0)

        template.defaultMeal = .snack
        #expect(template.defaultMealRaw == "snack")
        #expect(template.defaultSnackIndex == 1, "a stored 0 reads as the first slot")

        template.defaultSnackIndex = 3
        #expect(template.defaultSnackIndex == 3)

        template.defaultSnackIndex = -2
        #expect(template.defaultSnackIndex == 1)
        #expect(template.defaultSnackIndexRaw == 1)
    }

    @Test("A saved meal with an unknown or missing stored meal falls back to breakfast")
    func unknownStoredMealIsBreakfast() {
        let template = MealTemplate(
            name: "Meal",
            defaultMeal: .snack,
            defaultSnackIndex: 2,
            creationOperationID: UUID(),
            creationFingerprint: ""
        )
        template.defaultMealRaw = "brunch"
        #expect(template.defaultMeal == .breakfast)
        #expect(template.defaultSnackIndex == 0)

        template.defaultMealRaw = "snack"
        template.defaultSnackIndexRaw = nil
        #expect(template.defaultSnackIndex == 1)
    }

    @Test("Items with the same position are ordered by identifier so the order is stable")
    func sortedItemsBreakTiesByIdentifier() throws {
        let template = MealTemplate(
            name: "Meal",
            defaultMeal: .lunch,
            defaultSnackIndex: 0,
            creationOperationID: UUID(),
            creationFingerprint: ""
        )
        let data = Data("{}".utf8)
        let first = MealTemplateItem(snapshotData: data, sourceFoodID: nil, sortOrder: 1)
        first.id = try #require(UUID(uuidString: "00000000-0000-0000-0000-00000000000B"))
        let second = MealTemplateItem(snapshotData: data, sourceFoodID: nil, sortOrder: 1)
        second.id = try #require(UUID(uuidString: "00000000-0000-0000-0000-00000000000A"))
        let earliest = MealTemplateItem(snapshotData: data, sourceFoodID: nil, sortOrder: 0)
        template.items = [first, second, earliest]

        #expect(template.sortedItems.map(\.id) == [earliest.id, second.id, first.id])
    }
}

@MainActor
@Suite("Meal component amount coverage")
struct MealComponentAmountCoverageTests {
    @Test("A component's amount sheet works per 100 g, whatever portion it holds")
    func amountDraftIsPer100g() {
        let food = makeTestFoodItem(
            name: "Granola",
            caloriesPer100g: 450,
            proteinPer100g: 10,
            carbsPer100g: 60,
            fatPer100g: 18,
            fiberPer100g: 8,
            sugarsPer100g: 20,
            saturatedFatPer100g: 3,
            sodiumPer100g: 0.2,
            produceKind: .fruit
        )
        let component = MealComponentDraft(foodItem: food).updatingPortion(to: 40)

        let amount = component.amountDraft

        #expect(amount.id == component.id)
        #expect(amount.name == "Granola")
        #expect(amount.portionGrams == 40)
        #expect(abs(amount.caloriesPer100g - 450) < 1e-9)
        #expect(abs(amount.proteinPer100g - 10) < 1e-9)
        #expect(abs(amount.carbsPer100g - 60) < 1e-9)
        #expect(abs(amount.fatPer100g - 18) < 1e-9)
        #expect(abs(amount.fiberPer100g - 8) < 1e-9)
        #expect(abs((amount.sugarsPer100g ?? -1) - 20) < 1e-9)
        #expect(abs((amount.saturatedFatPer100g ?? -1) - 3) < 1e-9)
        #expect(abs((amount.sodiumPer100g ?? -1) - 0.2) < 1e-9)
        #expect(amount.addedSugarsPer100g == nil)
        #expect(amount.alcoholPer100g == nil)
        #expect(amount.produceKind == .fruit)
        #expect(abs(amount.calories - 180) < 1e-9)
        #expect(abs(component.snapshot.nutrition.calories - 180) < 1e-9)
    }

    @Test("A component weighing nothing offers zero per-100g values instead of dividing by zero")
    func zeroPortionAmountDraftIsZero() {
        let food = makeTestFoodItem(name: "Tea", caloriesPer100g: 1, sugarsPer100g: 0.2)
        var component = MealComponentDraft(foodItem: food)
        component.snapshot.portionGrams = 0

        let amount = component.amountDraft

        #expect(amount.portionGrams == 0)
        #expect(amount.caloriesPer100g == 0)
        #expect(amount.proteinPer100g == 0)
        #expect(amount.sugarsPer100g == nil)
    }

    @Test("A component without a recorded produce kind is unclassified on the amount sheet")
    func missingProduceKindIsUnclassified() {
        var component = MealComponentDraft(foodItem: makeTestFoodItem(produceKind: .vegetable))
        component.snapshot.produceKindSnapshotRaw = nil
        #expect(component.amountDraft.produceKind == .unclassified)

        component.snapshot.produceKindSnapshotRaw = "rock"
        #expect(component.amountDraft.produceKind == .unclassified)
    }

    @Test("A new component starts at the food's own serving, or 100 g without one")
    func newComponentStartsAtServing() {
        let served = MealComponentDraft(foodItem: makeTestFoodItem(caloriesPer100g: 200, defaultServingG: 30))
        let unserved = MealComponentDraft(foodItem: makeTestFoodItem(caloriesPer100g: 200))

        #expect(served.snapshot.portionGrams == 30)
        #expect(abs(served.snapshot.nutrition.calories - 60) < 1e-9)
        #expect(unserved.snapshot.portionGrams == 100)
        #expect(abs(unserved.snapshot.nutrition.calories - 200) < 1e-9)
    }

    @Test("The meal form's total is the sum of every component's scaled portion")
    func mealFormTotalsScaledPortions() {
        var draft = MealFormDraft()
        draft.upsert(MealComponentDraft(foodItem: makeTestFoodItem(
            caloriesPer100g: 389, proteinPer100g: 17, carbsPer100g: 66, fatPer100g: 7
        )).updatingPortion(to: 80))
        draft.upsert(MealComponentDraft(foodItem: makeTestFoodItem(
            caloriesPer100g: 64, proteinPer100g: 3.4, carbsPer100g: 4.8, fatPer100g: 3.6
        )).updatingPortion(to: 200))

        #expect(abs(draft.totalNutrition.calories - 439.2) < 1e-9)
        #expect(abs(draft.totalNutrition.proteinG - 20.4) < 1e-9)
        #expect(abs(draft.totalNutrition.carbsG - 62.4) < 1e-9)
        #expect(abs(draft.totalNutrition.fatG - 12.8) < 1e-9)
    }
}

@MainActor
@Suite("Meal template commands coverage")
struct MealTemplateCommandsCoverageTests {
    @Test("Every template error explains itself to the user")
    func errorDescriptions() {
        typealias E = MealTemplateCommands.CommandError
        #expect(E.emptyName.errorDescription == "Name this meal before saving it.")
        #expect(E.emptySelection.errorDescription == "Add at least one item to this meal.")
        #expect(E.invalidSnapshot("Soup").errorDescription == "Soup has saved values that can’t be reused.")
        #expect(E.incompleteTemplate.errorDescription == "This meal is incomplete and can’t be added.")
        #expect(E.partialDuplicate.errorDescription
            == "This meal was only partly logged. Review the destination before trying again.")
        #expect(E.operationConflict.errorDescription
            == "This save request was already used for different meal details. Review and try again.")
    }

    @Test("A selection from one meal suggests that meal; a mixed one suggests its first entry's meal")
    func suggestedMealForSelections() {
        let food = makeTestFoodItem()
        let dinner = makeTestEntry(mealType: .dinner, foodItem: food)
        let lunch = makeTestEntry(mealType: .lunch, foodItem: food)
        let otherLunch = makeTestEntry(mealType: .lunch, foodItem: food)

        #expect(MealTemplateCommands.suggestedMeal(for: [lunch, otherLunch]) == .lunch)
        #expect(MealTemplateCommands.suggestedMeal(for: [dinner, lunch]) == .dinner)
        #expect(MealTemplateCommands.suggestedMeal(for: [lunch, dinner]) == .lunch)
        #expect(MealTemplateCommands.suggestedMeal(for: []) == .breakfast)
    }

    @Test("Editing a meal that no longer exists fails and saves nothing")
    func savingUnknownExistingMealFails() throws {
        let container = try makeMealContainer()
        let context = ModelContext(container)
        let snapshot = FoodLogEntrySnapshot(foodItem: makeTestFoodItem(name: "Oats"), portionGrams: 80)

        #expect(throws: MealTemplateCommands.CommandError.incompleteTemplate) {
            try MealTemplateCommands.saveMeal(
                name: "Breakfast",
                snapshots: [snapshot],
                existingMealID: UUID(),
                modelContext: context
            )
        }
        let verify = ModelContext(container)
        #expect(try verify.fetchCount(FetchDescriptor<MealTemplate>()) == 0)
        #expect(try verify.fetchCount(FetchDescriptor<MealTemplateItem>()) == 0)
    }

    @Test("A blank-named or empty meal cannot be saved")
    func saveMealRejectsBlankNameAndEmptySelection() throws {
        let context = ModelContext(try makeMealContainer())
        let snapshot = FoodLogEntrySnapshot(foodItem: makeTestFoodItem(name: "Oats"), portionGrams: 80)

        #expect(throws: MealTemplateCommands.CommandError.emptyName) {
            try MealTemplateCommands.saveMeal(name: " \n ", snapshots: [snapshot], modelContext: context)
        }
        #expect(throws: MealTemplateCommands.CommandError.emptySelection) {
            try MealTemplateCommands.saveMeal(name: "Breakfast", snapshots: [], modelContext: context)
        }
    }

    @Test("A meal with no items, or with an unreadable item, is incomplete")
    func incompleteTemplatesCannotBeReused() throws {
        let empty = MealTemplate(
            name: "Empty",
            defaultMeal: .lunch,
            defaultSnackIndex: 0,
            creationOperationID: UUID(),
            creationFingerprint: ""
        )
        empty.items = []
        #expect(throws: MealTemplateCommands.CommandError.incompleteTemplate) {
            try MealTemplateCommands.snapshots(for: empty)
        }

        let mixed = MealTemplate(
            name: "Mixed",
            defaultMeal: .lunch,
            defaultSnackIndex: 0,
            creationOperationID: UUID(),
            creationFingerprint: ""
        )
        let good = FoodLogEntrySnapshot(foodItem: makeTestFoodItem(name: "Soup"), portionGrams: 300)
        mixed.items = [
            MealTemplateItem(snapshotData: try JSONEncoder().encode(good), sourceFoodID: nil, sortOrder: 0),
            MealTemplateItem(snapshotData: Data("garbage".utf8), sourceFoodID: nil, sortOrder: 1),
        ]
        #expect(throws: MealTemplateCommands.CommandError.incompleteTemplate) {
            try MealTemplateCommands.snapshots(for: mixed)
        }
    }

    @Test("A snapshot with a blank name, an unsafe portion or a non-finite nutrient cannot be planned")
    func invalidSnapshotsAreNamedInTheError() {
        let food = makeTestFoodItem(name: "Soup")
        var blankName = FoodLogEntrySnapshot(foodItem: food, portionGrams: 100)
        blankName.foodName = ""
        var hugePortion = FoodLogEntrySnapshot(foodItem: food, portionGrams: 100)
        hugePortion.portionGrams = 100_001
        var negativeSugar = FoodLogEntrySnapshot(foodItem: food, portionGrams: 100)
        negativeSugar.nutrition.sugarsG = -1
        var infiniteCalories = FoodLogEntrySnapshot(foodItem: food, portionGrams: 100)
        infiniteCalories.nutrition.calories = .infinity

        let cases: [(FoodLogEntrySnapshot, String)] = [
            (blankName, "This item"),
            (hugePortion, "Soup"),
            (negativeSugar, "Soup"),
            (infiniteCalories, "Soup"),
        ]
        for (snapshot, name) in cases {
            #expect(throws: MealTemplateCommands.CommandError.invalidSnapshot(name)) {
                try MealTemplateCommands.plan(
                    sourceName: "Meal",
                    snapshots: [snapshot],
                    destinationDate: utcDate(2026, 7, 22),
                    destinationMeal: .lunch,
                    calendar: utcCalendar()
                )
            }
        }
        #expect(throws: MealTemplateCommands.CommandError.emptySelection) {
            try MealTemplateCommands.plan(
                sourceName: "Meal",
                snapshots: [],
                destinationDate: utcDate(2026, 7, 22),
                destinationMeal: .lunch,
                calendar: utcCalendar()
            )
        }
    }

    @Test("A plan lands on the start of the destination day and in a valid snack slot")
    func planNormalisesDestination() throws {
        let snapshot = FoodLogEntrySnapshot(foodItem: makeTestFoodItem(name: "Apple"), portionGrams: 150)

        let snackPlan = try MealTemplateCommands.plan(
            sourceName: "Snack",
            snapshots: [snapshot],
            destinationDate: utcDate(2026, 7, 22, 23, 45),
            destinationMeal: .snack,
            destinationSnackIndex: 0,
            calendar: utcCalendar()
        )
        let lunchPlan = try MealTemplateCommands.plan(
            sourceName: "Lunch",
            snapshots: [snapshot],
            destinationDate: utcDate(2026, 7, 22, 0, 5),
            destinationMeal: .lunch,
            destinationSnackIndex: 3,
            calendar: utcCalendar()
        )

        #expect(snackPlan.destinationDate == utcDate(2026, 7, 22, 0))
        #expect(snackPlan.destinationSnackIndex == 1)
        #expect(lunchPlan.destinationDate == utcDate(2026, 7, 22, 0))
        #expect(lunchPlan.destinationSnackIndex == 0)
        #expect(snackPlan.items.map(\.snapshot) == [snapshot])
    }

    @Test("Logging a saved meal adds each component's recorded portion, so the day gains the meal's total")
    func loggingTemplateAddsItsTotal() throws {
        let container = try makeMealContainer()
        let context = ModelContext(container)
        let oats = makeTestFoodItem(name: "Oats", caloriesPer100g: 389, proteinPer100g: 17, carbsPer100g: 66, fatPer100g: 7)
        let milk = makeTestFoodItem(name: "Milk", caloriesPer100g: 64, proteinPer100g: 3.4, carbsPer100g: 4.8, fatPer100g: 3.6)
        [oats, milk].forEach(context.insert)
        let entries = [
            makeTestEntry(mealType: .breakfast, foodItem: oats, portionGrams: 80),
            makeTestEntry(mealType: .breakfast, foodItem: milk, portionGrams: 200),
        ]
        entries.forEach(context.insert)
        try context.save()

        let template = try MealTemplateCommands.createTemplate(
            name: "Porridge",
            entries: entries,
            defaultMeal: .breakfast,
            modelContext: context,
            now: utcDate(2026, 7, 20, 8)
        )
        let plan = try MealTemplateCommands.plan(
            sourceName: template.name,
            snapshots: try MealTemplateCommands.snapshots(for: template),
            destinationDate: utcDate(2026, 7, 22, 9),
            destinationMeal: .snack,
            destinationSnackIndex: 2,
            calendar: utcCalendar()
        )
        let logged = try MealTemplateCommands.log(
            plan: plan,
            availableFoods: [oats, milk],
            modelContext: context,
            now: utcDate(2026, 7, 22, 9)
        )

        #expect(logged.map(\.foodName) == ["Oats", "Milk"])
        #expect(logged.map(\.portionGrams) == [80, 200])
        #expect(logged.allSatisfy { $0.mealType == .snack && $0.snackIndex == 2 })
        #expect(abs(logged.reduce(0) { $0 + $1.calories } - 439.2) < 1e-9)
        #expect(abs(logged.reduce(0) { $0 + $1.proteinG } - 20.4) < 1e-9)
        #expect(abs(logged.reduce(0) { $0 + $1.carbsG } - 62.4) < 1e-9)
        #expect(abs(logged.reduce(0) { $0 + $1.fatG } - 12.8) < 1e-9)
        let verify = ModelContext(container)
        #expect(try verify.fetchCount(FetchDescriptor<FoodLogEntry>()) == 4)
    }

    @Test("A logged meal links an item to its stored food only when the caller offered that food")
    func loggingTemplateLinksOnlyOfferedFoods() throws {
        let container = try makeMealContainer()
        let context = ModelContext(container)
        let oats = makeTestFoodItem(name: "Oats", caloriesPer100g: 389)
        let milk = makeTestFoodItem(name: "Milk", caloriesPer100g: 64)
        let honey = makeTestFoodItem(name: "Honey", caloriesPer100g: 304)
        [oats, milk, honey].forEach(context.insert)
        try context.save()
        let plan = try MealTemplateCommands.plan(
            sourceName: "Porridge",
            snapshots: [
                FoodLogEntrySnapshot(foodItem: oats, portionGrams: 80),
                FoodLogEntrySnapshot(foodItem: milk, portionGrams: 200),
                FoodLogEntrySnapshot(foodItem: oats, portionGrams: 40),
                FoodLogEntrySnapshot(foodItem: honey, portionGrams: 10),
            ],
            destinationDate: utcDate(2026, 7, 22, 9),
            destinationMeal: .breakfast,
            calendar: utcCalendar()
        )

        let logged = try MealTemplateCommands.log(
            plan: plan,
            availableFoods: [honey, oats],
            modelContext: context,
            now: utcDate(2026, 7, 22, 9)
        )

        #expect(logged.map(\.foodName) == ["Oats", "Milk", "Oats", "Honey"])
        #expect(logged.map { $0.foodItem?.id } == [oats.id, nil, oats.id, honey.id])
        let stored = try ModelContext(container).fetch(
            FetchDescriptor<FoodLogEntry>(sortBy: [SortDescriptor(\.replicationItemIndex)])
        )
        #expect(stored.map { $0.foodItem?.id } == [oats.id, nil, oats.id, honey.id])
    }

    @Test("Only snapshots whose source food is gone or never recorded count as missing")
    func missingSourceCount() {
        let kept = makeTestFoodItem(name: "Kept")
        let gone = makeTestFoodItem(name: "Gone")
        var sourceless = FoodLogEntrySnapshot(foodItem: kept, portionGrams: 10)
        sourceless.sourceFoodID = nil
        let snapshots = [
            FoodLogEntrySnapshot(foodItem: kept, portionGrams: 10),
            FoodLogEntrySnapshot(foodItem: gone, portionGrams: 10),
            sourceless,
        ]

        #expect(MealTemplateCommands.missingSourceCount(in: snapshots, availableFoods: [kept]) == 2)
        #expect(MealTemplateCommands.missingSourceCount(in: snapshots, availableFoods: [kept, gone]) == 1)
    }

    @Test("Deleting a meal that is no longer stored is reported as incomplete")
    func deletingUnstoredTemplateFails() throws {
        let context = ModelContext(try makeMealContainer())
        let template = MealTemplate(
            name: "Never saved",
            defaultMeal: .dinner,
            defaultSnackIndex: 0,
            creationOperationID: UUID(),
            creationFingerprint: ""
        )

        #expect(throws: MealTemplateCommands.CommandError.incompleteTemplate) {
            try MealTemplateCommands.delete(template, modelContext: context)
        }
    }
}
