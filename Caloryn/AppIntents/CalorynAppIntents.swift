import AppIntents
import Foundation
import SwiftData

struct CalorynIntentDataStore: Sendable {
    let modelContainer: ModelContainer
    let widgetSnapshotStore: WidgetSnapshotStore

    nonisolated init(
        modelContainer: ModelContainer,
        widgetSnapshotStore: WidgetSnapshotStore = WidgetSnapshotStore()
    ) {
        self.modelContainer = modelContainer
        self.widgetSnapshotStore = widgetSnapshotStore
    }

    @MainActor
    func favoriteCandidates() throws -> [FavoriteIntentCandidate] {
        let context = modelContainer.mainContext
        guard try FavoriteIntentLogging.hasAuthenticatedUser(in: context) else {
            return []
        }
        let foods = try context.fetch(FetchDescriptor<FoodItem>())
        return FavoriteIntentCatalog.candidates(from: foods)
    }

    @MainActor
    func logFavorite(
        id: String,
        meal: MealType,
        now: Date = .now,
        calendar: Calendar = .current
    ) throws -> FavoriteIntentLogResult {
        let context = modelContainer.mainContext
        let result = try FavoriteIntentLogging.log(
            favoriteID: id,
            meal: meal,
            in: context,
            now: now,
            calendar: calendar
        )
        refreshWidgetSnapshot(
            in: context,
            now: now,
            calendar: calendar
        )
        CalorynAppShortcutRefresh.favoritesChanged()
        return result
    }

    @MainActor
    func todayCaloriesResponse(
        now: Date = .now,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) async throws -> TodayCaloriesIntentResponse {
        let context = modelContainer.mainContext
        let profiles = try context.fetch(
            FetchDescriptor<UserProfile>(
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        )
        guard let profile = profiles.first else {
            return .unavailable(
                "Open Caloryn and finish setup before checking today’s calories."
            )
        }

        let entries = try context.fetch(FetchDescriptor<FoodLogEntry>())
        let currentConsumed = entries
            .filter { calendar.isDate($0.date, inSameDayAs: now) }
            .reduce(0) { $0 + $1.calories }
        let expectsDynamicTarget = profile.effectiveEnergyCalculationMode == .dynamicHealth
        let snapshot = try? widgetSnapshotStore.load()
        guard let snapshot,
              snapshot.state == .ready,
              calendar.isDate(snapshot.dayStart, inSameDayAs: now) else {
            return .unavailable("Open Caloryn to refresh today’s calorie snapshot.")
        }

        let expectedBaseTarget: Int
        let expectedTarget: Int
        if expectsDynamicTarget {
            guard let budget = await CurrentActivityCalorieBudget.load(
                profile: profile,
                consumed: currentConsumed,
                now: now,
                calendar: calendar
            ) else {
                return .unavailable("Open Caloryn to refresh today’s calorie snapshot.")
            }
            expectedBaseTarget = budget.baseTarget
            expectedTarget = budget.adjustedTarget
        } else {
            expectedBaseTarget = profile.calorieBaseTarget(usesActiveEnergy: false)
            expectedTarget = expectedBaseTarget
        }

        return TodayCaloriesIntentResponse.make(
            snapshot: snapshot,
            currentConsumed: currentConsumed,
            expectedBaseTarget: expectedBaseTarget,
            expectedTarget: expectedTarget,
            expectsDynamicTarget: expectsDynamicTarget,
            now: now,
            calendar: calendar,
            locale: locale
        )
    }

    @MainActor
    private func refreshWidgetSnapshot(
        in context: ModelContext,
        now: Date,
        calendar: Calendar
    ) {
        guard let entries = try? context.fetch(FetchDescriptor<FoodLogEntry>()),
              let profiles = try? context.fetch(
                FetchDescriptor<UserProfile>(
                    sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
                )
              ),
              let profile = profiles.first else {
            return
        }

        let consumed = entries
            .filter { calendar.isDate($0.date, inSameDayAs: now) }
            .reduce(0) { $0 + $1.calories }
        let previous = try? widgetSnapshotStore.load()

        let snapshot: DailyWidgetSnapshot
        if let previous,
           previous.state == .ready,
           calendar.isDate(previous.dayStart, inSameDayAs: now) {
            snapshot = DailyWidgetSnapshot(
                generatedAt: now,
                dayStart: calendar.startOfDay(for: now),
                state: .ready,
                calories: WidgetCalorieSummary(
                    consumed: consumed,
                    baseTarget: previous.calories.baseTarget,
                    target: previous.calories.target,
                    dynamicAdjustment: previous.calories.dynamicAdjustment
                ),
                usesDynamicTarget: previous.usesDynamicTarget,
                activityRefreshedAt: previous.activityRefreshedAt
            )
        } else {
            snapshot = DailyWidgetSnapshotProjector.makeSnapshot(
                profile: profile,
                entries: entries,
                now: now,
                calendar: calendar
            )
        }

        WidgetSyncCoordinator(store: widgetSnapshotStore).publish(snapshot)
    }
}

struct FavoriteFoodEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Favorite Food"
    static let defaultQuery = FavoriteFoodQuery()

    let id: String
    let name: String
    let kind: String
    let portionGrams: Double
    let displayTitle: String

    init(candidate: FavoriteIntentCandidate) {
        id = candidate.id
        name = candidate.name
        kind = candidate.kind.rawValue
        portionGrams = candidate.portionGrams
        displayTitle = candidate.displayTitle
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(displayTitle)",
            subtitle: "\(kind), last logged \(IntentNumberFormatting.grams(portionGrams)) g"
        )
    }
}

