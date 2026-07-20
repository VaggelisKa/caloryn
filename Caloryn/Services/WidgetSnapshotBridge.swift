import OSLog
import SwiftData
import SwiftUI
import WidgetKit

/// Stateless publisher that writes widget snapshots to the shared app group
/// container and asks WidgetKit to reload. Deduplicates against the last
/// published snapshot (in memory first, disk on first launch) so repeated
/// projections don't burn the widget reload budget.
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
        // Load is best-effort: a schema-version mismatch or missing file must not
        // prevent the new snapshot from being written, otherwise a failing load
        // would freeze the widget permanently by never saving a fresh snapshot.
        let previous: DailyWidgetSnapshot?
        if let lastPublished {
            previous = lastPublished
        } else {
            previous = try? store.load()
        }

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

/// Invisible view that observes the SwiftData store plus HealthKit activity
/// and mirrors today's calorie state into the widget snapshot store.
///
/// It owns its own `ActiveEnergyDayTracker` (separate from TodayView's) on
/// purpose: TodayView tracks whichever date the user browses, while the
/// widget must always reflect the current day.
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

    /// Projecting the snapshot is a cheap filter + reduce over today's
    /// entries, so we simply re-project whenever SwiftData or the activity
    /// tracker invalidates this view. `renderIdentity` excludes
    /// `generatedAt`, so the task below only re-fires when the widget
    /// would actually draw something different.
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
                syncCoordinator.publish(currentSnapshot)
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
