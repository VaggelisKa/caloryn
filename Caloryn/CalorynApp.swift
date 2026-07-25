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
            isStoredInMemoryOnly: screenshotFixtureActive,
            cloudKitDatabase: screenshotFixtureActive
                ? .none
                : (iCloudEnabled ? .automatic : .none)
        )

        do {
            sharedModelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
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