struct FavoriteFoodQuery: EntityStringQuery, EnumerableEntityQuery {
    @Dependency
    private var store: CalorynIntentDataStore

    func entities(for identifiers: [FavoriteFoodEntity.ID]) async throws -> [FavoriteFoodEntity] {
        let candidates = try await store.favoriteCandidates()
        let byID = Dictionary(uniqueKeysWithValues: candidates.map { ($0.id, $0) })
        return identifiers.compactMap { byID[$0].map(FavoriteFoodEntity.init) }
    }

    func entities(matching string: String) async throws -> [FavoriteFoodEntity] {
        try await store.favoriteCandidates()
            .filter { FavoriteIntentCatalog.matches($0, search: string) }
            .map(FavoriteFoodEntity.init)
    }

    func suggestedEntities() async throws -> [FavoriteFoodEntity] {
        try await store.favoriteCandidates()
            .prefix(FavoriteFoodLogging.collapsedFavoriteLimit)
            .map(FavoriteFoodEntity.init)
    }

    func allEntities() async throws -> [FavoriteFoodEntity] {
        try await store.favoriteCandidates().map(FavoriteFoodEntity.init)
    }
}

enum CalorynIntentMeal: String, AppEnum {
    case breakfast
    case lunch
    case dinner
    case snack

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Meal"
    static let caseDisplayRepresentations: [CalorynIntentMeal: DisplayRepresentation] = [
        .breakfast: "Breakfast",
        .lunch: "Lunch",
        .dinner: "Dinner",
        .snack: "Snack",
    ]

    var mealType: MealType {
        MealType(rawValue: rawValue) ?? .breakfast
    }
}

struct LogFavoriteIntent: AppIntent {
    static let title: LocalizedStringResource = "Log a Favorite"
    static let description = IntentDescription(
        "Logs the most recently used safe portion of a favorite food or recipe to today."
    )
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication

    @Parameter(
        title: "Food",
        description: "A favorited manual food or reusable recipe."
    )
    var food: FavoriteFoodEntity

    @Parameter(
        title: "Meal",
        description: "Breakfast, lunch, dinner, or snack."
    )
    var meal: CalorynIntentMeal

    @Dependency
    private var store: CalorynIntentDataStore

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$food) to \(\.$meal)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let result = try await store.logFavorite(
                id: food.id,
                meal: meal.mealType
            )
            return .result(dialog: "\(await result.response)")
        } catch let error as FavoriteIntentLogging.Error {
            return .result(dialog: "\(error.localizedDescription)")
        } catch {
            return .result(
                dialog: "Caloryn couldn’t log that favorite. Open Caloryn to try again."
            )
        }
    }
}

struct ScanFoodIntent: AppIntent {
    static let title: LocalizedStringResource = "Scan Food"
    static let description = IntentDescription(
        "Opens Caloryn’s barcode scanner for today and the selected meal."
    )
    static let openAppWhenRun = true

    @available(iOS 26.0, *)
    static var supportedModes: IntentModes {
        .foreground(.immediate)
    }

    @Parameter(
        title: "Meal",
        description: "Breakfast, lunch, dinner, or snack."
    )
    var meal: CalorynIntentMeal

    static var parameterSummary: some ParameterSummary {
        Summary("Scan food for \(\.$meal)")
    }

    func perform() async throws -> some IntentResult {
        await AppRouter.shared.navigate(
            to: .scanFood(meal: WidgetMeal(rawValue: meal.rawValue) ?? .breakfast)
        )
        return .result()
    }
}

struct CheckTodayCaloriesIntent: AppIntent {
    static let title: LocalizedStringResource = "Check Today’s Calories"
    static let description = IntentDescription(
        "Reports calories logged today from Caloryn’s current local snapshot."
    )
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication

    @Dependency
    private var store: CalorynIntentDataStore

    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let response = try await store.todayCaloriesResponse()
            switch response {
            case .available(let message), .unavailable(let message):
                return .result(dialog: "\(message)")
            }
        } catch {
            return .result(
                dialog: "Open Caloryn to refresh today’s calorie snapshot."
            )
        }
    }
}

struct CalorynAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogFavoriteIntent(),
            phrases: [
                "Log a favorite with \(.applicationName)",
                "Log \(\.$food) with \(.applicationName)",
            ],
            shortTitle: "Log a Favorite",
            systemImageName: "star.circle.fill"
        )

        AppShortcut(
            intent: ScanFoodIntent(),
            phrases: [
                "Scan food with \(.applicationName)",
                "Scan food for \(\.$meal) with \(.applicationName)",
            ],
            shortTitle: "Scan Food",
            systemImageName: "barcode.viewfinder"
        )

        AppShortcut(
            intent: CheckTodayCaloriesIntent(),
            phrases: [
                "Check my calories with \(.applicationName)",
                "Check today’s calories with \(.applicationName)",
            ],
            shortTitle: "Check Today’s Calories",
            systemImageName: "gauge.with.dots.needle.67percent"
        )
    }
}

@MainActor
enum CalorynAppShortcutRefresh {
    static func favoritesChanged() {
        CalorynAppShortcuts.updateAppShortcutParameters()
    }

    static func favoriteWasEdited(
        isFavorite: Bool,
        updateParameters: () -> Void = {
            CalorynAppShortcuts.updateAppShortcutParameters()
        }
    ) {
        guard isFavorite else { return }
        updateParameters()
    }
}
