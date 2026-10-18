enum SettingsHealthAuthorizationRefresh {
    enum Action: Equatable {
        case none
        case refreshTracker
        case requestAuthorization
    }

    static func action(
        isManualOverride: Bool,
        energyCalculationMode: EnergyCalculationMode,
        isAuthorizationRequested: Bool,
        isHealthAvailable: Bool,
        isRequestingAuthorization: Bool
    ) -> Action {
        guard !isManualOverride else { return .none }
        guard energyCalculationMode != .dynamicHealth else { return .refreshTracker }
        guard isAuthorizationRequested else { return .none }
        guard isHealthAvailable, !isRequestingAuthorization else { return .none }

        return .requestAuthorization
    }
}
