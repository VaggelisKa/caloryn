import Foundation
import Observation

struct ActiveEnergyObservation {
    let stop: @MainActor () -> Void
}

@MainActor
struct ActiveEnergyDataSource {
    let isHealthAvailable: () -> Bool
    let activeEnergyBurnedKcal: (Date) async throws -> Double
    let observeActiveEnergyChanges: (@escaping @MainActor () -> Void) -> ActiveEnergyObservation?

    static let healthKit = ActiveEnergyDataSource(
        isHealthAvailable: {
            HealthKitService.isHealthDataAvailable
        },
        activeEnergyBurnedKcal: { date in
            try await HealthKitService.activeEnergyBurnedKcal(for: date)
        },
        observeActiveEnergyChanges: { onChange in
            guard let query = HealthKitService.observeActiveEnergyChanges(onChange: onChange) else {
                return nil
            }

            return ActiveEnergyObservation {
                HealthKitService.stop(query)
            }
        }
    )
}

@MainActor
@Observable
final class ActiveEnergyDayTracker {
    private(set) var activeEnergyKcal: Double = 0
    private(set) var isLoading = false
    private(set) var message: String?

    @ObservationIgnored private let dataSource: ActiveEnergyDataSource
    @ObservationIgnored private var activeEnergyObservation: ActiveEnergyObservation?
    private var selectedDate: Date = Date().startOfDay
    private var isEnabled = false

    init() {
        self.dataSource = .healthKit
    }

    init(dataSource: ActiveEnergyDataSource) {
        self.dataSource = dataSource
    }

    func configure(date: Date, isEnabled: Bool) async {
        let normalizedDate = date.startOfDay
        let dateChanged = !Calendar.current.isDate(normalizedDate, inSameDayAs: selectedDate)
        let enabledChanged = self.isEnabled != isEnabled

        selectedDate = normalizedDate
        self.isEnabled = isEnabled

        guard isEnabled else {
            stopObserving()
            reset()
            return
        }

        let observerNeedsStart = activeEnergyObservation == nil
        startObservingIfNeeded()

        if dateChanged || enabledChanged || observerNeedsStart {
            await refresh()
        }
    }

    func refreshWhenActive() {
        guard isEnabled else { return }
        startObservingIfNeeded()

        Task {
            await refresh()
        }
    }

    func stopObserving() {
        guard let activeEnergyObservation else { return }
        activeEnergyObservation.stop()
        self.activeEnergyObservation = nil
    }

    private func refresh() async {
        guard isEnabled else {
            reset()
            return
        }

        guard dataSource.isHealthAvailable() else {
            AppleHealthAdjustmentSettings.disable(message: AppleHealthAdjustmentSettings.unavailableMessage)
            isEnabled = false
            activeEnergyKcal = 0
            message = AppleHealthAdjustmentSettings.unavailableMessage
            stopObserving()
            return
        }

        isLoading = true
        message = nil
        defer {
            isLoading = false
        }

        do {
            let kcal = try await dataSource.activeEnergyBurnedKcal(selectedDate)
            if activeEnergyKcal != kcal {
                activeEnergyKcal = kcal
            }
            message = nil
        } catch {
            AppleHealthAdjustmentSettings.disable(message: error.localizedDescription)
            isEnabled = false
            activeEnergyKcal = 0
            message = error.localizedDescription
            stopObserving()
        }
    }

    private func reset() {
        activeEnergyKcal = 0
        isLoading = false
        message = nil
    }

    private func startObservingIfNeeded() {
        guard activeEnergyObservation == nil, dataSource.isHealthAvailable() else { return }

        activeEnergyObservation = dataSource.observeActiveEnergyChanges { [weak self] in
            guard let self else { return }

            Task {
                await self.refresh()
            }
        }
    }
}
