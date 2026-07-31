import XCTest
@testable import Caloryn

/// Drives the Settings auto-adjust flow through the reader seam: the branches
/// that used to need a device with Apple Health, an entitlement and a tap on a
/// permission sheet.
@MainActor
final class SettingsDynamicEnergyFlowTests: XCTestCase {
    override func setUp() {
        super.setUp()
        clearAppleHealthDefaults()
    }

    override func tearDown() {
        clearAppleHealthDefaults()
        super.tearDown()
    }

    // MARK: - Turning auto-adjust on

    func testGrantedAuthorizationMovesTheProfileAndStartsTheTracker() async {
        let reader = StubActiveEnergyReader()

        let step = await SettingsDynamicEnergyFlow.enable(
            isRequestingAuthorization: false,
            reader: reader,
            onRequestStarted: { _ in }
        )

        XCTAssertEqual(reader.authorizationRequestCount, 1)
        XCTAssertEqual(step?.energyCalculationMode, .dynamicHealth)
        XCTAssertEqual(step?.trackerCommand, .start)
        XCTAssertEqual(
            step?.state,
            SettingsDynamicEnergyFlow.State(isRequestingAuthorization: false, statusMessage: nil)
        )
    }

    func testTheSpinnerIsRaisedAndAnyOlderMessageClearedBeforeAsking() async {
        var statesWhileAsking: [SettingsDynamicEnergyFlow.State] = []
        let reader = StubActiveEnergyReader(
            authorizationError: HealthKitServiceError.authorizationFailed
        )

        _ = await SettingsDynamicEnergyFlow.enable(
            isRequestingAuthorization: false,
            reader: reader,
            onRequestStarted: { statesWhileAsking.append($0) }
        )

        XCTAssertEqual(
            statesWhileAsking,
            [SettingsDynamicEnergyFlow.State(isRequestingAuthorization: true, statusMessage: nil)]
        )
    }

    /// A refusal must leave the profile where it was; only the message changes.
    func testRefusedAuthorizationReportsTheReasonAndLeavesTheProfileAlone() async {
        let reader = StubActiveEnergyReader(
            authorizationError: HealthKitServiceError.authorizationFailed
        )

        let step = await SettingsDynamicEnergyFlow.enable(
            isRequestingAuthorization: false,
            reader: reader,
            onRequestStarted: { _ in }
        )

        XCTAssertNil(step?.energyCalculationMode)
        XCTAssertNil(step?.trackerCommand)
        XCTAssertEqual(
            step?.state,
            SettingsDynamicEnergyFlow.State(
                isRequestingAuthorization: false,
                statusMessage: HealthKitServiceError.authorizationFailed.localizedDescription
            )
        )
    }

    func testADeviceWithoutHealthDataSaysSoWithoutMovingTheProfile() async {
        let reader = StubActiveEnergyReader(isHealthAvailable: { false })

        let step = await SettingsDynamicEnergyFlow.enable(
            isRequestingAuthorization: false,
            reader: reader,
            onRequestStarted: { _ in }
        )

        XCTAssertEqual(reader.authorizationRequestCount, 0)
        XCTAssertNil(step?.energyCalculationMode)
        XCTAssertNil(step?.trackerCommand)
        XCTAssertEqual(step?.state?.statusMessage, AppleHealthAdjustmentSettings.unavailableMessage)
    }

    /// The request already running owns the outcome; a second one would race it.
    func testASecondRequestWhileOneIsInFlightChangesNothing() async {
        var statesWhileAsking: [SettingsDynamicEnergyFlow.State] = []
        let reader = StubActiveEnergyReader()

        let step = await SettingsDynamicEnergyFlow.enable(
            isRequestingAuthorization: true,
            reader: reader,
            onRequestStarted: { statesWhileAsking.append($0) }
        )

        XCTAssertNil(step)
        XCTAssertEqual(reader.authorizationRequestCount, 0)
        XCTAssertTrue(statesWhileAsking.isEmpty)
    }

    // MARK: - Turning auto-adjust off

    func testTurningOffAlwaysSucceedsAndReturnsToTheLifestyleEstimate() async {
        _ = await SettingsDynamicEnergyFlow.enable(
            isRequestingAuthorization: false,
            reader: StubActiveEnergyReader(),
            onRequestStarted: { _ in }
        )

        let step = SettingsDynamicEnergyFlow.disable(isRequestingAuthorization: false)

        XCTAssertEqual(step.energyCalculationMode, .lifestyleEstimate)
        XCTAssertNil(step.trackerCommand)
        XCTAssertEqual(
            step.state,
            SettingsDynamicEnergyFlow.State(isRequestingAuthorization: false, statusMessage: nil)
        )
        XCTAssertFalse(UserDefaults.standard.bool(forKey: AppleHealthAdjustmentSettings.adjustmentEnabledKey))
    }

