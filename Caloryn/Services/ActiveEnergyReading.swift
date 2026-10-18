import Foundation

struct ActiveEnergyObservation {
    let stop: @MainActor () -> Void
}

nonisolated protocol ActiveEnergyReading {
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
