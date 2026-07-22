import SwiftUI
import SwiftData

@main
struct CalorynApp: App {
    let sharedModelContainer: ModelContainer
    @State private var router = AppRouter()

    init() {
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
            cloudKitDatabase: iCloudEnabled ? .automatic : .none
        )

        do {
            sharedModelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
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
