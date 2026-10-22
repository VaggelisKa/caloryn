import AppIntents
import Foundation
import SwiftData
import Testing
@testable import Caloryn

nonisolated private let deviceDayCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone.current
    return calendar
}()

nonisolated private let englishLocale = Locale(identifier: "en_US")

nonisolated private func localDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
    deviceDayCalendar.date(
        from: DateComponents(year: year, month: month, day: day, hour: hour)
    )!
}

@MainActor
private func makeIntentContainer() throws -> ModelContainer {
    try ModelContainer(
        for: UserProfile.self,
        FoodItem.self,
        FoodLogEntry.self,
        RecipeIngredient.self,
        DailyGoalSnapshot.self,
        MealTemplate.self,
        MealTemplateItem.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
}

@MainActor
private func makeManualProfile(target: Int = 1_700) -> UserProfile {
    UserProfile(
        age: 30,
        sex: .male,
        heightCm: 180,
        weightKg: 75,
        activityLevel: .moderatelyActive,
        dailyCalorieTarget: target,
        manualOverride: true,
        calorieDeficit: 0
    )
}

@MainActor
@discardableResult
private func insertFavoriteFood(
    name: String,
    brand: String? = nil,
    caloriesPer100g: Double = 100,
    portion: Double,
    favoritedAt: Date,
    logDate: Date = localDate(2026, 7, 20),
    in context: ModelContext
) throws -> FoodItem {
    let food = makeTestFoodItem(
        name: name,
        brand: brand,
        caloriesPer100g: caloriesPer100g,
        isCustom: true
    )
    food.setFavorite(true, at: favoritedAt)
    context.insert(food)
    context.insert(makeTestEntry(date: logDate, foodItem: food, portionGrams: portion))
    try context.save()
    return food
}

private func makeTemporarySnapshotStore() -> (WidgetSnapshotStore, URL) {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("IntentDomainCoverage-\(UUID().uuidString)", isDirectory: true)
    return (WidgetSnapshotStore(directoryURL: directory), directory)
}

private func readySnapshot(
    consumed: Double,
    target: Int,
    state: DailyWidgetState = .ready,
    on date: Date
) -> DailyWidgetSnapshot {
    DailyWidgetSnapshot(
        generatedAt: date,
        dayStart: deviceDayCalendar.startOfDay(for: date),
        state: state,
        calories: WidgetCalorieSummary(
            consumed: consumed,
            target: target
        )
    )
}

private func mealSummary(_ snapshot: DailyWidgetSnapshot?) -> [String] {
    snapshot?.calories.meals.map { "\($0.meal.rawValue)=\($0.kcal)" } ?? []
}

@MainActor
struct FavoriteIntentCatalogCoverageTests {
    @Test("A candidate's subtitle names its kind and last logged portion")
    func candidateSubtitle() throws {
        let context = ModelContext(try makeIntentContainer())
        let food = try insertFavoriteFood(
            name: "Oats",
            portion: 120,
            favoritedAt: localDate(2026, 7, 1),
            in: context
        )

        let candidate = try #require(FavoriteIntentCatalog.candidates(from: [food]).first)

        #expect(candidate.displayTitle == "Oats")
        #expect(candidate.kind == .manualFood)
        #expect(candidate.portionGrams == 120)
    }

    @Test("A favourite recipe with ingredients is a Recipe candidate")
    func recipeCandidate() {
        let recipe = makeTestFoodItem(
            name: "Chili",
            defaultServingG: 300,
            isRecipe: true
        )
        recipe.setFavorite(true, at: localDate(2026, 7, 1))
        recipe.recipeIngredients = [
            RecipeIngredient(
                from: makeTestFoodItem(name: "Beans"),
                portionGrams: 300,
                sortOrder: 0
            )
        ]
        recipe.logEntries = [
            makeTestEntry(date: localDate(2026, 7, 2), foodItem: recipe, portionGrams: 250)
        ]

        let candidates = FavoriteIntentCatalog.candidates(from: [recipe])

        #expect(candidates.map(\.kind) == [.recipe])
        #expect(candidates.first?.displayTitle == "Chili")
    }

    @Test("Identical duplicates are told apart by brand")
    func duplicatesDisambiguatedByBrand() throws {
        let context = ModelContext(try makeIntentContainer())
        let morning = try insertFavoriteFood(
            name: "Protein bowl",
            brand: "Morning",
            portion: 350,
            favoritedAt: localDate(2026, 7, 20, 9),
            in: context
        )
        let evening = try insertFavoriteFood(
            name: "Protein bowl",
            brand: "  Evening  ",
            portion: 350,
            favoritedAt: localDate(2026, 7, 20, 8),
            in: context
        )

        let candidates = FavoriteIntentCatalog.candidates(from: [evening, morning])

        #expect(candidates.map(\.displayTitle) == [
            "Protein bowl — Manual food, last logged 350 g, Morning",
            "Protein bowl — Manual food, last logged 350 g, Evening",
        ])
    }

    @Test("Identical duplicates without a usable brand fall back to an ID prefix")
    func duplicatesWithoutBrandUseIDPrefix() throws {
        let context = ModelContext(try makeIntentContainer())
        let first = try insertFavoriteFood(
            name: "Shake",
            portion: 300,
            favoritedAt: localDate(2026, 7, 20, 9),
            in: context
        )
        let second = try insertFavoriteFood(
            name: "Shake",
            brand: "   ",
            portion: 300,
            favoritedAt: localDate(2026, 7, 20, 8),
            in: context
        )

        let candidates = FavoriteIntentCatalog.candidates(from: [first, second])

        #expect(candidates.map(\.displayTitle) == [
            "Shake — Manual food, last logged 300 g, ID \(first.id.uuidString.prefix(4))",
            "Shake — Manual food, last logged 300 g, ID \(second.id.uuidString.prefix(4))",
        ])
    }

    @Test("Names that differ only by case or accents count as duplicates")
    func duplicateDetectionFoldsCaseAndDiacritics() throws {
        let context = ModelContext(try makeIntentContainer())
        let accented = try insertFavoriteFood(
            name: "Café latte",
            portion: 250,
            favoritedAt: localDate(2026, 7, 20, 9),
            in: context
        )
        let plain = try insertFavoriteFood(
            name: "cafe LATTE",
            portion: 300,
            favoritedAt: localDate(2026, 7, 20, 8),
            in: context
        )
        let unrelated = try insertFavoriteFood(
            name: "Tea",
            portion: 200,
            favoritedAt: localDate(2026, 7, 20, 7),
            in: context
        )

        let candidates = FavoriteIntentCatalog.candidates(from: [unrelated, plain, accented])

        #expect(candidates.map(\.displayTitle) == [
            "Café latte — Manual food, last logged 250 g",
            "cafe LATTE — Manual food, last logged 300 g",
            "Tea",
        ])
    }

    @Test("Favourites pinned at the same moment sort by name, then by ID")
    func sortTieBreaks() throws {
        let context = ModelContext(try makeIntentContainer())
        let pinnedAt = localDate(2026, 7, 20, 9)
        let banana = try insertFavoriteFood(name: "banana", portion: 100, favoritedAt: pinnedAt, in: context)
        let apple = try insertFavoriteFood(name: "Apple", portion: 100, favoritedAt: pinnedAt, in: context)
        let twinA = try insertFavoriteFood(name: "Cherry", portion: 100, favoritedAt: pinnedAt, in: context)
        let twinB = try insertFavoriteFood(name: "Cherry", portion: 120, favoritedAt: pinnedAt, in: context)
        let newer = try insertFavoriteFood(
            name: "Zucchini",
            portion: 100,
            favoritedAt: localDate(2026, 7, 21),
            in: context
        )

        let candidates = FavoriteIntentCatalog.candidates(
            from: [twinB, banana, newer, twinA, apple]
        )
        let cherries = [twinA, twinB]
            .map(\.id.uuidString)
            .sorted()

        #expect(candidates.map(\.id) == [
            newer.id.uuidString,
            apple.id.uuidString,
            banana.id.uuidString,
        ] + cherries)
    }

    @Test("Favourites with no pin date sort after every dated one")
    func undatedFavoritesSortLast() throws {
        let context = ModelContext(try makeIntentContainer())
        let undated = try insertFavoriteFood(name: "Apple", portion: 100, favoritedAt: localDate(2026, 7, 1), in: context)
        undated.pinnedAt = nil
        let dated = try insertFavoriteFood(name: "Zucchini", portion: 100, favoritedAt: localDate(2000, 1, 1), in: context)

        let candidates = FavoriteIntentCatalog.candidates(from: [undated, dated])

        #expect(candidates.map(\.name) == ["Zucchini", "Apple"])
        #expect(candidates.map(\.favoritedAt) == [localDate(2000, 1, 1), nil])
    }

    @Test("Portions keep up to two decimals and are never grouped", arguments: [
        (12.5, "12{sep}5"),
        (87.25, "87{sep}25"),
        (1_234.5, "1234{sep}5"),
        (200.0, "200"),
    ])
    func portionFormatting(portion: Double, template: String) {
        let separator = Locale.current.decimalSeparator ?? "."
        let grams = template.replacingOccurrences(of: "{sep}", with: separator)
        let result = FavoriteIntentLogResult(foodName: "Oats", portionGrams: portion, meal: .breakfast, calories: 50)

        #expect(result.response == "Logged \(grams) g of Oats to breakfast — 50 calories.")
    }

    @Test("A blank or whitespace search matches every candidate", arguments: ["", "   ", "\n\t"])
    func blankSearchMatchesAll(search: String) {
        let candidate = FavoriteIntentCandidate(
            id: "A",
            name: "Oats",
            brand: nil,
            kind: .manualFood,
            portionGrams: 50,
            favoritedAt: nil,
            displayTitle: "Oats"
        )

        #expect(FavoriteIntentCatalog.matches(candidate, search: search))
    }

    @Test("Search spans name, brand, kind and display title, ignoring case and accents", arguments: [
        ("crème", true),
        ("CREME", true),
        ("  brulee  ", true),
        ("patisserie", true),
        ("recipe", true),
        ("ID 1a2b", true),
        ("manual", false),
        ("custard", false),
    ])
    func searchMatching(search: String, expected: Bool) {
        let candidate = FavoriteIntentCandidate(
            id: "1A2B3C",
            name: "Crème brûlée",
            brand: "Pâtisserie",
            kind: .recipe,
            portionGrams: 120,
            favoritedAt: nil,
            displayTitle: "Crème brûlée, ID 1A2B"
        )

        #expect(FavoriteIntentCatalog.matches(candidate, search: search) == expected)
    }
}

