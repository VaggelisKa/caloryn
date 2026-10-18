import Foundation
import Testing
@testable import Caloryn

@MainActor
@Suite(.serialized)
struct FoodSearchServiceNetworkCoverageTests {
    nonisolated enum Reply: Sendable, CustomTestStringConvertible {
        case http(Int, String)
        case nonHTTP(String)
        case transport(URLError.Code)
        case foreignError

        var testDescription: String {
            switch self {
            case .http(let status, _): "HTTP \(status)"
            case .nonHTTP: "non-HTTP response"
            case .transport(let code): "URLError \(code.rawValue)"
            case .foreignError: "non-URL error"
            }
        }
    }

    nonisolated private static let barcode = "5711953150388"
    nonisolated private static let calorynHost = "caloryn-api.vercel.app"
    nonisolated private static let openFoodFactsSearchHost = "search.openfoodfacts.org"
    nonisolated private static let openFoodFactsBarcodeHost = "world.openfoodfacts.org"

    nonisolated private static let completeNutriments =
        #""energy-kcal_100g": 62, "proteins_100g": 11, "carbohydrates_100g": 4, "fat_100g": 0.2"#
    nonisolated private static let kilojouleOnlyNutriments = #""energy-kj_100g": 260, "proteins_100g": 11"#
    nonisolated private static let energylessNutriments = #""proteins_100g": 11"#

    nonisolated private static func barcodeBody(
        name: String = "Stub Skyr",
        nutriments: String = completeNutriments
    ) -> String {
        """
        {"code": "\(barcode)", "status": 1, "product": {"code": "\(barcode)", "product_name": "\(name)", "nutriments": {\(nutriments)}}}
        """
    }

    nonisolated private static let barcodeNotFoundBody = #"{"code": "5711953150388", "status": 0, "status_verbose": "product not found"}"#
    nonisolated private static let barcodeWithoutProductBody = #"{"code": "5711953150388", "status": 1, "product": null}"#

    nonisolated private static func hit(code: String, name: String, nutriments: String = completeNutriments) -> String {
        """
        {"code": "\(code)", "product_name": "\(name)", "nutriments": {\(nutriments)}}
        """
    }

    nonisolated private static func searchBody(_ hits: String...) -> String {
        """
        {"hits": [\(hits.joined(separator: ", "))]}
        """
    }

    init() {
        FoodSearchNetworkCoverageStub.install(nil)
    }

