import SwiftData
import XCTest
@testable import Caloryn

final class CalorynAppIntentsTests: XCTestCase {
    private let englishLocale = Locale(identifier: "en_US")

    func testFavoriteCandidatesRankByMostRecentlyFavoritedAndSuggestionsUseFirstFive() throws {
        let context = ModelContext(try makeContainer())
        let baseDate = makeTestDate(year: 2026, month: 7, day: 10)
        var inserted: [FoodItem] = []

        for index in 0..<6 {
            let food = try insertFavorite(
                name: "Favorite \(index)",
                portion: Double(100 + index),
                favoritedAt: baseDate.addingTimeInterval(Double(index) * 60),
                in: context
            )
            inserted.append(food)
        }

        let candidates = FavoriteIntentCatalog.candidates(
            from: try context.fetch(FetchDescriptor<FoodItem>())
        )

        XCTAssertEqual(candidates.map(\.id), inserted.reversed().map { $0.id.uuidString })
        XCTAssertEqual(
            Array(candidates.prefix(FavoriteFoodLogging.collapsedFavoriteLimit)).count,
            5
        )
    }

    func testDuplicateNamesHaveExplicitRepresentationsAndStableDistinctIDs() throws {
        let context = ModelContext(try makeContainer())
        let first = try insertFavorite(
            name: "Protein bowl",
            brand: "Morning",
            portion: 350,
            favoritedAt: makeTestDate(year: 2026, month: 7, day: 20, hour: 8),
            in: context
        )
        let second = try insertFavorite(
            name: "Protein bowl",
            brand: "Evening",
            portion: 420,
            favoritedAt: makeTestDate(year: 2026, month: 7, day: 20, hour: 9),
            in: context
        )

        let candidates = FavoriteIntentCatalog.candidates(from: [first, second])

        XCTAssertEqual(Set(candidates.map(\.id)).count, 2)
        XCTAssertTrue(
            candidates.allSatisfy {
                $0.displayTitle.contains("Manual food")
                    && $0.displayTitle.contains("last logged")
            }
        )
        XCTAssertTrue(candidates.contains { $0.displayTitle.contains("350 g") })
        XCTAssertTrue(candidates.contains { $0.displayTitle.contains("420 g") })
    }

    func testQueryMatchingSearchesNameBrandAndKindWithoutBroadeningEligibility() throws {
        let context = ModelContext(try makeContainer())
        let eligible = try insertFavorite(
            name: "Greek yogurt",
            brand: "Dairy Co",
            portion: 350,
            favoritedAt: .now,
            in: context
        )
        let unfavorited = makeTestFoodItem(
            name: "Greek yogurt copy",
            isCustom: true
        )
        context.insert(unfavorited)
        context.insert(
            makeTestEntry(
                date: .now,
                foodItem: unfavorited,
                portionGrams: 200
            )
        )
        try context.save()

        let candidates = FavoriteIntentCatalog.candidates(
            from: try context.fetch(FetchDescriptor<FoodItem>())
        )

        XCTAssertEqual(candidates.map(\.id), [eligible.id.uuidString])
        XCTAssertEqual(
            candidates.filter {
                FavoriteIntentCatalog.matches($0, search: "dairy")
            }.map(\.id),
            [eligible.id.uuidString]
        )
        XCTAssertTrue(
            candidates.allSatisfy {
                !FavoriteIntentCatalog.matches($0, search: "copy")
            }
        )
    }

    func testMostRecentReusablePortionIsOverallAndNotMealSpecific() throws {
        let context = ModelContext(try makeContainer())
        let food = makeTestFoodItem(name: "Yogurt", isCustom: true)
        food.setFavorite(true)
        context.insert(food)
        let earlierInvocation = makeTestEntry(
            date: makeTestDate(year: 2026, month: 7, day: 22),
            mealType: .breakfast,
            foodItem: food,
            portionGrams: 150
        )
        earlierInvocation.createdAt = makeTestDate(
            year: 2026,
            month: 7,
            day: 22,
            hour: 8
        )
        context.insert(earlierInvocation)

        // A later invocation may deliberately log to an older calendar day.
        // "Most recent overall" follows the literal logging time, not meal or date.
        let laterInvocation = makeTestEntry(
            date: makeTestDate(year: 2026, month: 7, day: 20),
            mealType: .dinner,
            foodItem: food,
            portionGrams: 350
        )
        laterInvocation.createdAt = makeTestDate(
            year: 2026,
            month: 7,
            day: 22,
            hour: 9
        )
        context.insert(laterInvocation)
        try context.save()

        XCTAssertEqual(
            FavoriteFoodLogging.mostRecentlyLoggedSafePortion(for: food),
            350
        )
    }

