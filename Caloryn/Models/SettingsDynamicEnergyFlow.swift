import Foundation

/// What follows an Apple Health authorization outcome in Settings.
///
/// `SettingsHealthAuthorizationRefresh` decides *which* action to take when the
/// screen becomes active; this decides what state that action leaves behind.
/// Both the auto-adjust toggle and the on-return refresh used to run the same
/// block verbatim — guard against a second request, raise the in-flight state,
/// await the authorization, move the profile only if it was granted, start the
/// day tracker, then show whatever the service reported. One copy, here.
///
/// The view keeps the `@State`, the `Binding` and the `Task`; a `Step` says
/// which writes follow, so every branch is reachable without a Health store.
@MainActor
enum SettingsDynamicEnergyFlow {
    /// The two pieces of screen state the flow drives.
    struct State: Equatable {
        /// Drives the "Requesting Apple Health access" row and disables the toggle.
        var isRequestingAuthorization: Bool
        /// The message shown under the Calorie Estimate rows, if any.
        var statusMessage: String?
    }

    /// What the day tracker is asked to do once the profile has moved.
    enum TrackerCommand: Equatable {
        /// Auto-adjust just came on: configure the tracker as enabled for today.
        case start
        /// Auto-adjust was already on: re-read today's figures.
        case refresh
    }

    /// The writes the view performs, in order, once the flow settles.
    struct Step: Equatable {
        /// The mode to store, or `nil` to leave the profile alone — a refused
        /// authorization must not move it.
        var energyCalculationMode: EnergyCalculationMode?
        var trackerCommand: TrackerCommand?
        /// The screen state to adopt, or `nil` to leave it untouched — a plain
        /// tracker refresh must not clear a message it did not cause.
        var state: State?
    }

    /// Which way the toggle is being flipped, or `nil` when it already reads
    /// what it is being set to and there is nothing to do.
    enum ToggleRequest: Equatable {
        case enable
        case disable
    }

    static func toggleRequest(
        isEnabled: Bool,
        energyCalculationMode: EnergyCalculationMode
    ) -> ToggleRequest? {
        guard isEnabled != (energyCalculationMode == .dynamicHealth) else { return nil }

        return isEnabled ? .enable : .disable
    }

    /// The state held while the authorization request is in flight: the spinner
    /// on, and any earlier message cleared so a stale failure is not read as the
    /// outcome of this attempt.
    static let requestingState = State(isRequestingAuthorization: true, statusMessage: nil)

    /// Turns auto-adjust on.
    ///
    /// - Parameter onRequestStarted: called with `requestingState` before the
    ///   request is made, so the screen can show it is asking.
    /// - Returns: `nil` when a request is already in flight — that one owns the
    ///   outcome, and a second would race it.
    static func enable(
        isRequestingAuthorization: Bool,
        reader: any ActiveEnergyReading = HealthKitService.shared,
        onRequestStarted: (State) -> Void
    ) async -> Step? {
        guard !isRequestingAuthorization else { return nil }

        onRequestStarted(requestingState)

        let update = await AppleHealthAdjustmentSettings.enable(reader: reader)

        return Step(
            energyCalculationMode: update.isEnabled ? .dynamicHealth : nil,
            trackerCommand: update.isEnabled ? .start : nil,
            state: State(isRequestingAuthorization: false, statusMessage: update.message)
        )
    }

    /// Turns auto-adjust off. Never asks anything, so it always succeeds, and it
    /// leaves an in-flight request's own flag alone.
    static func disable(isRequestingAuthorization: Bool) -> Step {
        let update = AppleHealthAdjustmentSettings.disable()

        return Step(
            energyCalculationMode: .lifestyleEstimate,
            trackerCommand: nil,
            state: State(
                isRequestingAuthorization: isRequestingAuthorization,
                statusMessage: update.message
            )
        )
    }

    /// The step for an action decided by `SettingsHealthAuthorizationRefresh`,
    /// when the screen comes back from the Health privacy settings.
    ///
    /// - Returns: `nil` when nothing should change.
    static func step(
        after action: SettingsHealthAuthorizationRefresh.Action,
        isRequestingAuthorization: Bool,
        reader: any ActiveEnergyReading = HealthKitService.shared,
        onRequestStarted: (State) -> Void
    ) async -> Step? {
        switch action {
        case .none:
            return nil
        case .refreshTracker:
            return Step(energyCalculationMode: nil, trackerCommand: .refresh, state: nil)
        case .requestAuthorization:
            return await enable(
                isRequestingAuthorization: isRequestingAuthorization,
                reader: reader,
                onRequestStarted: onRequestStarted
            )
        }
    }
}
