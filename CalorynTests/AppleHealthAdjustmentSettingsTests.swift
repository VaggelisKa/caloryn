import XCTest
@testable import Caloryn

final class AppleHealthAdjustmentSettingsTests: XCTestCase {
    override func setUp() {
        super.setUp()
        clearAppleHealthDefaults()
    }

    override func tearDown() {
        clearAppleHealthDefaults()
        super.tearDown()
    }

    func testPersistStoresTheEnabledAndAuthorizationRequestedFlags() {
        let update = AppleHealthAdjustmentSettings.persist(
            isEnabled: true,
            authorizationRequested: true,
            message: nil
        )

        XCTAssertEqual(update, AppleHealthAdjustmentUpdate(
            isEnabled: true,
            authorizationRequested: true,
            message: nil
        ))
        XCTAssertTrue(UserDefaults.standard.bool(forKey: AppleHealthAdjustmentSettings.adjustmentEnabledKey))
        XCTAssertTrue(UserDefaults.standard.bool(forKey: AppleHealthAdjustmentSettings.authorizationRequestedKey))
    }

    func testDisableClearsSettingsAndReturnsTheUserFacingMessage() {
        AppleHealthAdjustmentSettings.persist(
            isEnabled: true,
            authorizationRequested: true,
            message: nil
        )

        let update = AppleHealthAdjustmentSettings.disable(message: "Active energy access was not allowed.")

        XCTAssertEqual(update, AppleHealthAdjustmentUpdate(
            isEnabled: false,
            authorizationRequested: false,
            message: "Active energy access was not allowed."
        ))
        XCTAssertFalse(UserDefaults.standard.bool(forKey: AppleHealthAdjustmentSettings.adjustmentEnabledKey))
        XCTAssertFalse(UserDefaults.standard.bool(forKey: AppleHealthAdjustmentSettings.authorizationRequestedKey))
    }

    func testEnableStoresEnabledWhenAuthorizationSucceeds() async {
        let update = await AppleHealthAdjustmentSettings.enable(
            reader: StubActiveEnergyReader()
        )

        XCTAssertEqual(update, AppleHealthAdjustmentUpdate(
            isEnabled: true,
            authorizationRequested: true,
            message: nil
        ))
        XCTAssertTrue(UserDefaults.standard.bool(forKey: AppleHealthAdjustmentSettings.adjustmentEnabledKey))
        XCTAssertTrue(UserDefaults.standard.bool(forKey: AppleHealthAdjustmentSettings.authorizationRequestedKey))
    }

    func testEnableStaysDisabledAndRecordsAttemptWhenAuthorizationFails() async {
        let update = await AppleHealthAdjustmentSettings.enable(
            reader: StubActiveEnergyReader(authorizationError: HealthKitServiceError.authorizationFailed)
        )

        XCTAssertEqual(update, AppleHealthAdjustmentUpdate(
            isEnabled: false,
            authorizationRequested: true,
            message: HealthKitServiceError.authorizationFailed.localizedDescription
        ))
        XCTAssertFalse(UserDefaults.standard.bool(forKey: AppleHealthAdjustmentSettings.adjustmentEnabledKey))
        XCTAssertTrue(UserDefaults.standard.bool(forKey: AppleHealthAdjustmentSettings.authorizationRequestedKey))
    }

    func testRepeatedEmptyActivityRefreshesSurfaceAccessHint() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000)

        XCTAssertNil(AppleHealthAdjustmentSettings.recordActiveEnergyRefresh(
            activeEnergyKcal: 0,
            recentActiveEnergySamples: [],
            now: now
        ))
        XCTAssertNil(AppleHealthAdjustmentSettings.recordActiveEnergyRefresh(
            activeEnergyKcal: 0,
            recentActiveEnergySamples: [],
            now: now.addingTimeInterval(60)
        ))
        XCTAssertEqual(
            AppleHealthAdjustmentSettings.recordActiveEnergyRefresh(
                activeEnergyKcal: 0,
                recentActiveEnergySamples: [],
                now: now.addingTimeInterval(120)
            ),
            AppleHealthAdjustmentSettings.emptyActivityAccessMessage
        )
    }

    func testActivityDataClearsTheEmptyActivityHintCounter() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000)

        _ = AppleHealthAdjustmentSettings.recordActiveEnergyRefresh(
            activeEnergyKcal: 0,
            recentActiveEnergySamples: [],
            now: now
        )
        _ = AppleHealthAdjustmentSettings.recordActiveEnergyRefresh(
            activeEnergyKcal: 0,
            recentActiveEnergySamples: [],
            now: now.addingTimeInterval(60)
        )

        XCTAssertNil(AppleHealthAdjustmentSettings.recordActiveEnergyRefresh(
            activeEnergyKcal: 12,
            recentActiveEnergySamples: [],
            now: now.addingTimeInterval(120)
        ))
        XCTAssertNil(AppleHealthAdjustmentSettings.recordActiveEnergyRefresh(
            activeEnergyKcal: 0,
            recentActiveEnergySamples: [],
            now: now.addingTimeInterval(180)
        ))
    }

    private func clearAppleHealthDefaults() {
        UserDefaults.standard.removeObject(forKey: AppleHealthAdjustmentSettings.adjustmentEnabledKey)
        UserDefaults.standard.removeObject(forKey: AppleHealthAdjustmentSettings.authorizationRequestedKey)
        AppleHealthAdjustmentSettings.clearEmptyActiveEnergyTracking()
    }
}
