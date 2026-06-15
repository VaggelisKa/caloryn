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

    private func clearAppleHealthDefaults() {
        UserDefaults.standard.removeObject(forKey: AppleHealthAdjustmentSettings.adjustmentEnabledKey)
        UserDefaults.standard.removeObject(forKey: AppleHealthAdjustmentSettings.authorizationRequestedKey)
    }
}
