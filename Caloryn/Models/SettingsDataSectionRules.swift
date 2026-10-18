import Foundation

enum SettingsDataSectionRules {
    static func isExportEnabled(loggedEntryCount: Int) -> Bool {
        loggedEntryCount > 0
    }

    static func presentsShareSheet(exportURL: URL?) -> Bool {
        exportURL != nil
    }

    static func showsSyncFooter(isICloudSyncEnabled: Bool) -> Bool {
        isICloudSyncEnabled
    }
}

enum SettingsAboutInfo {
    static func versionText(shortVersionString: String?) -> String {
        shortVersionString ?? "-"
    }
}
