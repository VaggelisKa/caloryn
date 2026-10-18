import Foundation

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

    var effectiveEnergyCalculationMode: EnergyCalculationMode {
        isManualOverride ? .lifestyleEstimate : energyCalculationMode
    }

    var isToggleBound: Bool { !isManualOverride }

    var isToggleOn: Bool {
        !isManualOverride && energyCalculationMode == .dynamicHealth
    }

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

    var showsDynamicMetrics: Bool {
        !isManualOverride && energyCalculationMode == .dynamicHealth
    }

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

    static let validActivityDaysDescription =
        "Active Energy days found; \(ActivityCalorieBudget.requiredDynamicActivityDays) days are needed before auto-adjust starts."

    static func validActivityDaysText(validActivityDays: Int) -> String {
        "\(validActivityDays)/\(ActivityCalorieBudget.requiredDynamicActivityDays)"
    }

    static func baselineText(activityBaselineKcal: Double?) -> String {
        guard let activityBaselineKcal else {
            return "-"
        }

        return activityBaselineKcal.rounded().kcalFormatted
    }

    static func todayText(activeEnergyKcal: Double) -> String {
        activeEnergyKcal.rounded().kcalFormatted
    }

    static func fallsBackToLifestyle(
        energyCalculationMode: EnergyCalculationMode,
        trackerMessage: String?
    ) -> Bool {
        trackerMessage != nil && energyCalculationMode == .dynamicHealth
    }
}
