import XCTest
@testable import Caloryn

@MainActor
final class FoodSearchServiceTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testDefaultSearchUsesCalorynAPI() async throws {
        let requestReceived = expectation(description: "Caloryn API request")
        URLProtocolStub.requestHandler = { request in
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
            XCTAssertNil(queryItems["fields"])
            requestReceived.fulfill()

            return (
                HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!,
                Data(
                    """
                    {
                      "attribution": "Contains information from Open Food Facts",
                      "count": 1,
                      "hits": [{
                        "code": "123",
                        "product_name": "Greek Yogurt",
                        "brands": "Test Dairy",
                        "nutriments": { "energy-kcal_100g": 100 }
                      }]
                    }
                    """.utf8
                )
            )
        }

        let service = FoodSearchService(session: makeStubbedSession())
        service.search(query: "greek yogurt")

        await fulfillment(of: [requestReceived], timeout: 2)
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(service.searchResults.first?.productName, "Greek Yogurt")
        XCTAssertNil(service.errorMessage)
        XCTAssertFalse(service.isSearching)
    }

    func testDefaultBarcodeLookupUsesCalorynAPI() async throws {
        URLProtocolStub.requestHandler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://caloryn-api.vercel.app/api/v1/products/5711953150388")
            return (
                HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(
                    """
                    {
                      "code": "5711953150388",
                      "status": 1,
                      "product": {
                        "code": "5711953150388",
                        "product_name": "Chocolate Milk",
                        "nutriments": { "energy-kcal_100g": 72 }
                      }
                    }
                    """.utf8
                )
            )
        }

        let service = FoodSearchService(session: makeStubbedSession())
        let product = try await service.lookupBarcode("5711953150388")

        XCTAssertEqual(product.productName, "Chocolate Milk")
    }

    func testOpenFoodFactsProviderRemainsAvailable() async throws {
        URLProtocolStub.requestHandler = { request in
            XCTAssertEqual(
                request.url?.absoluteString,
                "https://world.openfoodfacts.org/api/v0/product/123456.json"
            )
            return (
                HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(
                    """
                    {
                      "code": "123456",
                      "status": 1,
                      "product": {
                        "code": "123456",
                        "product_name": "Legacy Product",
                        "nutriments": { "energy-kcal_100g": 120 }
                      }
                    }
                    """.utf8
                )
            )
        }

        let service = FoodSearchService(
            provider: .openFoodFacts,
            session: makeStubbedSession()
        )
        let product = try await service.lookupBarcode("123456")

        XCTAssertEqual(product.productName, "Legacy Product")
    }

    func testOpenFoodFactsSearchProviderRemainsAvailable() async throws {
        let requestReceived = expectation(description: "Open Food Facts search request")
        URLProtocolStub.requestHandler = { request in
            XCTAssertEqual(request.url?.host, "search.openfoodfacts.org")
            XCTAssertEqual(request.url?.path, "/search")

            let components = try XCTUnwrap(
                URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)
            )
            let queryItems = Dictionary(
                uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") }
            )
            XCTAssertEqual(queryItems["q"], "legacy")
            XCTAssertEqual(queryItems["page_size"], "30")
            XCTAssertNotNil(queryItems["fields"])
            XCTAssertNotNil(queryItems["langs"])
            requestReceived.fulfill()

            return (
                HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(
                    """
                    {
                      "hits": [{
                        "code": "654321",
                        "product_name": "Legacy Search Product",
                        "nutriments": { "energy-kcal_100g": 90 }
                      }]
                    }
                    """.utf8
                )
            )
        }

        let service = FoodSearchService(
            provider: .openFoodFacts,
            session: makeStubbedSession()
        )
        service.search(query: "legacy")

        await fulfillment(of: [requestReceived], timeout: 2)
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(service.searchResults.first?.productName, "Legacy Search Product")
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
    }

    func testProductServingInfoFallsBackToPackQuantityString() throws {
        let product = try decodeProduct(
            """
            {
              "code": "987654",
              "product_name": "Small Pack",
              "quantity": "1 oz (28 g)",
              "nutriments": {
                "energy-kcal_100g": 500
              }
            }
            """
        )

        XCTAssertEqual(product.effectiveServingInfo.defaultServingG, 28)
        XCTAssertEqual(product.effectiveServingInfo.servingDescription, "1 pack (28g)")
        XCTAssertEqual(product.caloriesPerServing ?? -1, 140, accuracy: 0.001)
    }

    func testCreateFoodItemMapsNutritionServingNutriscoreAndProduceKind() throws {
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

        let food = FoodSearchService().createFoodItem(from: product)

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
        XCTAssertEqual(food.produceKind, .fruit)
    }

    func testClearResultsCancelsSearchState() throws {
        let service = FoodSearchService()
        service.searchResults = [
            try decodeProduct(
                """
                {
                  "code": "1",
                  "product_name": "Food",
                  "nutriments": {
                    "energy-kcal_100g": 100
                  }
                }
                """
            )
        ]
        service.isSearching = true
        service.errorMessage = "Network failed"

        service.clearResults()

        XCTAssertTrue(service.searchResults.isEmpty)
        XCTAssertFalse(service.isSearching)
        XCTAssertNil(service.errorMessage)
    }

    func testEmptySearchClearsPreviousError() {
        let service = FoodSearchService()
        service.errorMessage = "Network failed"

        service.search(query: "   ")

        XCTAssertNil(service.errorMessage)
        XCTAssertTrue(service.searchResults.isEmpty)
        XCTAssertFalse(service.isSearching)
    }

    private func makeStubbedSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: configuration)
    }

    private func decodeProduct(_ json: String) throws -> OpenFoodFactsProduct {
        try JSONDecoder().decode(OpenFoodFactsProduct.self, from: Data(json.utf8))
    }
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