@MainActor
struct FavoriteIntentLoggingCoverageTests {
    @Test("Errors explain what the user has to do", arguments: [
        (FavoriteIntentLogging.Error.unauthenticated, "Open Caloryn and finish setup before logging a favorite."),
        (FavoriteIntentLogging.Error.unavailable, "That favorite is no longer available for quick logging. Open Caloryn to log it manually."),
    ])
    func errorDescriptions(error: FavoriteIntentLogging.Error, message: String) {
        #expect(error.errorDescription == message)
        #expect(error.localizedDescription == message)
    }

    @Test("An identifier that is not a UUID is unavailable and logs nothing", arguments: [
        "", "not-a-uuid", "1234", "  ",
    ])
    func malformedIdentifierIsUnavailable(identifier: String) throws {
        let context = ModelContext(try makeIntentContainer())
        context.insert(makeManualProfile())
        try insertFavoriteFood(name: "Oats", portion: 50, favoritedAt: localDate(2026, 7, 1), in: context)

        #expect(throws: FavoriteIntentLogging.Error.unavailable) {
            try FavoriteIntentLogging.log(
                favoriteID: identifier,
                meal: .lunch,
                in: context,
                now: localDate(2026, 7, 25),
                calendar: deviceDayCalendar
            )
        }
        #expect(try context.fetchCount(FetchDescriptor<FoodLogEntry>()) == 1)
    }

    @Test("A well-formed but unknown UUID is unavailable")
    func unknownIdentifierIsUnavailable() throws {
        let context = ModelContext(try makeIntentContainer())
        context.insert(makeManualProfile())
        try context.save()

        #expect(throws: FavoriteIntentLogging.Error.unavailable) {
            try FavoriteIntentLogging.log(
                favoriteID: UUID().uuidString,
                meal: .snack,
                in: context,
                now: localDate(2026, 7, 25),
                calendar: deviceDayCalendar
            )
        }
    }

    @Test("Logging writes one entry at the start of today in the chosen meal")
    func loggingWritesEntryAtStartOfDay() throws {
        let context = ModelContext(try makeIntentContainer())
        context.insert(makeManualProfile())
        let food = try insertFavoriteFood(
            name: "Granola",
            caloriesPer100g: 450,
            portion: 85,
            favoritedAt: localDate(2026, 7, 1),
            in: context
        )
        let now = localDate(2026, 7, 25, 23)

        let result = try FavoriteIntentLogging.log(
            favoriteID: food.id.uuidString,
            meal: .dinner,
            in: context,
            now: now,
            calendar: deviceDayCalendar
        )

        #expect(result.foodName == "Granola")
        #expect(result.portionGrams == 85)
        #expect(result.meal == .dinner)
        #expect(abs(result.calories - 382.5) < 0.0001)
        let today = try context.fetch(FetchDescriptor<FoodLogEntry>())
            .filter { $0.date == deviceDayCalendar.startOfDay(for: now) }
        #expect(today.count == 1)
        #expect(today.first?.mealType == .dinner)
        #expect(today.first?.portionGrams == 85)
    }

    @Test("The spoken response rounds calories half away from zero", arguments: [
        (FavoriteIntentLogResult(foodName: "Granola", portionGrams: 85, meal: .dinner, calories: 382.5),
         "Logged 85 g of Granola to dinner — 383 calories."),
        (FavoriteIntentLogResult(foodName: "Rice", portionGrams: 250, meal: .lunch, calories: 324.49),
         "Logged 250 g of Rice to lunch — 324 calories."),
        (FavoriteIntentLogResult(foodName: "Nuts", portionGrams: 12, meal: .snack, calories: 0.4),
         "Logged 12 g of Nuts to snack — 0 calories."),
    ])
    func logResultResponse(result: FavoriteIntentLogResult, expected: String) {
        #expect(result.response == expected)
    }

    @Test("Intent meals map onto the app's meal types", arguments: [
        (CalorynIntentMeal.breakfast, MealType.breakfast),
        (CalorynIntentMeal.lunch, MealType.lunch),
        (CalorynIntentMeal.dinner, MealType.dinner),
        (CalorynIntentMeal.snack, MealType.snack),
    ])
    func intentMealMapping(intentMeal: CalorynIntentMeal, mealType: MealType) throws {
        #expect(intentMeal.mealType == mealType)
        let representation = try #require(CalorynIntentMeal.caseDisplayRepresentations[intentMeal])
        #expect(String(localized: representation.title) == mealType.displayName)
    }

    @Test("A favourite entity shows its title and last logged portion")
    func favoriteEntityRepresentation() {
        let candidate = FavoriteIntentCandidate(
            id: "ABCD-1",
            name: "Chili",
            brand: "Home",
            kind: .recipe,
            portionGrams: 275,
            favoritedAt: nil,
            displayTitle: "Chili, Home"
        )

        let entity = FavoriteFoodEntity(candidate: candidate)

        #expect(entity.id == "ABCD-1")
        #expect(entity.name == "Chili")
        #expect(entity.kind == "Recipe")
        #expect(entity.portionGrams == 275)
        #expect(entity.displayTitle == "Chili, Home")
        #expect(String(localized: entity.displayRepresentation.title) == "Chili, Home")
        #expect(
            entity.displayRepresentation.subtitle.map { String(localized: $0) }
                == "Recipe, last logged 275 g"
        )
    }
}

