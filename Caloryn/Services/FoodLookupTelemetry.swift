import Foundation
import OSLog

enum FoodLookupOperation: String, Sendable {
    case search
    case barcode
}

enum FoodLookupOutcome: String, Sendable {
    case success
    case notFound = "not_found"
    case offline
    case cancelled
    case unauthorized
    case rateLimited = "rate_limited"
    case invalidRequest = "invalid_request"
    case invalidData = "invalid_data"
    case unavailable
}

enum FoodLookupLatencyClass: String, Sendable {
    case fast
    case moderate
    case slow

    init(elapsed: Duration) {
        if elapsed < .milliseconds(500) {
            self = .fast
        } else if elapsed < .seconds(2) {
            self = .moderate
        } else {
            self = .slow
        }
    }
}

struct FoodLookupTelemetryEvent: Equatable, Sendable {
    let operation: FoodLookupOperation
    let provider: FoodSearchProvider
    let outcome: FoodLookupOutcome
    let latency: FoodLookupLatencyClass
    let attempt: Int
    let isFallback: Bool
    let fallbackSucceeded: Bool?
}

protocol FoodLookupTelemetryReporting {
    func record(_ event: FoodLookupTelemetryEvent)
}

struct OSFoodLookupTelemetryReporter: FoodLookupTelemetryReporting {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "app.caloryn",
        category: "FoodLookup"
    )

    func record(_ event: FoodLookupTelemetryEvent) {
        let fallbackSuccess = event.fallbackSucceeded.map(String.init) ?? "not_applicable"
        logger.info(
            "lookup operation=\(event.operation.rawValue, privacy: .public) provider=\(event.provider.rawValue, privacy: .public) outcome=\(event.outcome.rawValue, privacy: .public) latency=\(event.latency.rawValue, privacy: .public) attempt=\(event.attempt, privacy: .public) fallback=\(event.isFallback, privacy: .public) fallback_success=\(fallbackSuccess, privacy: .public)"
        )
    }
}
