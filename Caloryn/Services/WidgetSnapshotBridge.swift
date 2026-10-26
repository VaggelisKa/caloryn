import OSLog
import SwiftData
import SwiftUI
import WidgetKit

@MainActor
final class WidgetSyncCoordinator {
    private let store: WidgetSnapshotStore
    private var lastPublished: DailyWidgetSnapshot?
    private let logger = Logger(
        subsystem: "www.caloryn",
        category: "WidgetSync"
    )

    init(store: WidgetSnapshotStore = WidgetSnapshotStore()) {
        self.store = store
    }

    func publish(_ snapshot: DailyWidgetSnapshot) {
        let previous = lastPublished ?? (try? store.load())

        if let previous, previous.hasSameRenderableContent(as: snapshot) {
            lastPublished = previous
            return
        }

        do {
            try store.save(snapshot)
            lastPublished = snapshot
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetConstants.dailyProgressKind)
        } catch {
            logger.error("Unable to publish widget snapshot: \(error.localizedDescription, privacy: .public)")
        }
    }
}

struct WidgetSnapshotBridge: View {
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \UserProfile.updatedAt, order: .reverse) private var profiles: [UserProfile]
    @Query(filter: FoodLogEntryWindow.loggedSince(FoodLogEntryWindow.recentStart(now: .now, calendar: .current)))
    private var recentEntries: [FoodLogEntry]

    @State private var syncCoordinator = WidgetSyncCoordinator()

    private var profile: UserProfile? {
        profiles.first
    }

    private var publishableSnapshot: DailyWidgetSnapshot {
        DailyWidgetSnapshotProjector.makeSnapshot(
            profile: profile,
            entries: recentEntries
        )
    }

    var body: some View {
        let snapshot = publishableSnapshot

        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .task(id: snapshot.renderIdentity) {
                syncCoordinator.publish(snapshot)
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                syncCoordinator.publish(snapshot)
            }
    }
}
