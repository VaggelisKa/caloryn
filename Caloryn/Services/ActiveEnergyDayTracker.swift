import Foundation
import Observation

@MainActor
enum CurrentActivityCalorieBudget {
    static func load(
        profile: UserProfile,
        consumed: Double,
        now: Date = .now,
        calendar: Calendar = .current,
        reader: any ActiveEnergyReading = HealthKitService.shared
    ) async -> ActivityCalorieBudget? {
        guard reader.isHealthDataAvailable else { return nil }

        let dayStart = calendar.startOfDay(for: now)
        let historyStart = calendar.date(
            byAdding: .day,
            value: -ActivityCalorieBudget.historyLookbackDays,
            to: dayStart
        ) ?? dayStart

        do {
            async let activeEnergy = reader.activeEnergyBurnedKcal(for: dayStart, calendar: calendar)
            async let recentSamples = reader.dailyActiveEnergyBurnedKcal(
                from: historyStart,
                to: dayStart,
                calendar: calendar
            )
            let (activeEnergyKcal, recentActiveEnergySamples) = try await (
                activeEnergy,
                recentSamples
            )

            return profile.activityBudget(
                consumed: consumed,
                activeEnergyKcal: activeEnergyKcal,
                recentActiveEnergySamples: recentActiveEnergySamples,
                isActivityLoading: false,
                activityMessage: nil,
                date: dayStart
            )
        } catch {
            return nil
        }
    }
}

@MainActor
@Observable
final class ActiveEnergyDayTracker {
    private(set) var activeEnergyKcal: Double = 0
    private(set) var recentActiveEnergySamples: [DailyActiveEnergySample] = []
    private(set) var isLoading = false
    private(set) var message: String?
    private(set) var emptyActivityNotice: String?
    private(set) var lastRefresh: Date?

    @ObservationIgnored private let reader: any ActiveEnergyReading
    @ObservationIgnored private var activeEnergyObservation: ActiveEnergyObservation?
    @ObservationIgnored private var currentRefreshID: UUID?
    private var selectedDate: Date = Date().startOfDay
    private var isEnabled = false

    init(reader: any ActiveEnergyReading = HealthKitService.shared) {
        self.reader = reader
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

        guard reader.isHealthDataAvailable else {
            guard isCurrentRefresh(refreshID) else { return }
            AppleHealthAdjustmentSettings.disable(message: AppleHealthAdjustmentSettings.unavailableMessage)
            isEnabled = false
            activeEnergyKcal = 0
            message = AppleHealthAdjustmentSettings.unavailableMessage
            emptyActivityNotice = nil
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
            async let todayEnergy = reader.activeEnergyBurnedKcal(for: refreshDate)
            async let recentSamples = reader.dailyActiveEnergyBurnedKcal(
                from: refreshHistoryStartDate,
                to: refreshHistoryEndDate
            )
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
            emptyActivityNotice = refreshDate.startOfDay.isToday
                ? AppleHealthAdjustmentSettings.recordActiveEnergyRefresh(
                    activeEnergyKcal: kcal,
                    recentActiveEnergySamples: samples
                )
                : nil
            isLoading = false
            currentRefreshID = nil
        } catch {
            guard isCurrentRefresh(refreshID) else { return }
            AppleHealthAdjustmentSettings.disable(message: error.localizedDescription)
            isEnabled = false
            activeEnergyKcal = 0
            recentActiveEnergySamples = []
            message = error.localizedDescription
            emptyActivityNotice = nil
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
        emptyActivityNotice = nil
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
        guard activeEnergyObservation == nil, reader.isHealthDataAvailable else { return }

        activeEnergyObservation = reader.observeActiveEnergyChanges { [weak self] in
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