    func testUnsafeLatestPortionDoesNotFallBackToOlderPortion() throws {
        let context = ModelContext(try makeContainer())
        let food = makeTestFoodItem(name: "Unsafe", isCustom: true)
        food.setFavorite(true)
        context.insert(food)
        context.insert(
            makeTestEntry(
                date: makeTestDate(year: 2026, month: 7, day: 20),
                foodItem: food,
                portionGrams: 100
            )
        )
        context.insert(
            makeTestEntry(
                date: makeTestDate(year: 2026, month: 7, day: 21),
                foodItem: food,
                portionGrams: -5
            )
        )
        try context.save()

        XCTAssertNil(FavoriteFoodLogging.mostRecentlyLoggedSafePortion(for: food))
        XCTAssertTrue(FavoriteIntentCatalog.candidates(from: [food]).isEmpty)
    }

    func testRecipeWithoutSafeReusableShapeIsExcluded() {
        let recipe = makeTestFoodItem(
            name: "Incomplete Recipe",
            defaultServingG: 300,
            isRecipe: true
        )
        recipe.setFavorite(true)
        recipe.recipeIngredients = []
        recipe.logEntries = [
            makeTestEntry(
                date: .now,
                foodItem: recipe,
                portionGrams: 300
            )
        ]

        XCTAssertTrue(FavoriteIntentCatalog.candidates(from: [recipe]).isEmpty)
    }

    func testUnfavoritedCachedEntityCannotLogOrSubstitute() throws {
        let context = ModelContext(try makeContainer())
        context.insert(makeProfile())
        let food = try insertFavorite(
            name: "Cached Favorite",
            portion: 200,
            favoritedAt: .now,
            in: context
        )
        let cachedID = try XCTUnwrap(
            FavoriteIntentCatalog.candidates(from: [food]).first?.id
        )
        food.setFavorite(false)
        try context.save()

        XCTAssertThrowsError(
            try FavoriteIntentLogging.log(
                favoriteID: cachedID,
                meal: .lunch,
                in: context
            )
        ) { error in
            XCTAssertEqual(error as? FavoriteIntentLogging.Error, .unavailable)
        }
        XCTAssertEqual(try context.fetch(FetchDescriptor<FoodLogEntry>()).count, 1)
    }

    func testDeletedCachedEntityCannotLogOrUseSnapshotNutrition() throws {
        let context = ModelContext(try makeContainer())
        context.insert(makeProfile())
        let food = try insertFavorite(
            name: "Deleted Favorite",
            portion: 200,
            favoritedAt: .now,
            in: context
        )
        let cachedID = food.id.uuidString
        food.deletePreservingLogEntrySnapshots(from: context)
        try context.save()

        XCTAssertThrowsError(
            try FavoriteIntentLogging.log(
                favoriteID: cachedID,
                meal: .dinner,
                in: context
            )
        ) { error in
            XCTAssertEqual(error as? FavoriteIntentLogging.Error, .unavailable)
        }
        XCTAssertTrue(try context.fetch(FetchDescriptor<FoodItem>()).isEmpty)
    }

    func testInvalidatedNutritionCannotLogFromCachedEntity() throws {
        let context = ModelContext(try makeContainer())
        context.insert(makeProfile())
        let food = try insertFavorite(
            name: "Changed Favorite",
            portion: 250,
            favoritedAt: .now,
            in: context
        )
        let cachedID = food.id.uuidString
        food.caloriesPer100g = -1
        try context.save()

        XCTAssertThrowsError(
            try FavoriteIntentLogging.log(
                favoriteID: cachedID,
                meal: .breakfast,
                in: context
            )
        ) { error in
            XCTAssertEqual(error as? FavoriteIntentLogging.Error, .unavailable)
        }
    }

    func testEachInvocationCreatesExactlyOneTodayEntryWithoutDedupe() throws {
        let context = ModelContext(try makeContainer())
        context.insert(makeProfile())
        let food = try insertFavorite(
            name: "Greek yogurt",
            portion: 350,
            favoritedAt: .now,
            logDate: makeTestDate(year: 2026, month: 7, day: 20),
            in: context
        )
        let now = makeTestDate(year: 2026, month: 7, day: 25, hour: 17)

        let first = try FavoriteIntentLogging.log(
            favoriteID: food.id.uuidString,
            meal: .breakfast,
            in: context,
            now: now
        )
        let second = try FavoriteIntentLogging.log(
            favoriteID: food.id.uuidString,
            meal: .breakfast,
            in: context,
            now: now
        )

        XCTAssertEqual(first.portionGrams, 350)
        XCTAssertEqual(second.portionGrams, 350)
        XCTAssertEqual(
            first.response,
            "Logged 350 g of Greek yogurt to breakfast — 350 calories."
        )
        let todayEntries = try context.fetch(FetchDescriptor<FoodLogEntry>())
            .filter { Calendar.current.isDate($0.date, inSameDayAs: now) }
        XCTAssertEqual(todayEntries.count, 2)
        XCTAssertEqual(Set(todayEntries.map(\.id)).count, 2)
    }

