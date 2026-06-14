import Foundation

struct AppleHealthAdjustmentUpdate: Equatable {
    let isEnabled: Bool
    let authorizationRequested: Bool
    let message: String?
}

enum AppleHealthAdjustmentSettings {
    static let adjustmentEnabledKey = "appleHealthAdjustmentEnabled"
    static let authorizationRequestedKey = "appleHealthAuthorizationRequested"

    static var isHealthAvailable: Bool {
        HealthKitService.isHealthDataAvailable
    }

    static var activeEnergyCreditPolicyText: String {
        ActivityCalorieBudget.activeEnergyCreditPolicyText
    }

    static var activeEnergyCreditShortText: String {
        ActivityCalorieBudget.activeEnergyCreditShortText
    }

    static var unavailableMessage: String {
        "Apple Health is not available on this device."
    }

    static func footerText(isEnabled: Bool) -> String {
        guard isHealthAvailable else {
            return unavailableMessage
        }

        if isEnabled {
            return "Uses Apple Health Active Energy for today's budget."
        }

        return "Adjust calories based on activity"
    }

    @MainActor
    static func enable() async -> AppleHealthAdjustmentUpdate {
        guard isHealthAvailable else {
            return persist(isEnabled: false, authorizationRequested: false, message: unavailableMessage)
        }

        do {
            try await HealthKitService.requestActiveEnergyAuthorization()
            return persist(isEnabled: true, authorizationRequested: true, message: nil)
        } catch {
            return persist(isEnabled: false, authorizationRequested: false, message: error.localizedDescription)
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
        UserDefaults.standard.set(isEnabled, forKey: adjustmentEnabledKey)
        UserDefaults.standard.set(authorizationRequested, forKey: authorizationRequestedKey)

        return AppleHealthAdjustmentUpdate(
            isEnabled: isEnabled,
            authorizationRequested: authorizationRequested,
            message: message
        )
    }
}
