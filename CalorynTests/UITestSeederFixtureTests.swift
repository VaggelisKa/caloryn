#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import Caloryn

/// The fixtures the E2E journeys launch into. A journey asserts what it sees on screen; these
/// pin what it was given, so a changed fixture fails here, with its exact difference, rather
/// than as a timed-out element lookup three minutes into the UI plan.
///
/// The seeder dates everything from the real current day (it has no injectable clock), so
/// each seeding reads "today" before and after and re-seeds into a fresh store if midnight
/// fell in between.
@MainActor
@Suite("UI test seeder fixtures")
struct UITestSeederFixtureTests {

    // MARK: - Empty and profile

    @Test("The empty fixture seeds nothing at all, so the app opens onboarding")
    func emptySeedsNothing() throws {
        let seeded = try seededStore(.empty)

        #expect(try seeded.profiles().isEmpty)
        #expect(try seeded.foods().isEmpty)
        #expect(try seeded.entries().isEmpty)
        #expect(try seeded.snapshots().isEmpty)
    }

    @Test("profileOnly seeds one manual 2,000 kcal profile and no food")
    func profileOnlySeedsTheStandardProfile() throws {
        let seeded = try seededStore(.profileOnly)

        let profiles = try seeded.profiles()
        #expect(profiles.count == 1)
        let profile = try #require(profiles.first)
        #expect(profile.age == 30)
        #expect(profile.sex == .male)
        #expect(profile.heightCm == 180)
        #expect(profile.weightKg == 80)
        #expect(profile.activityLevel == .moderatelyActive)
        #expect(profile.dailyCalorieTarget == 2_000)
        #expect(profile.manualOverride)
        #expect(try seeded.foods().isEmpty)
        #expect(try seeded.entries().isEmpty)
    }

    // MARK: - Logged days

    @Test("loggedDay seeds one 100 g Rolled Oats breakfast today, 380 kcal")
    func loggedDaySeedsTodaysOats() throws {
        let seeded = try seededStore(.loggedDay)

        #expect(try seeded.profiles().count == 1)
        let foods = try seeded.foods()
        #expect(foods.map(\.name) == ["Rolled Oats"])
        let oats = try #require(foods.first)
        #expect(oats.brand == "Test Brand")
        #expect(oats.caloriesPer100g == 380)
        #expect(oats.defaultServingG == 50)

        let entries = try seeded.entries()
        #expect(entries.count == 1)
        let entry = try #require(entries.first)
        #expect(entry.date == seeded.today)
        #expect(entry.mealType == .breakfast)
        #expect(entry.foodName == "Rolled Oats")
        #expect(entry.portionGrams == 100)
        #expect(entry.calories == 380)
        #expect(entry.proteinG == 13)
        #expect(entry.foodItem?.name == "Rolled Oats")
    }

    @Test("loggedYesterday seeds the same breakfast one calendar day back, and nothing today")
    func loggedYesterdaySeedsYesterday() throws {
        let seeded = try seededStore(.loggedYesterday)
        let yesterday = try #require(Calendar.current.date(byAdding: .day, value: -1, to: seeded.today))

        let entries = try seeded.entries()
        #expect(entries.count == 1)
        let entry = try #require(entries.first)
        #expect(entry.date == yesterday)
        #expect(entry.foodName == "Rolled Oats")
        #expect(entry.calories == 380)
        #expect(entries.contains { Calendar.current.isDate($0.date, inSameDayAs: seeded.today) } == false)
    }

    // MARK: - Custom foods

    @Test("customFoods seeds the favourited smoothie and the salad the portion journeys do maths on")
    func customFoodsSeedsBothFoods() throws {
        let seeded = try seededStore(.customFoods)

        #expect(try seeded.profiles().count == 1)
        #expect(try seeded.entries().isEmpty, "Today must start empty: the journey checks the smoothie is not logged yet")

        let foods = try seeded.foods()
        #expect(Set(foods.map(\.name)) == ["Morning Smoothie", "House Salad"])
        #expect(foods.allSatisfy { $0.isCustom })

        let smoothie = try #require(foods.first { $0.name == "Morning Smoothie" })
        #expect(smoothie.isFavorite)
        #expect(smoothie.caloriesPer100g == 60)
        #expect(smoothie.defaultServingG == 250)

        // JourneyTests: "House Salad is 45 kcal per 100g and opens at its 180g serving".
        let salad = try #require(foods.first { $0.name == "House Salad" })
        #expect(salad.isFavorite == false)
        #expect(salad.caloriesPer100g == 45)
        #expect(salad.defaultServingG == 180)
        #expect(salad.fatPer100g == 1.5)
    }

