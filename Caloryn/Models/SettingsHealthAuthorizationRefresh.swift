/// What Settings should do when it becomes active, for a profile that may have
/// been sent to the Health privacy screen and come back.
///
/// The screen cannot tell whether permission was granted while it was in the
/// background, so it re-asks — but only when re-asking can change anything.
enum SettingsHealthAuthorizationRefresh {
    enum Action: Equatable {
        /// Nothing to do; the stored state already answers the question.
        case none
        /// Auto-adjust is already on, so only the day's figures need refreshing.
        case refreshTracker
        /// Authorization was requested before but auto-adjust never came on:
        /// ask again, since the answer may have changed off-screen.
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
