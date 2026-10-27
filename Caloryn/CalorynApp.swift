import AppIntents
import SwiftUI
import SwiftData

@main
struct CalorynApp: App {
    let sharedModelContainer: ModelContainer
    let cloudSync: CloudSyncActivity
    @State private var router = AppRouter.shared

    init() {
        CalorynTypeface.register()
        CalorynTypeface.styleCollapsedNavigationTitles()
        #if DEBUG
        let historyFixture = HistorySimulatorFixture.current
        let usesEphemeralStore = UITestConfiguration.isActive || historyFixture != nil
        #else
        let usesEphemeralStore = false
        #endif
        let iCloudEnabled = UserDefaults.standard.object(forKey: "iCloudSyncEnabled") as? Bool ?? true
        let syncsWithCloud = !usesEphemeralStore && iCloudEnabled
        #if DEBUG
        cloudSync = UITestConfiguration.holdsCloudImport
            ? .heldOpenForUITests()
            : CloudSyncActivity(syncsWithCloud: syncsWithCloud)
        #else
        cloudSync = CloudSyncActivity(syncsWithCloud: syncsWithCloud)
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
            cloudKitDatabase: syncsWithCloud ? .automatic : .none
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
                .font(CalorynTheme.bodyText)
                .environment(router)
                .environment(cloudSync)
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
