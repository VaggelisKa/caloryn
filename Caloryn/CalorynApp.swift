import AppIntents
import SwiftUI
import SwiftData

@main
struct CalorynApp: App {
    let sharedModelContainer: ModelContainer
    @State private var router = AppRouter.shared

    init() {
        let iCloudEnabled = UserDefaults.standard.object(forKey: "iCloudSyncEnabled") as? Bool ?? true
        #if DEBUG
        let usesEphemeralStore = UITestConfiguration.isActive
        #else
        let usesEphemeralStore = false
        #endif
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
        if usesEphemeralStore, let fixture = UITestConfiguration.fixture {
            do {
                try UITestSeeder.seed(fixture, into: sharedModelContainer.mainContext)
            } catch {
                fatalError("Could not seed UI test fixture \(fixture.rawValue): \(error)")
            }
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
