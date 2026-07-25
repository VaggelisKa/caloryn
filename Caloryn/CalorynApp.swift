import SwiftUI
import SwiftData

@main
struct CalorynApp: App {
    let sharedModelContainer: ModelContainer
    @State private var router = AppRouter()

    init() {
        let iCloudEnabled = UserDefaults.standard.object(forKey: "iCloudSyncEnabled") as? Bool ?? true
        let screenshotFixtureActive = Issue73ScreenshotScenario.current != nil
            || Issue74ScreenshotScenario.current != nil
            || Issue77ScreenshotScenario.current != nil
        #if DEBUG
        let uiTestActive = UITestConfiguration.isActive
        #else
        let uiTestActive = false
        #endif
        let usesEphemeralStore = screenshotFixtureActive || uiTestActive
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
            sharedModelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }

        #if DEBUG
        // Seed synchronously so the first `@Query` already sees the fixture.
        if uiTestActive, let fixture = UITestConfiguration.fixture {
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
            #if DEBUG
            if let screenshotScenario = Issue73ScreenshotScenario.current {
                Issue73ScreenshotHost(scenario: screenshotScenario)
            } else if let screenshotScenario = Issue77ScreenshotScenario.current {
                Issue77ScreenshotHost(scenario: screenshotScenario)
            } else if let screenshotScenario = Issue74ScreenshotScenario.current {
                Issue74ScreenshotHost(scenario: screenshotScenario)
            } else {
                ContentView()
                    .environment(router)
                    .onOpenURL(perform: router.handle)
            }
            #else
            ContentView()
                .environment(router)
                .onOpenURL(perform: router.handle)
            #endif
        }
        .modelContainer(sharedModelContainer)
    }
}
