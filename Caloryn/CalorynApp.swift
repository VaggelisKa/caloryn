import SwiftUI
import SwiftData

@main
struct CalorynApp: App {
    let sharedModelContainer: ModelContainer

    init() {
        #if DEBUG
        let usesHistoryPreviewGallery = ProcessInfo.processInfo.arguments.contains("--history-preview-gallery")
        #else
        let usesHistoryPreviewGallery = false
        #endif
        let iCloudEnabled = UserDefaults.standard.object(forKey: "iCloudSyncEnabled") as? Bool ?? true
        let schema = Schema([
            UserProfile.self,
            FoodItem.self,
            FoodLogEntry.self,
            RecipeIngredient.self,
        ])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: usesHistoryPreviewGallery,
            cloudKitDatabase: iCloudEnabled && !usesHistoryPreviewGallery ? .automatic : .none
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
            if ProcessInfo.processInfo.arguments.contains("--history-preview-gallery") {
                HistoryPreviewGalleryView()
            } else {
                ContentView()
            }
            #else
            ContentView()
            #endif
        }
        .modelContainer(sharedModelContainer)
    }
}
