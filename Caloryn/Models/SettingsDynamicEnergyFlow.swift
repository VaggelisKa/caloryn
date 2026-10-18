import Foundation

@MainActor
enum SettingsDynamicEnergyFlow {
    struct State: Equatable {
        var isRequestingAuthorization: Bool
        var statusMessage: String?
    }

    enum TrackerCommand: Equatable {
        case start
        case refresh
    }

    struct Step: Equatable {
        var energyCalculationMode: EnergyCalculationMode?
        var trackerCommand: TrackerCommand?
        var state: State?
    }

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

    static let requestingState = State(isRequestingAuthorization: true, statusMessage: nil)

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