@MainActor
struct TodayCaloriesResponseCoverageTests {
    @Test("Responses clamp, compare and group against the target", arguments: [
        (0, 2_000, "0 of 2,000 calories logged today. 2,000 remaining."),
        (-50, 2_000, "0 of 2,000 calories logged today. 2,000 remaining."),
        (2_000, 2_000, "2,000 of 2,000 calories logged today. 0 remaining."),
        (2_001, 2_000, "2,001 of 2,000 calories logged today. 1 over target."),
        (12_345, 1_000, "12,345 of 1,000 calories logged today. 11,345 over target."),
    ])
    func responseText(consumed: Int, target: Int, expected: String) {
        #expect(
            TodayCaloriesIntentResponse.make(consumed: consumed, target: target, locale: englishLocale)
                == .available(expected)
        )
    }

    @Test("A zero or negative target reports only what was logged", arguments: [0, -1])
    func nonPositiveTargetOmitsComparison(target: Int) {
        #expect(
            TodayCaloriesIntentResponse.make(consumed: 1_500, target: target, locale: englishLocale)
                == .available("1,500 calories logged today.")
        )
    }

    @Test("Formatting follows the injected locale")
    func localeFormatting() {
        #expect(
            TodayCaloriesIntentResponse.make(
                consumed: 1_200,
                target: 2_500,
                locale: Locale(identifier: "de_DE")
            ) == .available("1.200 of 2.500 calories logged today. 1.300 remaining.")
        )
    }

    @Test("A matching same-day snapshot is reported; a mismatched one is not", arguments: [
        (1_200.4, 1_700, true),
        (1_200.6, 1_700, false),
        (1_200.0, 1_800, false),
    ])
    func snapshotMustMatchLocalState(
        currentConsumed: Double,
        expectedTarget: Int,
        expectedAvailable: Bool
    ) {
        let now = localDate(2026, 7, 25, 18)
        let snapshot = readySnapshot(consumed: 1_200, target: 1_700, on: now)

        let response = TodayCaloriesIntentResponse.make(
            snapshot: snapshot,
            currentConsumed: currentConsumed,
            expectedTarget: expectedTarget,
            now: now,
            calendar: deviceDayCalendar,
            locale: englishLocale
        )

        #expect(response == (expectedAvailable
            ? .available("1,200 of 1,700 calories logged today. 500 remaining.")
            : .unavailable("Open Caloryn to refresh today’s calorie snapshot.")))
    }

    @Test("A snapshot that is not ready is never reported", arguments: [
        DailyWidgetState.needsOnboarding, .unavailable,
    ])
    func nonReadySnapshotIsUnavailable(state: DailyWidgetState) {
        let now = localDate(2026, 7, 25)
        let snapshot = readySnapshot(consumed: 0, target: 1_700, state: state, on: now)

        #expect(
            TodayCaloriesIntentResponse.make(
                snapshot: snapshot,
                currentConsumed: 0,
                expectedTarget: 1_700,
                now: now,
                calendar: deviceDayCalendar,
                locale: englishLocale
            ) == .unavailable("Open Caloryn to refresh today’s calorie snapshot.")
        )
    }

    @Test("Expected targets below one are compared as one, like the snapshot stores them")
    func expectedTargetsFloorAtOne() {
        let now = localDate(2026, 7, 25)
        let snapshot = readySnapshot(consumed: 10, target: 0, on: now)

        #expect(
            TodayCaloriesIntentResponse.make(
                snapshot: snapshot,
                currentConsumed: 10,
                expectedTarget: 0,
                now: now,
                calendar: deviceDayCalendar,
                locale: englishLocale
            ) == .available("10 of 1 calories logged today. 9 over target.")
        )
    }
}

