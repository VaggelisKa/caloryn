import Foundation
import Testing
@testable import Caloryn

/// What a failed food lookup tells the user, and how it is reported.
///
/// Every `FoodLookupError` becomes a full-screen message on the food search
/// sheet, so each case's title, message, icon and retry affordance is pinned
/// here, together with the fallback and telemetry contracts it carries.
@MainActor
struct FoodLookupErrorCoverageTests {

    struct Expectation: Sendable, CustomTestStringConvertible {
        let error: FoodLookupError
        let title: String
        let message: String
        let systemImage: String
        let retryTitle: String?
        let permitsFallback: Bool
        let outcomeRaw: String

        var testDescription: String { "\(error)" }
    }

    static let matrix: [Expectation] = [
        Expectation(
            error: .cancelled,
            title: "Lookup cancelled",
            message: "The lookup was cancelled.",
            systemImage: "xmark.circle",
            retryTitle: nil,
            permitsFallback: false,
            outcomeRaw: "cancelled"
        ),
        Expectation(
            error: .offline,
            title: "You’re offline",
            message: "Reconnect to the internet, then try again.",
            systemImage: "wifi.slash",
            retryTitle: "Try again",
            permitsFallback: false,
            outcomeRaw: "offline"
        ),
        Expectation(
            error: .invalidRequest,
            title: "Invalid lookup",
            message: "Check the search or scan another barcode.",
            systemImage: "exclamationmark.magnifyingglass",
            retryTitle: nil,
            permitsFallback: false,
            outcomeRaw: "invalid_request"
        ),
        Expectation(
            error: .unauthorized,
            title: "Food search unavailable",
            message: "Caloryn cannot access the food database right now. Try again later.",
            systemImage: "lock.trianglebadge.exclamationmark",
            retryTitle: nil,
            permitsFallback: false,
            outcomeRaw: "unauthorized"
        ),
        Expectation(
            error: .rateLimited,
            title: "Search paused",
            message: "The food database is receiving too many requests. Try again in a few minutes.",
            systemImage: "hourglass",
            retryTitle: nil,
            permitsFallback: false,
            outcomeRaw: "rate_limited"
        ),
        Expectation(
            error: .notFound,
            title: "No results",
            message: "Try a different search term or scan another barcode.",
            systemImage: "magnifyingglass",
            retryTitle: nil,
            permitsFallback: true,
            outcomeRaw: "not_found"
        ),
        Expectation(
            error: .invalidData,
            title: "Nutrition details missing",
            message: "The product was found, but its nutrition data could not be used. Try another result.",
            systemImage: "exclamationmark.triangle",
            retryTitle: "Try again",
            permitsFallback: true,
            outcomeRaw: "invalid_data"
        ),
        Expectation(
            error: .unavailable,
            title: "Food search unavailable",
            message: "The food databases did not respond. Try again in a moment.",
            systemImage: "server.rack",
            retryTitle: "Try again",
            permitsFallback: true,
            outcomeRaw: "unavailable"
        ),
    ]

    // MARK: - Presentation

    @Test("Each failure shows its own title, message, icon and retry button", arguments: matrix)
    func presentation(_ expected: Expectation) {
        let presentation = expected.error.presentation

        #expect(presentation.title == expected.title)
        #expect(presentation.message == expected.message)
        #expect(presentation.systemImage == expected.systemImage)
        #expect(presentation.retryTitle == expected.retryTitle)
    }

    @Test("The localized description is the presentation message", arguments: matrix)
    func localizedDescription(_ expected: Expectation) {
        #expect(expected.error.errorDescription == expected.message)
        #expect((expected.error as Error).localizedDescription == expected.message)
    }

    @Test("A name search shows the generic presentation for every failure", arguments: matrix)
    func searchPresentationIsGeneric(_ expected: Expectation) {
        #expect(expected.error.presentation(for: .search) == expected.error.presentation)
    }

    @Test("A barcode lookup rewords only not-found and invalid-request", arguments: matrix)
    func barcodePresentation(_ expected: Expectation) {
        let barcode = expected.error.presentation(for: .barcode)

        switch expected.error {
        case .notFound:
            #expect(barcode == FoodLookupFailurePresentation(
                title: "Barcode not found",
                message: "This barcode isn’t in our food database.",
                systemImage: "barcode.viewfinder",
                retryTitle: nil
            ))
        case .invalidRequest:
            #expect(barcode == FoodLookupFailurePresentation(
                title: "Barcode couldn’t be read",
                message: "This doesn’t appear to be a valid product barcode.",
                systemImage: "barcode.viewfinder",
                retryTitle: nil
            ))
        default:
            #expect(barcode == expected.error.presentation)
        }
    }

    @Test("Only a cancelled lookup survives the user starting a name search", arguments: matrix)
    func dismissal(_ expected: Expectation) {
        #expect(expected.error.dismissesWhenNameSearchBegins == (expected.error != .cancelled))
    }

    // MARK: - Fallback and telemetry contracts

    @Test("Only content failures may fall back to the secondary provider", arguments: matrix)
    func fallbackPermission(_ expected: Expectation) {
        #expect(expected.error.permitsFallback == expected.permitsFallback)
    }

    @Test("Each failure reports a stable telemetry outcome", arguments: matrix)
    func telemetryOutcome(_ expected: Expectation) {
        #expect(expected.error.outcome.rawValue == expected.outcomeRaw)
    }

    @Test("A successful lookup reports the success outcome")
    func successOutcome() {
        #expect(FoodLookupOutcome.success.rawValue == "success")
    }

    // MARK: - Latency classes

    @Test(
        "Latency is bucketed at 500 ms and 2 s",
        arguments: [
            (Duration.zero, FoodLookupLatencyClass.fast),
            (.milliseconds(499), .fast),
            (.milliseconds(500), .moderate),
            (.milliseconds(1_999), .moderate),
            (.seconds(2), .slow),
            (.seconds(30), .slow),
        ] as [(Duration, FoodLookupLatencyClass)]
    )
    func latencyClass(elapsed: Duration, expected: FoodLookupLatencyClass) {
        #expect(FoodLookupLatencyClass(elapsed: elapsed) == expected)
    }

    @Test("Latency classes report stable raw values")
    func latencyRawValues() {
        #expect(FoodLookupLatencyClass.fast.rawValue == "fast")
        #expect(FoodLookupLatencyClass.moderate.rawValue == "moderate")
        #expect(FoodLookupLatencyClass.slow.rawValue == "slow")
    }
}
