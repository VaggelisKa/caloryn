import Foundation

enum FirstLaunchSyncGate {
    enum Phase: Equatable {
        case main
        case onboarding
        case awaitingCloudImport
    }

    enum CloudEvent: Equatable {
        case setupFinished(succeeded: Bool)
        case importFinished
        case exportFinished
    }

    static let waitCeiling: Duration = .seconds(8)

    static func phase(
        hasLocalProfile: Bool,
        syncsWithCloud: Bool,
        initialImportSettled: Bool,
        waitExpired: Bool
    ) -> Phase {
        if hasLocalProfile {
            return .main
        }
        if syncsWithCloud && !initialImportSettled && !waitExpired {
            return .awaitingCloudImport
        }
        return .onboarding
    }

    static func settlesInitialImport(_ event: CloudEvent) -> Bool {
        switch event {
        case .setupFinished(let succeeded):
            return !succeeded
        case .importFinished:
            return true
        case .exportFinished:
            return false
        }
    }
}