@MainActor
struct CalorynIntentDataStoreCoverageTests {
    @Test("Without a profile, no favourites are offered to Shortcuts")
    func candidatesRequireProfile() throws {
        let container = try makeIntentContainer()
        try insertFavoriteFood(name: "Oats", portion: 50, favoritedAt: localDate(2026, 7, 1), in: container.mainContext)
        let (snapshotStore, directory) = makeTemporarySnapshotStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = CalorynIntentDataStore(modelContainer: container, widgetSnapshotStore: snapshotStore)

        #expect(try store.favoriteCandidates().isEmpty)
    }

    @Test("With a profile, eligible favourites are offered newest first")
    func candidatesWithProfile() throws {
        let container = try makeIntentContainer()
        let context = container.mainContext
        context.insert(makeManualProfile())
        let older = try insertFavoriteFood(name: "Oats", portion: 50, favoritedAt: localDate(2026, 7, 1), in: context)
        let newer = try insertFavoriteFood(name: "Yogurt", portion: 150, favoritedAt: localDate(2026, 7, 2), in: context)
        let notFavorite = makeTestFoodItem(name: "Plain", isCustom: true)
        context.insert(notFavorite)
        context.insert(makeTestEntry(date: localDate(2026, 7, 3), foodItem: notFavorite, portionGrams: 80))
        try context.save()
        let (snapshotStore, directory) = makeTemporarySnapshotStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = CalorynIntentDataStore(modelContainer: container, widgetSnapshotStore: snapshotStore)
        let candidates = try store.favoriteCandidates()

        #expect(candidates.map(\.id) == [newer.id.uuidString, older.id.uuidString])
        #expect(candidates.map(\.portionGrams) == [150, 50])
    }

