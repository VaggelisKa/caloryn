import XCTest
@testable import Caloryn

@MainActor
final class FoodSearchServiceTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testAutomaticPolicyIsBoundedAndOrdered() {
        XCTAssertEqual(FoodProviderPolicy.automatic.orderedProviders, [.calorynAPI, .openFoodFacts])
        XCTAssertEqual(
            FoodProviderPolicy(primary: .calorynAPI, secondary: .calorynAPI).orderedProviders,
            [.calorynAPI]
        )
    }

    func testBarcodeNotFoundPresentationHasNoRedundantAction() {
        let searchPresentation = FoodLookupError.notFound.presentation(for: .search)
        let barcodePresentation = FoodLookupError.notFound.presentation(for: .barcode)
        let invalidBarcodePresentation = FoodLookupError.invalidRequest.presentation(for: .barcode)

        XCTAssertEqual(searchPresentation.title, "No Results")
        XCTAssertNil(searchPresentation.retryTitle)
        XCTAssertEqual(barcodePresentation.title, "Barcode Not Found")
        XCTAssertEqual(
            barcodePresentation.message,
            "This barcode isn’t in our food database."
        )
        XCTAssertNil(barcodePresentation.retryTitle)
        XCTAssertNil(invalidBarcodePresentation.retryTitle)
        XCTAssertTrue(FoodLookupError.notFound.dismissesWhenNameSearchBegins)
        XCTAssertTrue(FoodLookupError.invalidRequest.dismissesWhenNameSearchBegins)
        XCTAssertFalse(FoodLookupError.unavailable.dismissesWhenNameSearchBegins)
    }

    func testContextualSuggestionRankingDoesNotInvokeFoodProviders() {
        var requestCount = 0
        URLProtocolStub.requestHandler = { request in
            requestCount += 1
            return try response(request, status: 200, body: #"{"hits":[]}"#)
        }
        let service = FoodSearchService(session: makeStubbedSession())
        let food = makeTestFoodItem(name: "Local oats")
        let destination = makeTestDate(year: 2026, month: 7, day: 22, hour: 8)
        let entries = (0..<3).map { offset in
            let date = Calendar.current.date(
                byAdding: .day,
                value: -offset,
                to: destination
            )!
            let entry = makeTestEntry(
                date: date,
                mealType: .breakfast,
                foodItem: food,
                portionGrams: 80
            )
            entry.createdAt = date
            return entry
        }

        let suggestions = ContextualFoodSuggestionAdapter.rank(
            foods: [food],
            entries: entries,
            destinationDate: destination,
            destinationMeal: .breakfast,
            now: destination
        )

        XCTAssertEqual(suggestions.map(\.foodID), [food.id])
        XCTAssertTrue(service.searchResults.isEmpty)
        XCTAssertEqual(requestCount, 0)
    }

    func testPrimarySearchSuccessDoesNotCallSecondary() async throws {
        let telemetry = RecordingTelemetryReporter()
        var requestCount = 0
        URLProtocolStub.requestHandler = { request in
            requestCount += 1
            XCTAssertEqual(request.url?.host, "caloryn-api.vercel.app")
            XCTAssertEqual(request.url?.path, "/api/v1/search")

            let components = try XCTUnwrap(
                URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)
            )
            let queryItems = Dictionary(
                uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") }
            )
            XCTAssertEqual(queryItems["q"], "greek yogurt")
            XCTAssertEqual(queryItems["limit"], "30")
            XCTAssertEqual(queryItems["country"], "DK")
            XCTAssertNil(queryItems["fields"])

            return try response(
                request,
                status: 200,
                body: self.searchBody(code: "123", name: "Greek Yogurt", complete: true)
            )
        }

        let service = FoodSearchService(
            session: makeStubbedSession(),
            countryCode: "dk",
            telemetry: telemetry
        )
        let results = try await service.searchImmediately(query: "greek yogurt")

        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(results.first?.product.productName, "Greek Yogurt")
        XCTAssertEqual(results.first?.provenance.provider, .calorynAPI)
        XCTAssertEqual(results.first?.provenance.source, .calorynCatalog)
        XCTAssertEqual(results.first?.provenance.completeness, .complete)
        XCTAssertEqual(results.first?.provenance.recoveredByFallback, false)
        XCTAssertEqual(telemetry.events.map(\.outcome), [.success])
    }

    func testSearchOmitsCountryWhenRegionIsUnavailableOrInvalid() async throws {
        for countryCode in [nil, "D1"] as [String?] {
            URLProtocolStub.requestHandler = { request in
                let components = try XCTUnwrap(
                    URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)
                )
                XCTAssertNil(components.queryItems?.first(where: { $0.name == "country" }))
                return try response(
                    request,
                    status: 200,
                    body: self.searchBody(code: "123", name: "Yogurt", complete: true)
                )
            }

            let service = FoodSearchService(
                policy: .only(.calorynAPI),
                session: makeStubbedSession(),
                countryCode: countryCode
            )
            _ = try await service.searchImmediately(query: "yogurt")
        }
    }

    func testBarcodeTransientFailureFallsBackExactlyOnce() async throws {
        let telemetry = RecordingTelemetryReporter()
        var requestedHosts: [String] = []
        URLProtocolStub.requestHandler = { request in
            requestedHosts.append(try XCTUnwrap(request.url?.host))
            if request.url?.host == "caloryn-api.vercel.app" {
                return try response(request, status: 503, body: "{}")
            }
            XCTAssertEqual(
                request.url?.absoluteString,
                "https://world.openfoodfacts.org/api/v0/product/5711953150388.json"
            )
            return try response(
                request,
                status: 200,
                body: self.barcodeBody(code: "5711953150388", name: "Recovered Milk", complete: true)
            )
        }

        let service = FoodSearchService(
            session: makeStubbedSession(),
            telemetry: telemetry
        )
        let result = try await service.lookupBarcode("5711953150388")

        XCTAssertEqual(requestedHosts, ["caloryn-api.vercel.app", "world.openfoodfacts.org"])
        XCTAssertEqual(result.product.productName, "Recovered Milk")
        XCTAssertEqual(result.provenance.provider, .openFoodFacts)
        XCTAssertEqual(result.provenance.source, .openFoodFactsCommunity)
        XCTAssertTrue(result.provenance.recoveredByFallback)
        XCTAssertEqual(telemetry.events.map(\.outcome), [.unavailable, .success])
        XCTAssertEqual(telemetry.events.map(\.attempt), [1, 2])
        XCTAssertEqual(telemetry.events.map(\.isFallback), [false, true])
        XCTAssertEqual(telemetry.events.last?.fallbackSucceeded, true)
    }

    func testSearchNotFoundFallsBackAndReturnsSecondaryResults() async throws {
        var requestCount = 0
        URLProtocolStub.requestHandler = { request in
            requestCount += 1
            if request.url?.host == "caloryn-api.vercel.app" {
                return try response(request, status: 200, body: #"{"hits": []}"#)
            }
            return try response(
                request,
                status: 200,
                body: self.searchBody(code: "456", name: "Community Result", complete: true)
            )
        }

        let service = FoodSearchService(session: makeStubbedSession())
        let results = try await service.searchImmediately(query: "rare food")

        XCTAssertEqual(requestCount, 2)
        XCTAssertEqual(results.first?.product.productName, "Community Result")
        XCTAssertEqual(results.first?.provenance.provider, .openFoodFacts)
        XCTAssertTrue(try XCTUnwrap(results.first).provenance.recoveredByFallback)
    }

    func testBothProvidersUnavailableReturnUnavailable() async {
        let telemetry = RecordingTelemetryReporter()
        var requestCount = 0
        URLProtocolStub.requestHandler = { request in
            requestCount += 1
            return try response(request, status: 503, body: "{}")
        }
        let service = FoodSearchService(
            session: makeStubbedSession(),
            telemetry: telemetry
        )

        await assertBarcodeFailure(.unavailable, from: service)

        XCTAssertEqual(requestCount, 2)
        XCTAssertEqual(telemetry.events.map(\.outcome), [.unavailable, .unavailable])
        XCTAssertEqual(telemetry.events.last?.fallbackSucceeded, false)
    }

    func testBothProvidersNotFoundReturnNotFound() async {
        var requestCount = 0
        URLProtocolStub.requestHandler = { request in
            requestCount += 1
            return try response(request, status: 404, body: "{}")
        }
        let service = FoodSearchService(session: makeStubbedSession())

        await assertBarcodeFailure(.notFound, from: service)
        XCTAssertEqual(requestCount, 2)
    }

    func testCancellationDoesNotFallBack() async {
        await assertNonFallbackTransportFailure(.cancelled, urlError: .cancelled)
    }

    func testOfflineDoesNotFallBack() async {
        await assertNonFallbackTransportFailure(.offline, urlError: .notConnectedToInternet)
    }

    func testAuthenticationFailureDoesNotFallBack() async {
        await assertNonFallbackHTTPFailure(.unauthorized, status: 401)
    }

    func testRateLimitDoesNotFallBack() async {
        await assertNonFallbackHTTPFailure(.rateLimited, status: 429)
    }

    func testInvalidRequestDoesNotFallBack() async {
        await assertNonFallbackHTTPFailure(.invalidRequest, status: 422)
    }

    func testMalformedProviderDataFallsBack() async throws {
        var requestCount = 0
        URLProtocolStub.requestHandler = { request in
            requestCount += 1
            if request.url?.host == "caloryn-api.vercel.app" {
                return try response(request, status: 200, body: #"{"unexpected": true}"#)
            }
            return try response(
                request,
                status: 200,
                body: self.barcodeBody(code: "123456", name: "Valid Backup", complete: false)
            )
        }
        let service = FoodSearchService(session: makeStubbedSession())

        let result = try await service.lookupBarcode("123456")

        XCTAssertEqual(requestCount, 2)
        XCTAssertEqual(result.product.productName, "Valid Backup")
        XCTAssertEqual(result.provenance.completeness, .partial)
    }

    func testInvalidBarcodeIsRejectedBeforeAnyProviderRequest() async {
        let telemetry = RecordingTelemetryReporter()
        var requestCount = 0
        URLProtocolStub.requestHandler = { request in
            requestCount += 1
            return try response(request, status: 200, body: "{}")
        }
        let service = FoodSearchService(
            session: makeStubbedSession(),
            telemetry: telemetry
        )

        do {
            _ = try await service.lookupBarcode("abc")
            XCTFail("Expected invalid request")
        } catch let error as FoodLookupError {
            XCTAssertEqual(error, .invalidRequest)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(requestCount, 0)
        XCTAssertTrue(telemetry.events.isEmpty)
    }

    func testArabicIndicBarcodeDigitsAreRejectedBeforeAnyProviderRequest() async {
        let telemetry = RecordingTelemetryReporter()
        var requestCount = 0
        URLProtocolStub.requestHandler = { request in
            requestCount += 1
            return try response(request, status: 200, body: "{}")
        }
        let service = FoodSearchService(
            session: makeStubbedSession(),
            telemetry: telemetry
        )

        do {
            _ = try await service.lookupBarcode("١٢٣٤٥٦٧٨")
            XCTFail("Expected invalid request")
        } catch let error as FoodLookupError {
            XCTAssertEqual(error, .invalidRequest)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(requestCount, 0)
        XCTAssertTrue(telemetry.events.isEmpty)
    }

    func testSearchDeduplicatesByBarcodeAndKeepsRicherProductInStablePosition() async throws {
        URLProtocolStub.requestHandler = { request in
            let body = """
            {
              "hits": [
                {
                  "code": "same-code",
                  "product_name": "Sparse Product",
                  "nutriments": { "energy-kcal_100g": 100 }
                },
                {
                  "code": "other-code",
                  "product_name": "Other Product",
                  "nutriments": {
                    "energy-kcal_100g": 200,
                    "proteins_100g": 5,
                    "carbohydrates_100g": 10,
                    "fat_100g": 3
                  }
                },
                {
                  "code": "same-code",
                  "product_name": "Rich Product",
                  "brands": "Better Data",
                  "nutriments": {
                    "energy-kcal_100g": 100,
                    "proteins_100g": 8,
                    "carbohydrates_100g": 12,
                    "fat_100g": 4,
                    "fiber_100g": 2
                  }
                }
              ]
            }
            """
            return try response(request, status: 200, body: body)
        }
        let service = FoodSearchService(
            policy: .only(.calorynAPI),
            session: makeStubbedSession()
        )

        let results = try await service.searchImmediately(query: "duplicate")

        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results.map(\.product.productName), ["Rich Product", "Other Product"])
        XCTAssertEqual(results.first?.provenance.completeness, .complete)
    }

    func testReconcileAcrossProvidersPrefersCompletenessThenPrimaryOnTie() throws {
        let sparse = try decodeProduct(
            #"{"code":"123","product_name":"Sparse","nutriments":{"energy-kcal_100g":100}}"#
        )
        let rich = try decodeProduct(
            #"{"code":"123","product_name":"Rich","nutriments":{"energy-kcal_100g":100,"proteins_100g":5,"carbohydrates_100g":10,"fat_100g":3}}"#
        )
        let primary = makeResult(sparse, provider: .calorynAPI)
        let secondary = makeResult(rich, provider: .openFoodFacts, fallback: true)

        let richerResult = FoodSearchService.reconcile([primary, secondary])
        let tieKeepsFirst = FoodSearchService.reconcile([secondary, secondary])

        XCTAssertEqual(richerResult.map(\.product.productName), ["Rich"])
        XCTAssertEqual(richerResult.first?.provenance.provider, .openFoodFacts)
        XCTAssertEqual(tieKeepsFirst.first?.provenance.provider, .openFoodFacts)
    }

    func testProductDecodingAcceptsStringNumbersBrandArraysAndServingFallbacks() throws {
        let product = try decodeProduct(
            """
            {
              "code": "123456",
              "product_name": "Protein Bar",
              "brands": ["Brand A", "Brand B"],
              "serving_size": "1 bar (50g)",
              "serving_quantity": "50",
              "quantity": "6 x 50 g",
              "nutrition_grades": "B",
              "categories_tags": ["en:snacks"],
              "nutriments": {
                "energy-kcal_100g": 220,
                "proteins_100g": 20,
                "carbohydrates_100g": 30,
                "fat_100g": 8
              }
            }
            """
        )

        XCTAssertEqual(product.id, "123456")
        XCTAssertEqual(product.brands, "Brand A, Brand B")
        XCTAssertEqual(product.servingQuantityG, 50)
        XCTAssertEqual(product.formattedServingDescription, "1 bar (50g)")
        XCTAssertEqual(product.effectiveServingInfo.defaultServingG, 50)
        XCTAssertEqual(product.effectiveServingInfo.servingDescription, "1 bar (50g)")
        XCTAssertEqual(product.caloriesPerServing ?? -1, 110, accuracy: 0.001)
        XCTAssertEqual(product.nutritionCompleteness, .complete)
    }

    func testProductServingInfoFallsBackToPackQuantityString() throws {
        let product = try decodeProduct(
            """
            {
              "code": "987654",
              "product_name": "Small Pack",
              "quantity": "1 oz (28 g)",
              "nutriments": { "energy-kcal_100g": 500 }
            }
            """
        )

        XCTAssertEqual(product.effectiveServingInfo.defaultServingG, 28)
        XCTAssertEqual(product.effectiveServingInfo.servingDescription, "1 pack (28g)")
        XCTAssertEqual(product.caloriesPerServing ?? -1, 140, accuracy: 0.001)
        XCTAssertEqual(product.missingCoreNutritionLabels, ["protein", "carbohydrates", "fat"])
    }

    func testCreateFoodItemMapsNutritionServingQualityAndProvenance() throws {
        let product = try decodeProduct(
            """
            {
              "code": "111",
              "product_name": "Apple Pack",
              "brands": "Fresh Farm",
              "product_quantity": "350",
              "nutrition_grades": "Z",
              "categories_tags": ["en:apples"],
              "nutriments": {
                "energy-kcal_100g": 52,
                "proteins_100g": 0.3,
                "carbohydrates_100g": 14,
                "fat_100g": 0.2,
                "fiber_100g": 2.4,
                "sugars_100g": 10.4,
                "sodium_100g": 0.001
              }
            }
            """
        )
        let provenance = FoodProvenance(
            provider: .openFoodFacts,
            source: .openFoodFactsCommunity,
            completeness: .complete,
            recoveredByFallback: true
        )

        let food = FoodSearchService().createFoodItem(
            from: FoodSearchResult(product: product, provenance: provenance)
        )

        XCTAssertEqual(food.name, "Apple Pack")
        XCTAssertEqual(food.brand, "Fresh Farm")
        XCTAssertEqual(food.barcode, "111")
        XCTAssertEqual(food.caloriesPer100g, 52)
        XCTAssertEqual(food.proteinPer100g, 0.3)
        XCTAssertEqual(food.carbsPer100g, 14)
        XCTAssertEqual(food.fatPer100g, 0.2)
        XCTAssertEqual(food.fiberPer100g, 2.4)
        XCTAssertEqual(food.sugarsPer100g, 10.4)
        XCTAssertEqual(food.sodiumPer100g, 0.001)
        XCTAssertEqual(food.defaultServingG, 350)
        XCTAssertEqual(food.servingDescription, "1 pack (350g)")
        XCTAssertNil(food.nutriscoreGrade)
        XCTAssertEqual(food.produceKind, ProduceKind.fruit)
        XCTAssertEqual(food.provenance, provenance)
    }

    func testTelemetrySchemaContainsOnlyAggregateOperationalDimensions() {
        let event = FoodLookupTelemetryEvent(
            operation: .search,
            provider: .calorynAPI,
            outcome: .success,
            latency: .fast,
            attempt: 1,
            isFallback: false,
            fallbackSucceeded: nil
        )

        XCTAssertEqual(
            Set(Mirror(reflecting: event).children.compactMap(\.label)),
            Set(["operation", "provider", "outcome", "latency", "attempt", "isFallback", "fallbackSucceeded"])
        )
    }

    func testClearAndEmptySearchResetStateWithoutSurfacingCancellation() {
        let service = FoodSearchService()
        service.search(query: "food")
        XCTAssertTrue(service.isSearching)

        service.clearResults()
        XCTAssertTrue(service.searchResults.isEmpty)
        XCTAssertFalse(service.isSearching)
        XCTAssertNil(service.failure)

        service.search(query: "   ")
        XCTAssertTrue(service.searchResults.isEmpty)
        XCTAssertFalse(service.isSearching)
        XCTAssertNil(service.failure)
    }

    private func assertNonFallbackTransportFailure(
        _ expected: FoodLookupError,
        urlError: URLError.Code
    ) async {
        let telemetry = RecordingTelemetryReporter()
        var requestCount = 0
        URLProtocolStub.requestHandler = { _ in
            requestCount += 1
            throw URLError(urlError)
        }
        let service = FoodSearchService(
            session: makeStubbedSession(),
            telemetry: telemetry
        )

        await assertBarcodeFailure(expected, from: service)
        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(telemetry.events.map(\.outcome), [expected.outcome])
    }

    private func assertNonFallbackHTTPFailure(
        _ expected: FoodLookupError,
        status: Int
    ) async {
        let telemetry = RecordingTelemetryReporter()
        var requestCount = 0
        URLProtocolStub.requestHandler = { request in
            requestCount += 1
            return try response(request, status: status, body: "{}")
        }
        let service = FoodSearchService(
            session: makeStubbedSession(),
            telemetry: telemetry
        )

        await assertBarcodeFailure(expected, from: service)
        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(telemetry.events.map(\.outcome), [expected.outcome])
    }

    private func assertBarcodeFailure(
        _ expected: FoodLookupError,
        from service: FoodSearchService,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await service.lookupBarcode("123456")
            XCTFail("Expected \(expected)", file: file, line: line)
        } catch let error as FoodLookupError {
            XCTAssertEqual(error, expected, file: file, line: line)
        } catch {
            XCTFail("Unexpected error: \(error)", file: file, line: line)
        }
    }

    private func makeStubbedSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: configuration)
    }

    private func decodeProduct(_ json: String) throws -> OpenFoodFactsProduct {
        try JSONDecoder().decode(OpenFoodFactsProduct.self, from: Data(json.utf8))
    }

    private func makeResult(
        _ product: OpenFoodFactsProduct,
        provider: FoodSearchProvider,
        fallback: Bool = false
    ) -> FoodSearchResult {
        FoodSearchResult(
            product: product,
            provenance: FoodProvenance(
                provider: provider,
                source: provider == .calorynAPI ? .calorynCatalog : .openFoodFactsCommunity,
                completeness: product.nutritionCompleteness,
                recoveredByFallback: fallback
            )
        )
    }

    private func searchBody(code: String, name: String, complete: Bool) -> String {
        let macros = complete
            ? #", "proteins_100g": 10, "carbohydrates_100g": 4, "fat_100g": 2"#
            : ""
        return """
        {
          "hits": [{
            "code": "\(code)",
            "product_name": "\(name)",
            "nutriments": { "energy-kcal_100g": 100\(macros) }
          }]
        }
        """
    }

    private func barcodeBody(code: String, name: String, complete: Bool) -> String {
        let macros = complete
            ? #", "proteins_100g": 10, "carbohydrates_100g": 4, "fat_100g": 2"#
            : ""
        return """
        {
          "code": "\(code)",
          "status": 1,
          "product": {
            "code": "\(code)",
            "product_name": "\(name)",
            "nutriments": { "energy-kcal_100g": 100\(macros) }
          }
        }
        """
    }
}

@MainActor
private final class RecordingTelemetryReporter: FoodLookupTelemetryReporting {
    private(set) var events: [FoodLookupTelemetryEvent] = []

    func record(_ event: FoodLookupTelemetryEvent) {
        events.append(event)
    }
}

private func response(
    _ request: URLRequest,
    status: Int,
    body: String
) throws -> (HTTPURLResponse, Data) {
    (
        HTTPURLResponse(
            url: try XCTUnwrap(request.url),
            statusCode: status,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!,
        Data(body.utf8)
    )
}

private final class URLProtocolStub: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let requestHandler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }

        do {
            let (response, data) = try requestHandler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
