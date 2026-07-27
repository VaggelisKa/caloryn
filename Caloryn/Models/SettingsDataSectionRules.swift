import Foundation

/// Gating for the Settings "Data" section.
enum SettingsDataSectionRules {
    /// Exporting an empty log would hand the user a header-only file, so the
    /// action is offered only once there is something to export.
    static func isExportEnabled(loggedEntryCount: Int) -> Bool {
        loggedEntryCount > 0
    }

    /// Presenting the share sheet depends on the export having produced a file;
    /// a failed export leaves the screen as it was.
    static func presentsShareSheet(exportURL: URL?) -> Bool {
        exportURL != nil
    }

    /// The footer explains what sync does, so it is only there while sync is on.
    static func showsSyncFooter(isICloudSyncEnabled: Bool) -> Bool {
        isICloudSyncEnabled
    }
}

/// The "About" section's version row.
enum SettingsAboutInfo {
    /// A bundle with no short version string is a broken build rather than a
    /// zero version, so the row shows a dash instead of inventing a number.
    static func versionText(shortVersionString: String?) -> String {
        shortVersionString ?? "-"
    }
}