    @Test("A pinned catalog or edited product is never offered, however recently it was pinned")
    func candidatesSkipPinnedProducts() throws {
        let container = try makeIntentContainer()
        let context = container.mainContext
        context.insert(makeManualProfile())
        let favorite = try insertFavoriteFood(name: "Oats", portion: 50, favoritedAt: localDate(2026, 7, 1), in: context)
        let catalogProduct = makeTestFoodItem(name: "Provider Skyr")
        catalogProduct.isPinnedRaw = true
        catalogProduct.pinnedAt = localDate(2026, 7, 3)
        let editedProduct = makeTestFoodItem(name: "Edited Skyr", isCustom: true)
        editedProduct.providerProductIdentityRaw = "5711953150388"
        editedProduct.setFavorite(true, at: localDate(2026, 7, 4))
        for product in [catalogProduct, editedProduct] {
            context.insert(product)
            context.insert(makeTestEntry(date: localDate(2026, 7, 20), foodItem: product, portionGrams: 150))
        }
        try context.save()
        let (snapshotStore, directory) = makeTemporarySnapshotStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = CalorynIntentDataStore(modelContainer: container, widgetSnapshotStore: snapshotStore)

        #expect(try store.favoriteCandidates().map(\.id) == [favorite.id.uuidString])
    }

