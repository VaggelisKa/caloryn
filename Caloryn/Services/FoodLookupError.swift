import Foundation

struct FoodLookupFailurePresentation: Equatable {
    let title: String
    let message: String
    let systemImage: String
    let retryTitle: String?
}

enum FoodLookupError: LocalizedError, Equatable, Sendable {
    case cancelled
    case offline
    case invalidRequest
    case unauthorized
    case rateLimited
    case notFound
    case invalidData
    case unavailable

    var permitsFallback: Bool {
        switch self {
        case .notFound, .invalidData, .unavailable:
            true
        case .cancelled, .offline, .invalidRequest, .unauthorized, .rateLimited:
            false
        }
    }

    var outcome: FoodLookupOutcome {
        switch self {
        case .cancelled: .cancelled
        case .offline: .offline
        case .invalidRequest: .invalidRequest
        case .unauthorized: .unauthorized
        case .rateLimited: .rateLimited
        case .notFound: .notFound
        case .invalidData: .invalidData
        case .unavailable: .unavailable
        }
    }

    var presentation: FoodLookupFailurePresentation {
        switch self {
        case .cancelled:
            FoodLookupFailurePresentation(
                title: "Lookup Cancelled",
                message: "The lookup was cancelled.",
                systemImage: "xmark.circle",
                retryTitle: nil
            )
        case .offline:
            FoodLookupFailurePresentation(
                title: "You’re Offline",
                message: "Reconnect to the internet, then try again.",
                systemImage: "wifi.slash",
                retryTitle: "Try Again"
            )
        case .invalidRequest:
            FoodLookupFailurePresentation(
                title: "Invalid Lookup",
                message: "Check the search or scan another barcode.",
                systemImage: "exclamationmark.magnifyingglass",
                retryTitle: nil
            )
        case .unauthorized:
            FoodLookupFailurePresentation(
                title: "Food Search Unavailable",
                message: "Caloryn cannot access the food database right now. Try again later.",
                systemImage: "lock.trianglebadge.exclamationmark",
                retryTitle: nil
            )
        case .rateLimited:
            FoodLookupFailurePresentation(
                title: "Search Paused",
                message: "The food database is receiving too many requests. Try again in a few minutes.",
                systemImage: "hourglass",
                retryTitle: nil
            )
        case .notFound:
            FoodLookupFailurePresentation(
                title: "No Results",
                message: "Try a different search term or scan another barcode.",
                systemImage: "magnifyingglass",
                retryTitle: nil
            )
        case .invalidData:
            FoodLookupFailurePresentation(
                title: "Nutrition Details Missing",
                message: "The product was found, but its nutrition data could not be used. Try another result.",
                systemImage: "exclamationmark.triangle",
                retryTitle: "Try Again"
            )
        case .unavailable:
            FoodLookupFailurePresentation(
                title: "Food Search Unavailable",
                message: "The food databases did not respond. Try again in a moment.",
                systemImage: "server.rack",
                retryTitle: "Try Again"
            )
        }
    }

    func presentation(for operation: FoodLookupOperation) -> FoodLookupFailurePresentation {
        switch (operation, self) {
        case (.barcode, .notFound):
            FoodLookupFailurePresentation(
                title: "Barcode Not Found",
                message: "This barcode isn’t in our food database.",
                systemImage: "barcode.viewfinder",
                retryTitle: nil
            )
        case (.barcode, .invalidRequest):
            FoodLookupFailurePresentation(
                title: "Barcode Couldn’t Be Read",
                message: "This doesn’t appear to be a valid product barcode.",
                systemImage: "barcode.viewfinder",
                retryTitle: nil
            )
        default:
            presentation
        }
    }

    var dismissesWhenNameSearchBegins: Bool {
        self != .cancelled
    }

    var errorDescription: String? {
        presentation.message
    }
}