    private func makeService(
        policy: FoodProviderPolicy? = nil,
        telemetry: FoodSearchNetworkTelemetryLog? = nil
    ) -> FoodSearchService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FoodSearchNetworkCoverageStub.self]
        return FoodSearchService(
            policy: policy ?? .automatic,
            session: URLSession(configuration: configuration),
            countryCode: "DK",
            telemetry: telemetry ?? FoodSearchNetworkTelemetryLog()
        )
    }

    private func lookupError(_ service: FoodSearchService, barcode: String = barcode) async -> (any Error)? {
        do {
            _ = try await service.lookupBarcode(barcode)
            return nil
        } catch {
            return error
        }
    }

    private func searchError(_ service: FoodSearchService, query: String) async -> (any Error)? {
        do {
            _ = try await service.searchImmediately(query: query)
            return nil
        } catch {
            return error
        }
    }

    private func eventually(_ condition: () -> Bool) async -> Bool {
        for _ in 0..<250 {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return condition()
    }

    nonisolated private static func queryItems(_ request: URLRequest) -> [String: String] {
        guard let url = request.url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return [:] }
        return Dictionary(
            (components.queryItems ?? []).map { ($0.name, $0.value ?? "") },
            uniquingKeysWith: { first, _ in first }
        )
    }

    @Test(
        "Each HTTP status maps to one lookup failure, with no second attempt",
        arguments: [
            (401, FoodLookupError.unauthorized),
            (403, .unauthorized),
            (404, .notFound),
            (408, .unavailable),
            (418, .invalidRequest),
            (429, .rateLimited),
            (500, .unavailable),
            (503, .unavailable),
            (599, .unavailable),
            (600, .unavailable),
        ] as [(Int, FoodLookupError)]
    )
    func statusMapping(status: Int, expected: FoodLookupError) async {
        let log = FoodSearchNetworkRequestLog()
        let telemetry = FoodSearchNetworkTelemetryLog()
        FoodSearchNetworkCoverageStub.install { request in
            log.append(request)
            return .http(status, "{}")
        }
        let service = makeService(policy: .only(.calorynAPI), telemetry: telemetry)

        let error = await lookupError(service)

        #expect(error as? FoodLookupError == expected)
        #expect(log.requests.count == 1)
        #expect(telemetry.events.map(\.outcome) == [expected.outcome])
        #expect(telemetry.events.map(\.operation) == [.barcode])
        #expect(telemetry.events.map(\.provider) == [.calorynAPI])
    }

    @Test(
        "Each transport failure maps to one lookup failure",
        arguments: [
            (Reply.transport(.notConnectedToInternet), FoodLookupError.offline),
            (.transport(.internationalRoamingOff), .offline),
            (.transport(.dataNotAllowed), .offline),
            (.transport(.callIsActive), .offline),
            (.transport(.badURL), .invalidRequest),
            (.transport(.unsupportedURL), .invalidRequest),
            (.transport(.timedOut), .unavailable),
            (.transport(.cannotFindHost), .unavailable),
            (.transport(.cancelled), .cancelled),
            (.foreignError, .unavailable),
            (.nonHTTP("{}"), .unavailable),
        ] as [(Reply, FoodLookupError)]
    )
    func transportMapping(reply: Reply, expected: FoodLookupError) async {
        let telemetry = FoodSearchNetworkTelemetryLog()
        FoodSearchNetworkCoverageStub.install { _ in reply }
        let service = makeService(policy: .only(.calorynAPI), telemetry: telemetry)

        let error = await lookupError(service)

        #expect(error as? FoodLookupError == expected)
        #expect(telemetry.events.map(\.outcome) == [expected.outcome])
    }

    @Test(
        "A timeout or an unrecognised error falls back to the secondary provider",
        arguments: [Reply.transport(.timedOut), .foreignError, .nonHTTP("{}")]
    )
    func transientTransportFailureFallsBack(primaryReply: Reply) async throws {
        let log = FoodSearchNetworkRequestLog()
        let telemetry = FoodSearchNetworkTelemetryLog()
        let body = Self.barcodeBody(name: "Backup Skyr")
        FoodSearchNetworkCoverageStub.install { request in
            log.append(request)
            return request.url?.host == Self.calorynHost ? primaryReply : .http(200, body)
        }
        let service = makeService(telemetry: telemetry)

        let result = try await service.lookupBarcode(Self.barcode)

        #expect(log.requests.compactMap(\.url?.host) == [Self.calorynHost, Self.openFoodFactsBarcodeHost])
        #expect(result.product.productName == "Backup Skyr")
        #expect(result.provenance.provider == .openFoodFacts)
        #expect(result.provenance.recoveredByFallback)
        #expect(telemetry.events.map(\.outcome) == [.unavailable, .success])
    }

    @Test(
        "When both providers fail, the most actionable failure is reported",
        arguments: [
            (Reply.http(200, barcodeNotFoundBody), Reply.http(200, barcodeNotFoundBody), FoodLookupError.notFound),
            (.http(404, "{}"), .http(200, barcodeWithoutProductBody), .notFound),
            (.http(404, "{}"), .http(200, barcodeBody(nutriments: energylessNutriments)), .invalidData),
            (.http(200, "not json"), .http(404, "{}"), .invalidData),
            (.http(200, "not json"), .http(200, #"{"status": "1"}"#), .invalidData),
            (.http(200, barcodeBody(nutriments: energylessNutriments)), .http(503, "{}"), .unavailable),
            (.http(503, "{}"), .http(404, "{}"), .unavailable),
            (.http(404, "{}"), .nonHTTP("{}"), .unavailable),
            (.http(503, "{}"), .http(401, "{}"), .unauthorized),
            (.http(404, "{}"), .http(429, "{}"), .rateLimited),
            (.http(503, "{}"), .transport(.notConnectedToInternet), .offline),
            (.http(404, "{}"), .http(422, "{}"), .invalidRequest),
            (.http(503, "{}"), .http(422, "{}"), .invalidRequest),
            (.http(200, "not json"), .http(422, "{}"), .invalidRequest),
            (.http(503, "{}"), .transport(.cancelled), .cancelled),
        ] as [(Reply, Reply, FoodLookupError)]
    )
    func finalFailurePrecedence(primary: Reply, secondary: Reply, expected: FoodLookupError) async {
        let log = FoodSearchNetworkRequestLog()
        let telemetry = FoodSearchNetworkTelemetryLog()
        FoodSearchNetworkCoverageStub.install { request in
            log.append(request)
            return request.url?.host == Self.calorynHost ? primary : secondary
        }
        let service = makeService(telemetry: telemetry)

        let error = await lookupError(service)

        #expect(error as? FoodLookupError == expected)
        #expect(log.requests.count == 2)
        #expect(telemetry.events.map(\.attempt) == [1, 2])
        #expect(telemetry.events.map(\.isFallback) == [false, true])
        #expect(telemetry.events.map(\.fallbackSucceeded) == [nil, false])
    }

    @Test("A padded barcode is trimmed before it is sent to the primary provider")
    func barcodeRequestShape() async throws {
        let log = FoodSearchNetworkRequestLog()
        let body = Self.barcodeBody()
        FoodSearchNetworkCoverageStub.install { request in
            log.append(request)
            return .http(200, body)
        }
        let service = makeService()

        let result = try await service.lookupBarcode("  \(Self.barcode)\n")

        let request = try #require(log.requests.first)
        #expect(log.requests.count == 1)
        #expect(request.url?.absoluteString == "https://caloryn-api.vercel.app/api/v1/products/5711953150388")
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "User-Agent") == "Caloryn/1.0 (iOS; contact@caloryn.app)")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(result.provenance == FoodProvenance(
            provider: .calorynAPI,
            source: .calorynCatalog,
            completeness: .complete,
            recoveredByFallback: false
        ))
    }

    @Test("A community-only policy is the primary attempt, not a fallback")
    func communityOnlyBarcode() async throws {
        let log = FoodSearchNetworkRequestLog()
        let telemetry = FoodSearchNetworkTelemetryLog()
        let body = Self.barcodeBody(nutriments: #""energy-kcal_100g": 62, "proteins_100g": 11"#)
        FoodSearchNetworkCoverageStub.install { request in
            log.append(request)
            return .http(200, body)
        }
        let service = makeService(policy: .only(.openFoodFacts), telemetry: telemetry)

        let result = try await service.lookupBarcode(Self.barcode)

        #expect(log.requests.compactMap(\.url?.absoluteString) == [
            "https://world.openfoodfacts.org/api/v0/product/5711953150388.json",
        ])
        #expect(result.provenance == FoodProvenance(
            provider: .openFoodFacts,
            source: .openFoodFactsCommunity,
            completeness: .partial,
            recoveredByFallback: false
        ))
        #expect(telemetry.events.map(\.isFallback) == [false])
        #expect(telemetry.events.map(\.fallbackSucceeded) == [nil])
    }

    @Test("A product with energy only in kilojoules scans, converted to kilocalories")
    func kilojouleOnlyBarcode() async throws {
        FoodSearchNetworkCoverageStub.install { _ in
            .http(200, Self.barcodeBody(nutriments: Self.kilojouleOnlyNutriments))
        }
        let service = makeService(policy: .only(.calorynAPI))

        let result = try await service.lookupBarcode(Self.barcode)

        let kcal = try #require(result.product.nutriments?.energyKcal100g)
        #expect(abs(kcal - 62.141) < 0.001)
    }

    @Test("A product with no energy at all is rejected as unusable")
    func energylessBarcode() async {
        FoodSearchNetworkCoverageStub.install { _ in
            .http(200, Self.barcodeBody(nutriments: Self.energylessNutriments))
        }
        let service = makeService(policy: .only(.calorynAPI))

        #expect(await lookupError(service) as? FoodLookupError == .invalidData)
    }

    @Test("Community search asks for the app's fields, page size and languages")
    func communitySearchRequestShape() async throws {
        let log = FoodSearchNetworkRequestLog()
        let body = Self.searchBody(Self.hit(code: "111", name: "Community Oats"))
        FoodSearchNetworkCoverageStub.install { request in
            log.append(request)
            return .http(200, body)
        }
        let service = makeService(policy: .only(.openFoodFacts))

        let results = try await service.searchImmediately(query: "  rolled oats ")

        let request = try #require(log.requests.first)
        let items = Self.queryItems(request)
        let languages = (items["langs"] ?? "").split(separator: ",").map(String.init)
        #expect(request.url?.host == Self.openFoodFactsSearchHost)
        #expect(request.url?.path == "/search")
        #expect(items["q"] == "rolled oats")
        #expect(items["page_size"] == "30")
        #expect(items["fields"] == [
            "code", "product_name", "brands", "serving_size", "serving_quantity", "product_quantity",
            "quantity", "nutriments", "nutrition_grades", "categories_tags", "lang", "countries_tags",
        ].joined(separator: ","))
        #expect(items["country"] == nil)
        #expect(items["limit"] == nil)
        #expect(languages.contains("en"))
        #expect(Set(languages).count == languages.count)
        #expect(languages.allSatisfy { $0 == $0.lowercased() && !$0.contains("-") && !$0.contains("_") })
        #expect(results.map(\.provenance.source) == [.openFoodFactsCommunity])
        #expect(results.map(\.provenance.recoveredByFallback) == [false])
    }

    @Test("A blank query is rejected before any provider is asked")
    func blankQuery() async {
        let log = FoodSearchNetworkRequestLog()
        let telemetry = FoodSearchNetworkTelemetryLog()
        FoodSearchNetworkCoverageStub.install { request in
            log.append(request)
            return .http(200, "{}")
        }
        let service = makeService(telemetry: telemetry)

        #expect(await searchError(service, query: " \n\t ") as? FoodLookupError == .invalidRequest)
        #expect(log.requests.isEmpty)
        #expect(telemetry.events.isEmpty)
    }

    @Test("A search response that is not JSON is invalid data")
    func malformedSearchResponse() async {
        FoodSearchNetworkCoverageStub.install { _ in .http(200, "<html>maintenance</html>") }
        let service = makeService(policy: .only(.calorynAPI))

        #expect(await searchError(service, query: "oats") as? FoodLookupError == .invalidData)
    }

    @Test("Search keeps only hits with a name and energy, and fails when none remain")
    func unusableHitsAreDropped() async throws {
        let mixed = Self.searchBody(
            Self.hit(code: "201", name: "Energyless Oats", nutriments: Self.energylessNutriments),
            Self.hit(code: "202", name: "Usable Oats", nutriments: #""energy-kcal_100g": 370, "fat_100g": 7"#),
            Self.hit(code: "203", name: " ", nutriments: Self.completeNutriments)
        )
        let unusable = Self.searchBody(
            Self.hit(code: "301", name: "Energyless Oats", nutriments: Self.energylessNutriments)
        )
        FoodSearchNetworkCoverageStub.install { request in
            .http(200, Self.queryItems(request)["q"] == "mixed" ? mixed : unusable)
        }
        let service = makeService(policy: .only(.calorynAPI))

        let results = try await service.searchImmediately(query: "mixed")

        #expect(results.map(\.product.productName) == ["Usable Oats"])
        #expect(results.map(\.provenance.completeness) == [.partial])
        #expect(await searchError(service, query: "unusable") as? FoodLookupError == .invalidData)
    }

    @Test("Duplicate hits collapse to the richest one, and a tie keeps the first")
    func duplicateHitsCollapse() async throws {
        let body = Self.searchBody(
            Self.hit(code: "901", name: "First Tie", nutriments: #""energy-kcal_100g": 370"#),
            Self.hit(code: "901", name: "Second Tie", nutriments: #""energy-kcal_100g": 380"#),
            Self.hit(code: "902", name: "Sparse Oats", nutriments: #""energy-kcal_100g": 370"#),
            Self.hit(code: "902", name: "Rich Oats", nutriments: Self.completeNutriments),
            Self.hit(code: "902", name: "Late Sparse Oats", nutriments: #""energy-kcal_100g": 370"#)
        )
        FoodSearchNetworkCoverageStub.install { _ in .http(200, body) }
        let service = makeService(policy: .only(.calorynAPI))

        let results = try await service.searchImmediately(query: "oats")

        #expect(results.map(\.product.productName) == ["First Tie", "Rich Oats"])
    }

    @Test("A string-typed nutrient keeps its hit and every other hit in the response")
    func stringTypedHitIsKept() async throws {
        let body = Self.searchBody(
            Self.hit(code: "401", name: "Fine Oats"),
            Self.hit(code: "402", name: "Stringly Oats", nutriments: #""energy-kcal_100g": "370""#)
        )
        FoodSearchNetworkCoverageStub.install { _ in .http(200, body) }
        let service = makeService(policy: .only(.calorynAPI))

        let results = try await service.searchImmediately(query: "oats")

        #expect(Set(results.compactMap(\.product.productName)) == ["Fine Oats", "Stringly Oats"])
        #expect(results.first { $0.product.code == "402" }?.product.nutriments?.energyKcal100g == 370)
    }

    @Test("Search fallback is reported as a second, successful search attempt")
    func searchFallbackTelemetry() async throws {
        let telemetry = FoodSearchNetworkTelemetryLog()
        let body = Self.searchBody(Self.hit(code: "501", name: "Community Rye"))
        FoodSearchNetworkCoverageStub.install { request in
            request.url?.host == Self.calorynHost ? .http(404, "{}") : .http(200, body)
        }
        let service = makeService(telemetry: telemetry)

        let results = try await service.searchImmediately(query: "rye")

        #expect(results.map(\.provenance.provider) == [.openFoodFacts])
        #expect(results.map(\.provenance.recoveredByFallback) == [true])
        #expect(telemetry.events.map(\.operation) == [.search, .search])
        #expect(telemetry.events.map(\.provider) == [.calorynAPI, .openFoodFacts])
        #expect(telemetry.events.map(\.outcome) == [.notFound, .success])
        #expect(telemetry.events.map(\.fallbackSucceeded) == [nil, true])
    }

    @Test("A lookup started in an already-cancelled task stops before any request")
    func preCancelledLookup() async {
        let log = FoodSearchNetworkRequestLog()
        let telemetry = FoodSearchNetworkTelemetryLog()
        FoodSearchNetworkCoverageStub.install { request in
            log.append(request)
            return .http(200, Self.barcodeBody())
        }
        let service = makeService(telemetry: telemetry)

        let task = Task { () -> (any Error)? in
            withUnsafeCurrentTask { $0?.cancel() }
            return await lookupError(service)
        }
        let error = await task.value

        #expect(error is CancellationError)
        #expect(log.requests.isEmpty)
        #expect(telemetry.events.isEmpty)
    }

    @Test("Cancelling an in-flight lookup reports cancellation and never falls back")
    func inFlightCancellation() async {
        let log = FoodSearchNetworkRequestLog()
        let telemetry = FoodSearchNetworkTelemetryLog()
        let cancel = FoodSearchNetworkCancelHandle()
        FoodSearchNetworkCoverageStub.install { request in
            log.append(request)
            cancel.fire()
            return .http(200, Self.barcodeBody())
        }
        let service = makeService(telemetry: telemetry)

        let task = Task { await lookupError(service) }
        cancel.set { task.cancel() }
        let error = await task.value

        #expect(error as? FoodLookupError == .cancelled)
        #expect(log.requests.compactMap(\.url?.host) == [Self.calorynHost])
        #expect(telemetry.events.map(\.outcome) == [.cancelled])
    }

    @Test("A typed search publishes its results once the debounce settles")
    func debouncedSearchPublishesResults() async {
        let body = Self.searchBody(
            Self.hit(code: "601", name: "Greek Yogurt"),
            Self.hit(code: "602", name: "Skyr", nutriments: #""energy-kcal_100g": 62"#)
        )
        FoodSearchNetworkCoverageStub.install { _ in .http(200, body) }
        let service = makeService(policy: .only(.calorynAPI))

        service.search(query: "yogurt")
        #expect(service.isSearching)

        #expect(await eventually { !service.isSearching })
        #expect(service.searchResults.map(\.product.productName) == ["Greek Yogurt", "Skyr"])
        #expect(service.searchResults.map(\.provenance.completeness) == [.complete, .partial])
        #expect(service.failure == nil)
        #expect(service.errorMessage == nil)
    }

    @Test("Typing again before the debounce settles sends only the newer query")
    func newerQuerySupersedesOlder() async {
        let log = FoodSearchNetworkRequestLog()
        FoodSearchNetworkCoverageStub.install { request in
            log.append(request)
            let query = Self.queryItems(request)["q"] ?? ""
            return .http(200, Self.searchBody(Self.hit(code: "7\(query.count)", name: "Result for \(query)")))
        }
        let service = makeService(policy: .only(.calorynAPI))

        service.search(query: "app")
        service.search(query: "apple")

        #expect(await eventually { !service.isSearching })
        #expect(log.requests.map { Self.queryItems($0)["q"] } == ["apple"])
        #expect(service.searchResults.map(\.product.productName) == ["Result for apple"])
    }

    @Test("A failed search replaces earlier results with the failure message")
    func debouncedSearchFailure() async {
        let body = Self.searchBody(Self.hit(code: "801", name: "Bread"))
        FoodSearchNetworkCoverageStub.install { request in
            Self.queryItems(request)["q"] == "bread" ? .http(200, body) : .http(429, "{}")
        }
        let service = makeService(policy: .only(.calorynAPI))

        service.search(query: "bread")
        #expect(await eventually { !service.isSearching })
        #expect(service.searchResults.count == 1)

        service.search(query: "butter")
        #expect(service.isSearching)
        #expect(await eventually { !service.isSearching })

        #expect(service.searchResults.isEmpty)
        #expect(service.failure == .rateLimited)
        #expect(service.errorMessage == "The food database is receiving too many requests. Try again in a few minutes.")

        service.search(query: "bread")
        #expect(service.failure == nil)
        #expect(service.errorMessage == nil)
        #expect(service.isSearching)
        #expect(await eventually { !service.isSearching })
        #expect(service.searchResults.map(\.product.productName) == ["Bread"])
    }

    @Test("A request cancelled underneath a live search ends it as cancelled")
    func transportCancellationEndsTheSearch() async {
        let telemetry = FoodSearchNetworkTelemetryLog()
        FoodSearchNetworkCoverageStub.install { _ in .transport(.cancelled) }
        let service = makeService(policy: .only(.calorynAPI), telemetry: telemetry)

        service.search(query: "porridge")

        #expect(await eventually { !service.isSearching })
        #expect(telemetry.events.map(\.outcome) == [.cancelled])
        #expect(service.failure == .cancelled)
        #expect(service.errorMessage == "The lookup was cancelled.")
        #expect(service.searchResults.isEmpty)
    }
}

nonisolated private final class FoodSearchNetworkCoverageStub: URLProtocol {
    typealias Handler = @Sendable (URLRequest) -> FoodSearchServiceNetworkCoverageTests.Reply

    nonisolated private static let lock = NSLock()
    nonisolated(unsafe) private static var handler: Handler?

    static func install(_ handler: Handler?) {
        lock.lock()
        self.handler = handler
        lock.unlock()
    }

    nonisolated private static func currentHandler() -> Handler? {
        lock.lock()
        defer { lock.unlock() }
        return handler
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.currentHandler(), let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }

        switch handler(request) {
        case .http(let status, let body):
            guard let response = HTTPURLResponse(
                url: url,
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            ) else {
                client?.urlProtocol(self, didFailWithError: URLError(.unknown))
                return
            }
            deliver(response, body: body)
        case .nonHTTP(let body):
            let response = URLResponse(
                url: url,
                mimeType: "application/json",
                expectedContentLength: body.utf8.count,
                textEncodingName: nil
            )
            deliver(response, body: body)
        case .transport(let code):
            client?.urlProtocol(self, didFailWithError: URLError(code))
        case .foreignError:
            client?.urlProtocol(
                self,
                didFailWithError: NSError(domain: "FoodSearchNetworkCoverageStub", code: 7)
            )
        }
    }

    override func stopLoading() {}

    private func deliver(_ response: URLResponse, body: String) {
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}

nonisolated private final class FoodSearchNetworkRequestLog: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [URLRequest] = []

    func append(_ request: URLRequest) {
        lock.lock()
        stored.append(request)
        lock.unlock()
    }

    var requests: [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }
}

nonisolated private final class FoodSearchNetworkCancelHandle: @unchecked Sendable {
    private let lock = NSLock()
    private var action: (@Sendable () -> Void)?

    func set(_ action: @escaping @Sendable () -> Void) {
        lock.lock()
        self.action = action
        lock.unlock()
    }

    func fire() {
        lock.lock()
        let action = self.action
        lock.unlock()
        action?()
    }
}

@MainActor
private final class FoodSearchNetworkTelemetryLog: FoodLookupTelemetryReporting {
    private(set) var events: [FoodLookupTelemetryEvent] = []

    func record(_ event: FoodLookupTelemetryEvent) {
        events.append(event)
    }
}
