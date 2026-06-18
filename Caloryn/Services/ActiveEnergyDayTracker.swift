import Foundation
import Observation

struct ActiveEnergyObservation {
    let stop: @MainActor () -> Void
}

@MainActor
struct ActiveEnergyDataSource {
    let isHealthAvailable: () -> Bool
    let activeEnergyBurnedKcal: (Date) async throws -> Double
    let dailyActiveEnergyBurnedKcal: (Date, Date) async throws -> [DailyActiveEnergySample]
    let observeActiveEnergyChanges: (@escaping @MainActor () -> Void) -> ActiveEnergyObservation?

    static let healthKit = ActiveEnergyDataSource(
        isHealthAvailable: {
            HealthKitService.isHealthDataAvailable
        },
        activeEnergyBurnedKcal: { date in
            try await HealthKitService.activeEnergyBurnedKcal(for: date)
        },
        dailyActiveEnergyBurnedKcal: { startDate, endDate in
            try await HealthKitService.dailyActiveEnergyBurnedKcal(from: startDate, to: endDate)
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
    private(set) var recentActiveEnergySamples: [DailyActiveEnergySample] = []
    private(set) var isLoading = false
    private(set) var message: String?
    private(set) var lastRefresh: Date?

    @ObservationIgnored private let dataSource: ActiveEnergyDataSource
    @ObservationIgnored private var activeEnergyObservation: ActiveEnergyObservation?
    @ObservationIgnored private var currentRefreshID: UUID?
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

        let refreshID = beginRefresh()

        guard dataSource.isHealthAvailable() else {
            guard isCurrentRefresh(refreshID) else { return }
            AppleHealthAdjustmentSettings.disable(message: AppleHealthAdjustmentSettings.unavailableMessage)
            isEnabled = false
            activeEnergyKcal = 0
            message = AppleHealthAdjustmentSettings.unavailableMessage
            isLoading = false
            currentRefreshID = nil
            stopObserving()
            return
        }

        isLoading = true
        message = nil

        do {
            let refreshDate = selectedDate
            let refreshHistoryStartDate = historyStartDate
            let refreshHistoryEndDate = historyEndDate
            async let todayEnergy = dataSource.activeEnergyBurnedKcal(refreshDate)
            async let recentSamples = dataSource.dailyActiveEnergyBurnedKcal(refreshHistoryStartDate, refreshHistoryEndDate)
            let (kcal, samples) = try await (todayEnergy, recentSamples)

            guard isCurrentRefresh(refreshID) else { return }
            if activeEnergyKcal != kcal {
                activeEnergyKcal = kcal
            }
            if recentActiveEnergySamples != samples {
                recentActiveEnergySamples = samples
            }
            lastRefresh = Date()
            message = nil
            isLoading = false
            currentRefreshID = nil
        } catch {
            guard isCurrentRefresh(refreshID) else { return }
            AppleHealthAdjustmentSettings.disable(message: error.localizedDescription)
            isEnabled = false
            activeEnergyKcal = 0
            recentActiveEnergySamples = []
            message = error.localizedDescription
            isLoading = false
            currentRefreshID = nil
            stopObserving()
        }
    }

    private func reset() {
        currentRefreshID = nil
        activeEnergyKcal = 0
        recentActiveEnergySamples = []
        isLoading = false
        message = nil
        lastRefresh = nil
    }

    private func beginRefresh() -> UUID {
        let refreshID = UUID()
        currentRefreshID = refreshID
        return refreshID
    }

    private func isCurrentRefresh(_ refreshID: UUID) -> Bool {
        currentRefreshID == refreshID
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

    private var historyStartDate: Date {
        Calendar.current.date(
            byAdding: .day,
            value: -ActivityCalorieBudget.historyLookbackDays,
            to: historyEndDate
        ) ?? selectedDate
    }

    private var historyEndDate: Date {
        let today = Date.now.startOfDay
        if selectedDate > today {
            return today
        }
        return selectedDate
    }
}