    /// Turning off never asks anything, so it must not clear the flag of a
    /// request that is still running.
    func testTurningOffLeavesAnInFlightRequestsFlagAlone() {
        let step = SettingsDynamicEnergyFlow.disable(isRequestingAuthorization: true)

        XCTAssertEqual(step.state?.isRequestingAuthorization, true)
    }

    // MARK: - The toggle

    func testTheToggleDoesNothingWhenItAlreadyReadsWhatItIsSetTo() {
        XCTAssertNil(
            SettingsDynamicEnergyFlow.toggleRequest(isEnabled: true, energyCalculationMode: .dynamicHealth)
        )
        XCTAssertNil(
            SettingsDynamicEnergyFlow.toggleRequest(isEnabled: false, energyCalculationMode: .lifestyleEstimate)
        )
    }

    func testTheToggleEnablesAndDisablesOnAChange() {
        XCTAssertEqual(
            SettingsDynamicEnergyFlow.toggleRequest(isEnabled: true, energyCalculationMode: .lifestyleEstimate),
            .enable
        )
        XCTAssertEqual(
            SettingsDynamicEnergyFlow.toggleRequest(isEnabled: false, energyCalculationMode: .dynamicHealth),
            .disable
        )
    }

    // MARK: - Coming back from the Health privacy screen

    func testNothingToDoChangesNoStateAndAsksNothing() async {
        let reader = StubActiveEnergyReader()

        let step = await SettingsDynamicEnergyFlow.step(
            after: .none,
            isRequestingAuthorization: false,
            reader: reader,
            onRequestStarted: { _ in }
        )

        XCTAssertNil(step)
        XCTAssertEqual(reader.authorizationRequestCount, 0)
    }

    /// Auto-adjust is already on: only the day's figures are re-read, and the
    /// message on screen is left as it is.
    func testAnAlreadyEnabledScreenOnlyRefreshesTheTracker() async {
        let reader = StubActiveEnergyReader()

        let step = await SettingsDynamicEnergyFlow.step(
            after: .refreshTracker,
            isRequestingAuthorization: false,
            reader: reader,
            onRequestStarted: { _ in }
        )

        XCTAssertEqual(step?.trackerCommand, .refresh)
        XCTAssertNil(step?.energyCalculationMode)
        XCTAssertNil(step?.state)
        XCTAssertEqual(reader.authorizationRequestCount, 0)
    }

    /// The one path that re-asks: permission may have been granted off-screen.
    func testAPendingPromptIsAskedAgainAndTurnsAutoAdjustOnWhenGranted() async {
        let reader = StubActiveEnergyReader()

        let step = await SettingsDynamicEnergyFlow.step(
            after: .requestAuthorization,
            isRequestingAuthorization: false,
            reader: reader,
            onRequestStarted: { _ in }
        )

        XCTAssertEqual(reader.authorizationRequestCount, 1)
        XCTAssertEqual(step?.energyCalculationMode, .dynamicHealth)
        XCTAssertEqual(step?.trackerCommand, .start)
    }

    func testAPendingPromptRefusedAgainLeavesTheProfileAlone() async {
        let reader = StubActiveEnergyReader(
            authorizationError: HealthKitServiceError.authorizationFailed
        )

        let step = await SettingsDynamicEnergyFlow.step(
            after: .requestAuthorization,
            isRequestingAuthorization: false,
            reader: reader,
            onRequestStarted: { _ in }
        )

        XCTAssertNil(step?.energyCalculationMode)
        XCTAssertEqual(
            step?.state?.statusMessage,
            HealthKitServiceError.authorizationFailed.localizedDescription
        )
    }

    // MARK: - Helpers

    private func clearAppleHealthDefaults() {
        UserDefaults.standard.removeObject(forKey: AppleHealthAdjustmentSettings.adjustmentEnabledKey)
        UserDefaults.standard.removeObject(forKey: AppleHealthAdjustmentSettings.authorizationRequestedKey)
        AppleHealthAdjustmentSettings.clearEmptyActiveEnergyTracking()
    }
}
