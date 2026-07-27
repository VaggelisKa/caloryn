import Foundation

/// Every rule the Settings "Calorie Estimate" section applies.
///
/// Takes the four facts the rules depend on rather than the profile, so the
/// section's behaviour is reachable without a SwiftData store: whether a manual
/// target is in force, which energy mode is stored, whether Apple Health exists
/// on this device, and whether an authorization request is in flight.
struct SettingsCalorieEstimate: Equatable {
    let isManualOverride: Bool
    let energyCalculationMode: EnergyCalculationMode
    let isHealthAvailable: Bool
    let isRequestingAuthorization: Bool

    init(
        isManualOverride: Bool,
        energyCalculationMode: EnergyCalculationMode,
        isHealthAvailable: Bool,
        isRequestingAuthorization: Bool
    ) {
        self.isManualOverride = isManualOverride
        self.energyCalculationMode = energyCalculationMode
        self.isHealthAvailable = isHealthAvailable
        self.isRequestingAuthorization = isRequestingAuthorization
    }

    /// A manual target always wins: the stored mode is ignored while it is on.
    var effectiveEnergyCalculationMode: EnergyCalculationMode {
        isManualOverride ? .lifestyleEstimate : energyCalculationMode
    }

    // MARK: - Toggle

    /// Whether the toggle drives the profile. With a manual target it is shown
    /// fixed off instead, so flipping it cannot silently discard the target.
    var isToggleBound: Bool { !isManualOverride }

    var isToggleOn: Bool {
        !isManualOverride && energyCalculationMode == .dynamicHealth
    }

    /// Off and unavailable means there is nothing to turn on; already on stays
    /// tappable so it can always be turned back off.
    var isToggleDisabled: Bool {
        if isManualOverride {
            return true
        }

        return isRequestingAuthorization || (energyCalculationMode != .dynamicHealth && !isHealthAvailable)
    }

    var modeIconName: String {
        effectiveEnergyCalculationMode == .dynamicHealth ? "heart.text.square.fill" : "figure.walk"
    }

    var modeSubtitle: String {
        if isManualOverride {
            return "Off - manual calorie target is set"
        }

        if energyCalculationMode == .dynamicHealth {
            return "On - using Health data when available"
        }

        return "Off - using your activity level"
    }

    // MARK: - Section content

    /// The per-day metric rows only mean anything while Health is actually
    /// driving the target.
    var showsDynamicMetrics: Bool {
        !isManualOverride && energyCalculationMode == .dynamicHealth
    }

    /// The budget's status line reads as information while auto-adjust is on and
    /// as a warning while it is off.
    var isDynamicStatusInformational: Bool {
        energyCalculationMode == .dynamicHealth
    }

    var isActiveEnergyTrackingEnabled: Bool {
        effectiveEnergyCalculationMode == .dynamicHealth
    }

    var footerText: String {
        if isManualOverride {
            return "Manual calorie targets stay fixed until you turn the override off."
        }

        if !isHealthAvailable {
            return AppleHealthAdjustmentSettings.unavailableMessage
        }

        if energyCalculationMode == .dynamicHealth {
            return "Auto-adjust uses Apple Health activity to keep your daily calorie target up to date. "
                + "Turn it off to use your activity level instead."
        }

        return "Your activity level sets the estimate. Auto-adjust can use Apple Health activity instead."
    }

    // MARK: - Metric values

    static let validActivityDaysDescription =
        "Active Energy days found; \(ActivityCalorieBudget.requiredDynamicActivityDays) days are needed before auto-adjust starts."

    static func validActivityDaysText(validActivityDays: Int) -> String {
        "\(validActivityDays)/\(ActivityCalorieBudget.requiredDynamicActivityDays)"
    }

    /// A dash until there are enough valid days to have a baseline at all.
    static func baselineText(activityBaselineKcal: Double?) -> String {
        guard let activityBaselineKcal else {
            return "-"
        }

        return Int(activityBaselineKcal.rounded()).kcalFormatted
    }

    // MARK: - Tracker fallback

    /// The tracker reporting a problem while auto-adjust is on drops the profile
    /// back to the lifestyle estimate rather than leaving the target frozen.
    static func fallsBackToLifestyle(
        energyCalculationMode: EnergyCalculationMode,
        trackerMessage: String?
    ) -> Bool {
        trackerMessage != nil && energyCalculationMode == .dynamicHealth
    }
}