    func testLoggingRequiresAuthenticatedLocalProfile() throws {
        let context = ModelContext(try makeContainer())
        let food = try insertFavorite(
            name: "Private Favorite",
            portion: 100,
            favoritedAt: .now,
            in: context
        )

        XCTAssertThrowsError(
            try FavoriteIntentLogging.log(
                favoriteID: food.id.uuidString,
                meal: .snack,
                in: context
            )
        ) { error in
            XCTAssertEqual(error as? FavoriteIntentLogging.Error, .unauthenticated)
        }
    }

    func testFavoriteEditRefreshesParametersOnlyForFavoriteEntities() {
        var refreshCount = 0

        CalorynAppShortcutRefresh.favoriteWasEdited(isFavorite: true) {
            refreshCount += 1
        }
        CalorynAppShortcutRefresh.favoriteWasEdited(isFavorite: false) {
            refreshCount += 1
        }

        XCTAssertEqual(refreshCount, 1)
    }

    func testCalorieResponsesCoverUnderOverAndMissingTarget() {
        XCTAssertEqual(
            TodayCaloriesIntentResponse.make(
                consumed: 1_200,
                target: 1_700,
                locale: englishLocale
            ),
            .available("1,200 of 1,700 calories logged today. 500 remaining.")
        )
        XCTAssertEqual(
            TodayCaloriesIntentResponse.make(
                consumed: 1_850,
                target: 1_700,
                locale: englishLocale
            ),
            .available("1,850 of 1,700 calories logged today. 150 over target.")
        )
        XCTAssertEqual(
            TodayCaloriesIntentResponse.make(
                consumed: 1_200,
                target: nil,
                locale: englishLocale
            ),
            .available("1,200 calories logged today.")
        )
    }

    func testCalorieResponseRejectsAbsentAndStaleSnapshots() {
        let now = makeTestDate(year: 2026, month: 7, day: 25)
        let stale = makeSnapshot(
            consumed: 1_200,
            target: 1_700,
            at: makeTestDate(year: 2026, month: 7, day: 24)
        )

        XCTAssertEqual(
            TodayCaloriesIntentResponse.make(
                snapshot: nil,
                currentConsumed: 0,
                expectedBaseTarget: 1_700,
                expectedTarget: 1_700,
                expectsDynamicTarget: false,
                now: now
            ),
            .unavailable("Open Caloryn to refresh today’s calorie snapshot.")
        )
        XCTAssertEqual(
            TodayCaloriesIntentResponse.make(
                snapshot: stale,
                currentConsumed: 1_200,
                expectedBaseTarget: 1_700,
                expectedTarget: 1_700,
                expectsDynamicTarget: false,
                now: now
            ),
            .unavailable("Open Caloryn to refresh today’s calorie snapshot.")
        )
    }

    func testCalorieResponseRejectsSameDaySnapshotThatDoesNotMatchLocalState() {
        let now = makeTestDate(year: 2026, month: 7, day: 25)
        let snapshot = makeSnapshot(
            consumed: 1_200,
            target: 1_700,
            at: now
        )

        XCTAssertEqual(
            TodayCaloriesIntentResponse.make(
                snapshot: snapshot,
                currentConsumed: 1_350,
                expectedBaseTarget: 1_700,
                expectedTarget: 1_700,
                expectsDynamicTarget: false,
                now: now
            ),
            .unavailable("Open Caloryn to refresh today’s calorie snapshot.")
        )
    }

    func testCalorieResponseRejectsDynamicSnapshotWhenCurrentHealthTargetDiffers() {
        let now = makeTestDate(year: 2026, month: 7, day: 25)
        let snapshot = DailyWidgetSnapshot(
            generatedAt: now,
            dayStart: Calendar.current.startOfDay(for: now),
            state: .ready,
            calories: WidgetCalorieSummary(
                consumed: 1_200,
                baseTarget: 1_700,
                target: 1_900,
                dynamicAdjustment: 200
            ),
            usesDynamicTarget: true,
            activityRefreshedAt: now
        )

        XCTAssertEqual(
            TodayCaloriesIntentResponse.make(
                snapshot: snapshot,
                currentConsumed: 1_200,
                expectedBaseTarget: 1_700,
                expectedTarget: 2_000,
                expectsDynamicTarget: true,
                now: now
            ),
            .unavailable("Open Caloryn to refresh today’s calorie snapshot.")
        )
    }