    @Test("Logging with no snapshot on disk projects a fresh one from the profile")
    func logFavoriteProjectsFreshSnapshot() throws {
        let container = try makeIntentContainer()
        let context = container.mainContext
        context.insert(makeManualProfile(target: 1_700))
        let favorite = try insertFavoriteFood(name: "Yogurt", portion: 350, favoritedAt: localDate(2026, 7, 1), in: context)
        let other = makeTestFoodItem(name: "Soup", caloriesPer100g: 50)
        context.insert(other)
        let now = localDate(2026, 7, 25, 15)
        context.insert(makeTestEntry(date: localDate(2026, 7, 25, 0), mealType: .dinner, foodItem: other, portionGrams: 400))
        context.insert(makeTestEntry(date: localDate(2026, 7, 24), mealType: .lunch, foodItem: other, portionGrams: 1_000))
        try context.save()
        let (snapshotStore, directory) = makeTemporarySnapshotStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CalorynIntentDataStore(modelContainer: container, widgetSnapshotStore: snapshotStore)

        let result = try store.logFavorite(id: favorite.id.uuidString, meal: .lunch, now: now, calendar: deviceDayCalendar)

        #expect(result.response == "Logged 350 g of Yogurt to lunch — 350 calories.")
        let snapshot = try #require(try snapshotStore.load())
        #expect(snapshot.state == .ready)
        #expect(snapshot.generatedAt == now)
        #expect(snapshot.dayStart == deviceDayCalendar.startOfDay(for: now))
        #expect(snapshot.calories.consumed == 550)
        #expect(snapshot.calories.target == 1_700)
        #expect(mealSummary(snapshot) == ["lunch=350", "dinner=200"])
    }

    @Test("Logging onto today's ready snapshot keeps its targets and updates what was eaten")
    func logFavoriteKeepsSameDayTargets() throws {
        let container = try makeIntentContainer()
        let context = container.mainContext
        context.insert(makeManualProfile(target: 1_700))
        let favorite = try insertFavoriteFood(name: "Yogurt", portion: 200, favoritedAt: localDate(2026, 7, 1), in: context)
        try context.save()
        let now = localDate(2026, 7, 25, 15)
        let (snapshotStore, directory) = makeTemporarySnapshotStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        try snapshotStore.save(readySnapshot(
            consumed: 0,
            target: 2_350,
            on: localDate(2026, 7, 25, 8)
        ))
        let store = CalorynIntentDataStore(modelContainer: container, widgetSnapshotStore: snapshotStore)

        _ = try store.logFavorite(id: favorite.id.uuidString, meal: .breakfast, now: now, calendar: deviceDayCalendar)

        let snapshot = try #require(try snapshotStore.load())
        #expect(snapshot.generatedAt == now)
        #expect(snapshot.calories.consumed == 200)
        #expect(snapshot.calories.target == 2_350)
        #expect(mealSummary(snapshot) == ["breakfast=200"])
    }

    @Test("A previous snapshot that is stale or not ready is replaced by a fresh projection", arguments: [
        (localDate(2026, 7, 24, 20), DailyWidgetState.ready),
        (localDate(2026, 7, 25, 8), DailyWidgetState.needsOnboarding),
        (localDate(2026, 7, 25, 8), DailyWidgetState.unavailable),
    ])
    func logFavoriteReprojectsStaleSnapshot(previousDate: Date, previousState: DailyWidgetState) throws {
        let container = try makeIntentContainer()
        let context = container.mainContext
        context.insert(makeManualProfile(target: 1_900))
        let favorite = try insertFavoriteFood(name: "Yogurt", portion: 120, favoritedAt: localDate(2026, 7, 1), in: context)
        try context.save()
        let now = localDate(2026, 7, 25, 15)
        let (snapshotStore, directory) = makeTemporarySnapshotStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        try snapshotStore.save(readySnapshot(
            consumed: 900,
            target: 2_800,
            state: previousState,
            on: previousDate
        ))
        let store = CalorynIntentDataStore(modelContainer: container, widgetSnapshotStore: snapshotStore)

        _ = try store.logFavorite(id: favorite.id.uuidString, meal: .snack, now: now, calendar: deviceDayCalendar)

        let snapshot = try #require(try snapshotStore.load())
        #expect(snapshot.state == .ready)
        #expect(snapshot.dayStart == deviceDayCalendar.startOfDay(for: now))
        #expect(snapshot.calories.consumed == 120)
        #expect(snapshot.calories.target == 1_900)
        #expect(mealSummary(snapshot) == ["snack=120"])
    }

    @Test("A fresh projection after logging uses the most recently updated profile")
    func logFavoriteProjectsFromNewestProfile() throws {
        let container = try makeIntentContainer()
        let context = container.mainContext
        let older = makeManualProfile(target: 1_500)
        older.updatedAt = localDate(2026, 7, 1)
        let newer = makeManualProfile(target: 2_300)
        newer.updatedAt = localDate(2026, 7, 20)
        context.insert(older)
        context.insert(newer)
        let favorite = try insertFavoriteFood(name: "Yogurt", portion: 150, favoritedAt: localDate(2026, 7, 1), in: context)
        let (snapshotStore, directory) = makeTemporarySnapshotStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CalorynIntentDataStore(modelContainer: container, widgetSnapshotStore: snapshotStore)

        _ = try store.logFavorite(id: favorite.id.uuidString, meal: .lunch, now: localDate(2026, 7, 25, 15), calendar: deviceDayCalendar)

        let snapshot = try #require(try snapshotStore.load())
        #expect(snapshot.calories.target == 2_300)
        #expect(snapshot.calories.consumed == 150)
    }

