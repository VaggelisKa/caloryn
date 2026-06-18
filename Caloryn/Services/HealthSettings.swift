import Foundation

struct AppleHealthAdjustmentUpdate: Equatable {
    let isEnabled: Bool
    let authorizationRequested: Bool
    let message: String?
}

enum AppleHealthAdjustmentSettings {
    static let adjustmentEnabledKey = "appleHealthAdjustmentEnabled"
    static let authorizationRequestedKey = "appleHealthAuthorizationRequested"
    static let emptyActiveEnergyRefreshCountKey = "appleHealthEmptyActiveEnergyRefreshCount"
    static let emptyActiveEnergyFirstSeenKey = "appleHealthEmptyActiveEnergyFirstSeen"

    private static let emptyActivityWarningRefreshThreshold = 3
    private static let emptyActivityWarningDelay: TimeInterval = 86_400

    static var isHealthAvailable: Bool {
        HealthKitService.isHealthDataAvailable
    }

    static var authorizationRequested: Bool {
        UserDefaults.standard.bool(forKey: authorizationRequestedKey)
    }

    static var dynamicEnergyPolicyText: String {
        ActivityCalorieBudget.dynamicEnergyPolicyText
    }

    static var dynamicEnergyShortText: String {
        ActivityCalorieBudget.dynamicEnergyShortText
    }

    static var unavailableMessage: String {
        "Apple Health is not available on this device."
    }

    static var connectedWaitingMessage: String {
        ActivityCalorieBudget.connectedWaitingText
    }

    static var emptyActivityAccessMessage: String {
        "No Active Energy found yet. This can happen if activity has not been recorded or Health access is off."
    }

    static func footerText(isEnabled: Bool) -> String {
        guard isHealthAvailable else {
            return unavailableMessage
        }

        if isEnabled {
            return "Uses Apple Health activity to adjust your daily calorie target."
        }

        return "Use Apple Health activity to update your daily calorie target."
    }

    @MainActor
    static func enable(
        isHealthAvailable: () -> Bool = {
            HealthKitService.isHealthDataAvailable
        },
        requestAuthorization: () async throws -> Void = {
            try await HealthKitService.requestActiveEnergyAuthorization()
        }
    ) async -> AppleHealthAdjustmentUpdate {
        guard isHealthAvailable() else {
            return persist(isEnabled: false, authorizationRequested: false, message: unavailableMessage)
        }

        do {
            try await requestAuthorization()
            clearEmptyActiveEnergyTracking()
            return persist(isEnabled: true, authorizationRequested: true, message: nil)
        } catch {
            return persist(isEnabled: false, authorizationRequested: true, message: error.localizedDescription)
        }
    }

    @discardableResult
    static func disable(message: String? = nil) -> AppleHealthAdjustmentUpdate {
        persist(isEnabled: false, authorizationRequested: false, message: message)
    }

    @discardableResult
    static func persist(
        isEnabled: Bool,
        authorizationRequested: Bool,
        message: String?
    ) -> AppleHealthAdjustmentUpdate {
        if !isEnabled {
            clearEmptyActiveEnergyTracking()
        }

        UserDefaults.standard.set(isEnabled, forKey: adjustmentEnabledKey)
        UserDefaults.standard.set(authorizationRequested, forKey: authorizationRequestedKey)

        return AppleHealthAdjustmentUpdate(
            isEnabled: isEnabled,
            authorizationRequested: authorizationRequested,
            message: message
        )
    }

    static func recordActiveEnergyRefresh(
        activeEnergyKcal: Double,
        recentActiveEnergySamples: [DailyActiveEnergySample],
        now: Date = .now
    ) -> String? {
        guard !hasAnyActiveEnergyData(
            activeEnergyKcal: activeEnergyKcal,
            recentActiveEnergySamples: recentActiveEnergySamples
        ) else {
            clearEmptyActiveEnergyTracking()
            return nil
        }

        let firstSeen = UserDefaults.standard.object(forKey: emptyActiveEnergyFirstSeenKey) as? Date ?? now
        if UserDefaults.standard.object(forKey: emptyActiveEnergyFirstSeenKey) == nil {
            UserDefaults.standard.set(firstSeen, forKey: emptyActiveEnergyFirstSeenKey)
        }

        let refreshCount = UserDefaults.standard.integer(forKey: emptyActiveEnergyRefreshCountKey) + 1
        UserDefaults.standard.set(refreshCount, forKey: emptyActiveEnergyRefreshCountKey)

        guard refreshCount >= emptyActivityWarningRefreshThreshold
                || now.timeIntervalSince(firstSeen) >= emptyActivityWarningDelay else {
            return nil
        }

        return emptyActivityAccessMessage
    }

    static func clearEmptyActiveEnergyTracking() {
        UserDefaults.standard.removeObject(forKey: emptyActiveEnergyRefreshCountKey)
        UserDefaults.standard.removeObject(forKey: emptyActiveEnergyFirstSeenKey)
    }

    private static func hasAnyActiveEnergyData(
        activeEnergyKcal: Double,
        recentActiveEnergySamples: [DailyActiveEnergySample]
    ) -> Bool {
        activeEnergyKcal > 0 || recentActiveEnergySamples.contains { $0.activeEnergyKcal > 0 }
    }
}
