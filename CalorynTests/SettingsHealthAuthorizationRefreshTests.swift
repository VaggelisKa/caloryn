import XCTest
@testable import Caloryn

final class SettingsHealthAuthorizationRefreshTests: XCTestCase {
    func testManualOverrideNeverAsksForHealthAuthorization() {
        XCTAssertEqual(
            action(isManualOverride: true, energyCalculationMode: .lifestyleEstimate, isAuthorizationRequested: true),
            .none
        )
    }

    /// A manual target outranks a stored dynamic mode, so not even the tracker
    /// refresh happens.
    func testManualOverrideWithADynamicModeStillDoesNothing() {
        XCTAssertEqual(
            action(isManualOverride: true, energyCalculationMode: .dynamicHealth, isAuthorizationRequested: true),
            .none
        )
    }

    func testEnabledAutoAdjustOnlyRefreshesTheTracker() {
        XCTAssertEqual(
            action(energyCalculationMode: .dynamicHealth, isAuthorizationRequested: false),
            .refreshTracker
        )
    }

    func testAuthorizationIsRequestedAgainAfterAPendingPrompt() {
        XCTAssertEqual(
            action(energyCalculationMode: .lifestyleEstimate, isAuthorizationRequested: true),
            .requestAuthorization
        )
    }

    func testNothingHappensWhenAuthorizationWasNeverRequested() {
        XCTAssertEqual(
            action(energyCalculationMode: .lifestyleEstimate, isAuthorizationRequested: false),
            .none
        )
    }

    func testNothingHappensWithoutAHealthStore() {
        XCTAssertEqual(
            action(
                energyCalculationMode: .lifestyleEstimate,
                isAuthorizationRequested: true,
                isHealthAvailable: false
            ),
            .none
        )
    }

    /// A request already in flight owns the outcome; a second one would race it.
    func testAnInFlightRequestIsNotDuplicated() {
        XCTAssertEqual(
            action(
                energyCalculationMode: .lifestyleEstimate,
                isAuthorizationRequested: true,
                isRequestingAuthorization: true
            ),
            .none
        )
    }

    private func action(
        isManualOverride: Bool = false,
        energyCalculationMode: EnergyCalculationMode,
        isAuthorizationRequested: Bool,
        isHealthAvailable: Bool = true,
        isRequestingAuthorization: Bool = false
    ) -> SettingsHealthAuthorizationRefresh.Action {
        SettingsHealthAuthorizationRefresh.action(
            isManualOverride: isManualOverride,
            energyCalculationMode: energyCalculationMode,
            isAuthorizationRequested: isAuthorizationRequested,
            isHealthAvailable: isHealthAvailable,
            isRequestingAuthorization: isRequestingAuthorization
        )
    }
}