    @Test("Logging counts entries from today's midnight up to, not including, tomorrow's", arguments: [false, true])
    func logFavoriteCountsOnlyTodaysEntries(hasSameDaySnapshot: Bool) throws {
        let container = try makeIntentContainer()
        let context = container.mainContext
        context.insert(makeManualProfile(target: 1_700))
        let favorite = try insertFavoriteFood(name: "Yogurt", portion: 100, favoritedAt: localDate(2026, 7, 1), in: context)
        let soup = makeTestFoodItem(name: "Soup", caloriesPer100g: 100)
        context.insert(soup)
        let todayStart = localDate(2026, 7, 25, 0)
        let tomorrowStart = localDate(2026, 7, 26, 0)
        let boundaryEntries: [(Date, MealType, Double)] = [
            (todayStart, .breakfast, 300),
            (todayStart.addingTimeInterval(-1), .lunch, 900),
            (tomorrowStart, .dinner, 500),
        ]
        for (date, meal, grams) in boundaryEntries {
            let entry = makeTestEntry(mealType: meal, foodItem: soup, portionGrams: grams)
            entry.date = date
            context.insert(entry)
        }
        try context.save()
        let (snapshotStore, directory) = makeTemporarySnapshotStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        if hasSameDaySnapshot {
            try snapshotStore.save(readySnapshot(consumed: 0, target: 1_700, on: localDate(2026, 7, 25, 8)))
        }
        let store = CalorynIntentDataStore(modelContainer: container, widgetSnapshotStore: snapshotStore)

        _ = try store.logFavorite(id: favorite.id.uuidString, meal: .snack, now: localDate(2026, 7, 25, 15), calendar: deviceDayCalendar)

        let snapshot = try #require(try snapshotStore.load())
        #expect(snapshot.calories.consumed == 400)
        #expect(mealSummary(snapshot) == ["breakfast=300", "snack=100"])
    }

