import Foundation

/// A running HealthKit subscription, expressed without naming HealthKit so the
/// callers never import it.
struct ActiveEnergyObservation {
    let stop: @MainActor () -> Void
}

/// Thin seam over HealthKit's active-energy reads so every caller is testable.
///
/// Same shape as `ReminderNotificationCenter`: a protocol describing only what
/// the callers need, a concrete conformance (`HealthKitService`) and injection
/// through a default argument. Nothing here mentions `HKQuery`, so a fake can
/// answer without a device, an entitlement or a permission prompt.
nonisolated protocol ActiveEnergyReading {
    /// Nonisolated because settings and onboarding read availability while
    /// building view state, before any query runs.
    var isHealthDataAvailable: Bool { get }

    @MainActor
    func requestActiveEnergyAuthorization() async throws

    @MainActor
    func activeEnergyBurnedKcal(for date: Date, calendar: Calendar) async throws -> Double

    @MainActor
    func dailyActiveEnergyBurnedKcal(
        from startDate: Date,
        to endDate: Date,
        calendar: Calendar
    ) async throws -> [DailyActiveEnergySample]

    /// Returns `nil` when there is nothing to observe (no health data on this
    /// device); otherwise a handle the caller must stop.
    @MainActor
    func observeActiveEnergyChanges(onChange: @escaping @MainActor () -> Void) -> ActiveEnergyObservation?
}

extension ActiveEnergyReading {
    @MainActor
    func activeEnergyBurnedKcal(for date: Date) async throws -> Double {
        try await activeEnergyBurnedKcal(for: date, calendar: .current)
    }

    @MainActor
    func dailyActiveEnergyBurnedKcal(
        from startDate: Date,
        to endDate: Date
    ) async throws -> [DailyActiveEnergySample] {
        try await dailyActiveEnergyBurnedKcal(from: startDate, to: endDate, calendar: .current)
    }
}