    // MARK: - History

    @Test("history seeds thirty consecutive days ending today, one oats breakfast each")
    func historySeedsThirtyConsecutiveDays() throws {
        let seeded = try seededStore(.history)
        let calendar = Calendar.current

        #expect(try seeded.foods().map(\.name) == ["Rolled Oats"])
        let entries = try seeded.entries()
        #expect(entries.count == 30)

        let expectedDays = (0..<30).compactMap { calendar.date(byAdding: .day, value: -$0, to: seeded.today) }
        #expect(Set(entries.map(\.date)) == Set(expectedDays))
        #expect(entries.allSatisfy { $0.mealType == .breakfast })
    }

    @Test(
        "history repeats a 100/150/200/250/300 g portion cycle back from today",
        arguments: [(0, 100.0), (1, 150.0), (2, 200.0), (3, 250.0), (4, 300.0), (5, 100.0), (29, 300.0)]
    )
    func historyPortionPattern(dayOffset: Int, grams: Double) throws {
        let seeded = try seededStore(.history)
        let day = try #require(Calendar.current.date(byAdding: .day, value: -dayOffset, to: seeded.today))

        let entry = try #require(try seeded.entries().first { $0.date == day })
        #expect(entry.portionGrams == grams)
        #expect(abs(entry.calories - grams * 3.8) < 0.001)
    }

    @Test("history totals 22,800 kcal over its thirty days, the figure History's averages derive from")
    func historyTotal() throws {
        let seeded = try seededStore(.history)
        let total = try seeded.entries().reduce(0) { $0 + $1.calories }
        #expect(abs(total - 22_800) < 0.001)
    }

