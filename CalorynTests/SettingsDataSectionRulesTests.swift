import XCTest
@testable import Caloryn

final class SettingsDataSectionRulesTests: XCTestCase {
    func testExportNeedsSomethingToExport() {
        XCTAssertFalse(SettingsDataSectionRules.isExportEnabled(loggedEntryCount: 0))
        XCTAssertTrue(SettingsDataSectionRules.isExportEnabled(loggedEntryCount: 1))
    }

    func testAFailedExportDoesNotPresentTheShareSheet() {
        XCTAssertFalse(SettingsDataSectionRules.presentsShareSheet(exportURL: nil))
        XCTAssertTrue(
            SettingsDataSectionRules.presentsShareSheet(exportURL: URL(fileURLWithPath: "/tmp/log.csv"))
        )
    }

    func testSyncFooterFollowsTheSyncToggle() {
        XCTAssertTrue(SettingsDataSectionRules.showsSyncFooter(isICloudSyncEnabled: true))
        XCTAssertFalse(SettingsDataSectionRules.showsSyncFooter(isICloudSyncEnabled: false))
    }

    func testVersionRowShowsTheBundleVersion() {
        XCTAssertEqual(SettingsAboutInfo.versionText(shortVersionString: "1.4.2"), "1.4.2")
    }

    func testVersionRowShowsADashWhenTheBundleHasNoVersion() {
        XCTAssertEqual(SettingsAboutInfo.versionText(shortVersionString: nil), "-")
    }
}
