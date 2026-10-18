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
    @Query private var allEntries: [FoodLogEntry]

    @State private var activeEnergyTracker = ActiveEnergyDayTracker()
    @State private var syncCoordinator = WidgetSyncCoordinator()

    private var profile: UserProfile? {
        profiles.first
    }

    private var healthRefreshKey: WidgetHealthRefreshKey {
        WidgetHealthRefreshKey(
            dayStart: Date.now.startOfDay,
            profileID: profile?.id,
            calculationModeRaw: profile?.effectiveEnergyCalculationMode.rawValue
        )
    }

    private var currentSnapshot: DailyWidgetSnapshot {
        DailyWidgetSnapshotProjector.makeSnapshot(
            profile: profile,
            entries: allEntries,
            activeEnergyKcal: activeEnergyTracker.activeEnergyKcal,
            recentActiveEnergySamples: activeEnergyTracker.recentActiveEnergySamples,
            isActivityLoading: activeEnergyTracker.isLoading,
            activityMessage: activeEnergyTracker.message,
            activityRefreshedAt: activeEnergyTracker.lastRefresh
        )
    }

    var body: some View {
        let snapshot = currentSnapshot

        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .task(id: healthRefreshKey) {
                await activeEnergyTracker.configure(
                    date: .now,
                    isEnabled: profile?.effectiveEnergyCalculationMode == .dynamicHealth
                )
            }
            .task(id: snapshot.renderIdentity) {
                syncCoordinator.publish(snapshot)
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                activeEnergyTracker.refreshWhenActive()
                syncCoordinator.publish(snapshot)
            }
            .onDisappear {
                activeEnergyTracker.stopObserving()
            }
    }
}

private struct WidgetHealthRefreshKey: Hashable {
    let dayStart: Date
    let profileID: UUID?
    let calculationModeRaw: String?
}