    @Test("A refused log neither writes an entry nor touches the widget snapshot")
    func refusedLogLeavesSnapshotAlone() throws {
        let container = try makeIntentContainer()
        let context = container.mainContext
        let favorite = try insertFavoriteFood(name: "Yogurt", portion: 120, favoritedAt: localDate(2026, 7, 1), in: context)
        let (snapshotStore, directory) = makeTemporarySnapshotStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CalorynIntentDataStore(modelContainer: container, widgetSnapshotStore: snapshotStore)

        #expect(throws: FavoriteIntentLogging.Error.unauthenticated) {
            try store.logFavorite(id: favorite.id.uuidString, meal: .snack, now: localDate(2026, 7, 25), calendar: deviceDayCalendar)
        }
        #expect(try snapshotStore.load() == nil)
        #expect(try context.fetchCount(FetchDescriptor<FoodLogEntry>()) == 1)
    }

    @Test("Checking calories with no snapshot on disk asks the user to open the app")
    func todayCaloriesWithoutSnapshot() async throws {
        let container = try makeIntentContainer()
        container.mainContext.insert(makeManualProfile())
        try container.mainContext.save()
        let (snapshotStore, directory) = makeTemporarySnapshotStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CalorynIntentDataStore(modelContainer: container, widgetSnapshotStore: snapshotStore)

        let response = try await store.todayCaloriesResponse(
            now: localDate(2026, 7, 25),
            calendar: deviceDayCalendar,
            locale: englishLocale
        )

        #expect(response == .unavailable("Open Caloryn to refresh today’s calorie snapshot."))
    }

    @Test("Checking calories rejects a snapshot that is not ready or not from today", arguments: [
        (localDate(2026, 7, 25, 6), DailyWidgetState.unavailable),
        (localDate(2026, 7, 25, 6), DailyWidgetState.needsOnboarding),
        (localDate(2026, 7, 24, 23), DailyWidgetState.ready),
    ])
    func todayCaloriesRejectsUnusableSnapshot(snapshotDate: Date, state: DailyWidgetState) async throws {
        let container = try makeIntentContainer()
        container.mainContext.insert(makeManualProfile())
        try container.mainContext.save()
        let (snapshotStore, directory) = makeTemporarySnapshotStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        try snapshotStore.save(readySnapshot(consumed: 0, target: 1_700, state: state, on: snapshotDate))
        let store = CalorynIntentDataStore(modelContainer: container, widgetSnapshotStore: snapshotStore)

        let response = try await store.todayCaloriesResponse(
            now: localDate(2026, 7, 25, 12),
            calendar: deviceDayCalendar,
            locale: englishLocale
        )

        #expect(response == .unavailable("Open Caloryn to refresh today’s calorie snapshot."))
    }

    @Test("Checking calories counts only today's entries in the injected calendar")
    func todayCaloriesCountsOnlyToday() async throws {
        let container = try makeIntentContainer()
        let context = container.mainContext
        context.insert(makeManualProfile())
        let food = makeTestFoodItem(name: "Bread", caloriesPer100g: 100)
        context.insert(food)
        context.insert(makeTestEntry(date: localDate(2026, 7, 25, 0), foodItem: food, portionGrams: 300))
        context.insert(makeTestEntry(date: localDate(2026, 7, 24, 23), foodItem: food, portionGrams: 900))
        context.insert(makeTestEntry(date: localDate(2026, 7, 26, 0), foodItem: food, portionGrams: 500))
        try context.save()
        let now = localDate(2026, 7, 25, 18)
        let (snapshotStore, directory) = makeTemporarySnapshotStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        try snapshotStore.save(readySnapshot(consumed: 300, target: 1_700, on: now))
        let store = CalorynIntentDataStore(modelContainer: container, widgetSnapshotStore: snapshotStore)

        let response = try await store.todayCaloriesResponse(now: now, calendar: deviceDayCalendar, locale: englishLocale)

        #expect(response == .available("300 of 1,700 calories logged today. 1,400 remaining."))
    }

    @Test("Checking calories finds today's entries on a day whose midnight a daylight-saving change skips")
    func todayCaloriesAcrossMidnightDaylightSaving() async throws {
        var santiago = Calendar(identifier: .gregorian)
        santiago.timeZone = try #require(TimeZone(identifier: "America/Santiago"))
        func santiagoDate(_ day: Int, _ hour: Int, _ minute: Int = 0, _ second: Int = 0) throws -> Date {
            try #require(santiago.date(from: DateComponents(year: 2025, month: 9, day: day, hour: hour, minute: minute, second: second)))
        }
        let container = try makeIntentContainer()
        let context = container.mainContext
        context.insert(makeManualProfile())
        let food = makeTestFoodItem(name: "Bread", caloriesPer100g: 100)
        context.insert(food)
        let boundaryEntries: [(Date, Double)] = [
            (try santiagoDate(7, 1), 300),
            (try santiagoDate(6, 23, 59, 59), 900),
            (try santiagoDate(8, 0), 500),
        ]
        for (date, grams) in boundaryEntries {
            let entry = makeTestEntry(foodItem: food, portionGrams: grams)
            entry.date = date
            context.insert(entry)
        }
        try context.save()
        let now = try santiagoDate(7, 18)
        let (snapshotStore, directory) = makeTemporarySnapshotStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        try snapshotStore.save(DailyWidgetSnapshot(
            generatedAt: now,
            dayStart: santiago.startOfDay(for: now),
            state: .ready,
            calories: WidgetCalorieSummary(consumed: 300, target: 1_700)
        ))
        let store = CalorynIntentDataStore(modelContainer: container, widgetSnapshotStore: snapshotStore)

        let response = try await store.todayCaloriesResponse(now: now, calendar: santiago, locale: englishLocale)

        #expect(response == .available("300 of 1,700 calories logged today. 1,400 remaining."))
    }

    @Test("Checking calories compares against the most recently updated profile", arguments: [
        (2_100, true),
        (1_700, false),
    ])
    func todayCaloriesUsesNewestProfile(snapshotTarget: Int, expectedAvailable: Bool) async throws {
        let container = try makeIntentContainer()
        let context = container.mainContext
        let older = makeManualProfile(target: 1_700)
        older.updatedAt = localDate(2026, 7, 1)
        let newer = makeManualProfile(target: 2_100)
        newer.updatedAt = localDate(2026, 7, 20)
        context.insert(newer)
        context.insert(older)
        try context.save()
        let now = localDate(2026, 7, 25, 18)
        let (snapshotStore, directory) = makeTemporarySnapshotStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        try snapshotStore.save(readySnapshot(consumed: 0, target: snapshotTarget, on: now))
        let store = CalorynIntentDataStore(modelContainer: container, widgetSnapshotStore: snapshotStore)

        let response = try await store.todayCaloriesResponse(now: now, calendar: deviceDayCalendar, locale: englishLocale)

        #expect(response == (expectedAvailable
            ? .available("0 of 2,100 calories logged today. 2,100 remaining.")
            : .unavailable("Open Caloryn to refresh today’s calorie snapshot.")))
    }
}