    @Test("historyPattern seeds thirty past days with an exact 2,000 kcal target snapshot each, today untouched")
    func historyPatternShape() throws {
        let seeded = try seededStore(.historyPattern)
        let calendar = Calendar.current

        let profiles = try seeded.profiles()
        #expect(profiles.count == 1)
        #expect(profiles.first?.dailyCalorieTarget == 2_000)
        #expect(profiles.first?.age == 34)

        let entries = try seeded.entries()
        let days = Set(entries.map(\.date))
        #expect(days.count == 30)
        #expect(days.contains(seeded.today) == false)
        #expect(entries.count == 120, "four meals a day")

        let snapshots = try seeded.snapshots()
        #expect(snapshots.count == 30)
        #expect(snapshots.allSatisfy { $0.effectiveCalorieTarget == 2_000 })
        let expectedKeys = (1...30).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: seeded.today).map { DailyGoalSnapshot.dayKey(for: $0) }
        }
        #expect(Set(snapshots.map(\.dayKey)) == Set(expectedKeys))
    }

    @Test("historyPattern's Fridays carry the heavier day the recurring pattern is built from")
    func historyPatternFridaysAreHeavier() throws {
        let seeded = try seededStore(.historyPattern)
        let calendar = Calendar.current

        let byDay = Dictionary(grouping: try seeded.entries(), by: \.date)
        for (day, entries) in byDay {
            let total = entries.reduce(0) { $0 + $1.calories }
            let isFriday = calendar.component(.weekday, from: day) == 6
            #expect(abs(total - (isFriday ? 2_800 : 2_000)) < 0.001, "\(day) totals \(total)")
            let dinner = entries.first { $0.mealType == .dinner }?.foodName
            #expect(dinner == (isFriday ? "Friday dinner" : "Evening meal"))
        }
    }

    @Test("historyPattern produces exactly the over-target Friday dinner pattern the journey opens")
    func historyPatternIsDiscovered() throws {
        let seeded = try seededStore(.historyPattern)

        let pattern = try #require(try seeded.discoveredPattern())
        #expect(pattern.kind == .weekdayMeal)
        #expect(pattern.weekday == 6)
        #expect(pattern.mealType == .dinner)
        #expect(pattern.supportingDays.isEmpty == false)
    }

    @Test("historyNoPattern seeds eighteen even days and no pattern qualifies, so History shows no card")
    func historyNoPatternFindsNothing() throws {
        let seeded = try seededStore(.historyNoPattern)

        let entries = try seeded.entries()
        #expect(Set(entries.map(\.date)).count == 18)
        #expect(entries.count == 72)
        #expect(try seeded.snapshots().count == 18)
        #expect(entries.contains { $0.foodName == "Friday dinner" } == false)
        #expect(try seeded.discoveredPattern() == nil)
    }

    // MARK: - Over budget

    @Test("overBudgetDay logs eleven entries today, past the 2,000 kcal goal")
    func overBudgetDayIsOverBudget() throws {
        let seeded = try seededStore(.overBudgetDay)

        let profile = try #require(try seeded.profiles().first)
        #expect(profile.dailyCalorieTarget == 2_000)
        #expect(profile.target(for: .sugars) == 50)
        #expect(profile.target(for: .saturatedFat) == 20)

        let entries = try seeded.entries()
        #expect(entries.count == 11)
        #expect(entries.allSatisfy { $0.date == seeded.today })
        let total = entries.reduce(0) { $0 + $1.calories }
        #expect(abs(total - 2_337.4) < 0.01)
        #expect(total > Double(profile.dailyCalorieTarget))

        let perMeal = Dictionary(grouping: entries, by: \.mealType).mapValues(\.count)
        #expect(perMeal == [.breakfast: 3, .lunch: 3, .dinner: 4, .snack: 1])
    }

    @Test("overBudgetDay keeps one entry whose saved food is gone, the wine, from its snapshot alone")
    func overBudgetDayHasAnOrphanedEntry() throws {
        let seeded = try seededStore(.overBudgetDay)

        let orphans = try seeded.entries().filter { $0.foodItem == nil }
        #expect(orphans.map(\.foodName) == ["Red wine"])
        let wine = try #require(orphans.first)
        #expect(wine.mealType == .dinner)
        #expect(wine.portionGrams == 250)
        #expect(abs(wine.calories - 170) < 0.001)

        let foods = try seeded.foods()
        #expect(foods.count == 10)
        #expect(foods.contains { $0.name == "Red wine" } == false)
        #expect(foods.contains { $0.name == "Granny Smith apples, organic, family pack from a Danish orchard" })
        #expect(foods.filter { $0.isRecipe }.map(\.name) == ["Smørrebrød, salmon"])
    }
}

// MARK: - Helpers

@MainActor
private struct SeededStore {
    let container: ModelContainer
    let today: Date

    var context: ModelContext { container.mainContext }

    func profiles() throws -> [UserProfile] { try context.fetch(FetchDescriptor<UserProfile>()) }
    func foods() throws -> [FoodItem] { try context.fetch(FetchDescriptor<FoodItem>()) }
    func entries() throws -> [FoodLogEntry] { try context.fetch(FetchDescriptor<FoodLogEntry>()) }
    func snapshots() throws -> [DailyGoalSnapshot] { try context.fetch(FetchDescriptor<DailyGoalSnapshot>()) }

    /// The recurring pattern History would show, resolved the way `HistoryView` resolves it.
    func discoveredPattern() throws -> HistoryRecurringCaloriePattern? {
        let resolver = HistoryDayTargetResolver(
            fallbackTarget: try profiles().first?.dailyCalorieTarget ?? 2_000,
            valuesByDayKey: DailyGoalSnapshotStore.latestValuesByDayKey(try snapshots())
        )
        return HistoryRecurringCaloriePatternEngine().discover(entries: try entries(), targetResolver: resolver)
    }
}

@MainActor
private func seededStore(_ fixture: UITestConfiguration.Fixture) throws -> SeededStore {
    for _ in 0..<2 {
        let before = Calendar.current.startOfDay(for: Date())
        let container = try ModelContainer(
            for: UserProfile.self,
            FoodItem.self,
            FoodLogEntry.self,
            RecipeIngredient.self,
            DailyGoalSnapshot.self,
            MealTemplate.self,
            MealTemplateItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        try UITestSeeder.seed(fixture, into: container.mainContext)
        let after = Calendar.current.startOfDay(for: Date())
        if before == after {
            return SeededStore(container: container, today: before)
        }
    }
    Issue.record("Could not seed \(fixture.rawValue) without crossing midnight twice")
    throw CancellationError()
}
#endif
