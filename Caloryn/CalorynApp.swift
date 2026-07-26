import AppIntents
import SwiftUI
import SwiftData

@main
struct CalorynApp: App {
    let sharedModelContainer: ModelContainer
    @State private var router = AppRouter.shared

    init() {
        #if DEBUG
        let historyFixture = HistorySimulatorFixture.current
        let usesEphemeralStore = UITestConfiguration.isActive || historyFixture != nil
        #else
        let usesEphemeralStore = false
        #endif
        let iCloudEnabled = UserDefaults.standard.object(forKey: "iCloudSyncEnabled") as? Bool ?? true
        let schema = Schema([
            UserProfile.self,
            FoodItem.self,
            FoodLogEntry.self,
            RecipeIngredient.self,
            DailyGoalSnapshot.self,
            MealTemplate.self,
            MealTemplateItem.self,
        ])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: usesEphemeralStore,
            cloudKitDatabase: usesEphemeralStore
                ? .none
                : (iCloudEnabled ? .automatic : .none)
        )

        do {
            let modelContainer = try ModelContainer(
                for: schema,
                configurations: [config]
            )
            sharedModelContainer = modelContainer
            AppDependencyManager.shared.add(
                dependency: CalorynIntentDataStore(modelContainer: modelContainer)
            )
            Task { @MainActor in
                CalorynAppShortcutRefresh.favoritesChanged()
            }
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }

        #if DEBUG
        // Seed synchronously so the first `@Query` already sees the fixture.
        if UITestConfiguration.isActive, let fixture = UITestConfiguration.fixture {
            do {
                try UITestSeeder.seed(fixture, into: sharedModelContainer.mainContext)
            } catch {
                fatalError("Could not seed UI test fixture \(fixture.rawValue): \(error)")
            }
        }

        if let historyFixture {
            let context = ModelContext(sharedModelContainer)
            switch historyFixture {
            case .recurringInsight:
                HistoryPreviewFixtures.seedRecurringInsight(in: context)
            case .noRecurringInsight:
                HistoryPreviewFixtures.seedNoRecurringInsight(in: context)
            }
            try? context.save()
            AppRouter.shared.selectedTab = .history
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(router)
                .onOpenURL(perform: router.handle)
        }
        .modelContainer(sharedModelContainer)
    }
}

#if DEBUG
private enum HistorySimulatorFixture: String {
    case recurringInsight
    case noRecurringInsight

    static var current: HistorySimulatorFixture? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flagIndex = arguments.firstIndex(of: "-CalorynHistoryFixture"),
              arguments.indices.contains(flagIndex + 1) else {
            return nil
        }
        return HistorySimulatorFixture(rawValue: arguments[flagIndex + 1])
    }
}
#endif