    func testCurrentDynamicBudgetUsesLocalHealthData() async {
        let now = makeTestDate(year: 2026, month: 7, day: 25)
        let profile = UserProfile(
            age: 30,
            sex: .male,
            heightCm: 180,
            weightKg: 75,
            activityLevel: .moderatelyActive,
            dailyCalorieTarget: 1_700,
            manualOverride: false,
            calorieDeficit: 0,
            energyCalculationMode: .dynamicHealth
        )
        let samples = (1...7).map { offset in
            DailyActiveEnergySample(
                date: Calendar.current.date(
                    byAdding: .day,
                    value: -offset,
                    to: now
                )!,
                activeEnergyKcal: 300
            )
        }
        let reader = StubActiveEnergyReader(
            isHealthAvailable: { true },
            activeEnergyBurnedKcal: { _ in 500 },
            dailyActiveEnergyBurnedKcal: { _, _ in samples },
            observeActiveEnergyChanges: { _ in nil }
        )

        let budget = await CurrentActivityCalorieBudget.load(
            profile: profile,
            consumed: 1_200,
            now: now,
            calendar: .current,
            reader: reader
        )

        XCTAssertEqual(budget?.activeEnergyKcal, 500)
        XCTAssertEqual(budget?.recentActiveEnergySamples, samples)
        XCTAssertEqual(budget?.adjustedTarget, (budget?.baseTarget ?? 0) + 200)
    }

    func testCalorieCheckUsesCurrentLocalSnapshotWithoutNetwork() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let now = makeTestDate(year: 2026, month: 7, day: 25)
        context.insert(makeProfile())
        let food = makeTestFoodItem(
            name: "Local entry",
            caloriesPer100g: 100
        )
        context.insert(food)
        context.insert(
            makeTestEntry(
                date: now,
                foodItem: food,
                portionGrams: 1_200
            )
        )
        try context.save()

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let snapshotStore = WidgetSnapshotStore(directoryURL: directory)
        try snapshotStore.save(
            makeSnapshot(consumed: 1_200, target: 1_700, at: now)
        )
        let store = CalorynIntentDataStore(
            modelContainer: container,
            widgetSnapshotStore: snapshotStore
        )

        let response = try await store.todayCaloriesResponse(
            now: now,
            locale: englishLocale
        )

        XCTAssertEqual(
            response,
            .available("1,200 of 1,700 calories logged today. 500 remaining.")
        )
    }

    func testCalorieCheckRequiresAuthenticatedLocalProfile() async throws {
        let container = try makeContainer()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let snapshotStore = WidgetSnapshotStore(directoryURL: directory)
        let now = makeTestDate(year: 2026, month: 7, day: 25)
        try snapshotStore.save(
            makeSnapshot(consumed: 1_200, target: 1_700, at: now)
        )
        let store = CalorynIntentDataStore(
            modelContainer: container,
            widgetSnapshotStore: snapshotStore
        )

        let response = try await store.todayCaloriesResponse(now: now)

        XCTAssertEqual(
            response,
            .unavailable(
                "Open Caloryn and finish setup before checking today’s calories."
            )
        )
    }

    private func insertFavorite(
        name: String,
        brand: String? = nil,
        portion: Double,
        favoritedAt: Date,
        logDate: Date = makeTestDate(year: 2026, month: 7, day: 20),
        in context: ModelContext
    ) throws -> FoodItem {
        let food = makeTestFoodItem(
            name: name,
            brand: brand,
            isCustom: true
        )
        food.setFavorite(true, at: favoritedAt)
        context.insert(food)
        context.insert(
            makeTestEntry(
                date: logDate,
                foodItem: food,
                portionGrams: portion
            )
        )
        try context.save()
        return food
    }

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: UserProfile.self,
            FoodItem.self,
            FoodLogEntry.self,
            RecipeIngredient.self,
            DailyGoalSnapshot.self,
            MealTemplate.self,
            MealTemplateItem.self,
            configurations: configuration
        )
    }

    private func makeProfile() -> UserProfile {
        UserProfile(
            age: 30,
            sex: .male,
            heightCm: 180,
            weightKg: 75,
            activityLevel: .moderatelyActive,
            dailyCalorieTarget: 1_700,
            manualOverride: true,
            calorieDeficit: 0
        )
    }

    private func makeSnapshot(
        consumed: Double,
        target: Int,
        at date: Date
    ) -> DailyWidgetSnapshot {
        DailyWidgetSnapshot(
            generatedAt: date,
            dayStart: Calendar.current.startOfDay(for: date),
            state: .ready,
            calories: WidgetCalorieSummary(
                consumed: consumed,
                baseTarget: target,
                target: target
            )
        )
    }
}
