import Foundation
import SwiftData

struct FoodSearchResult: Identifiable, Hashable {
    let product: OpenFoodFactsProduct
    let provenance: FoodProvenance

    var id: String { product.id }
}

@Observable
final class FoodSearchService {
    private(set) var searchResults: [FoodSearchResult] = []
    private(set) var isSearching = false
    private(set) var failure: FoodLookupError?

    var errorMessage: String? { failure?.presentation.message }

    private var searchTask: Task<Void, Never>?
    private let policy: FoodProviderPolicy
    private let session: URLSession
    private let countryCode: String?
    private let telemetry: any FoodLookupTelemetryReporting
    private let clock = ContinuousClock()

    private static let calorynAPIBaseURL = "https://caloryn-api.vercel.app"
    private static let openFoodFactsSearchBaseURL = "https://search.openfoodfacts.org"
    private static let openFoodFactsBarcodeBaseURL = "https://world.openfoodfacts.org"
    private static let userAgent = "Caloryn/1.0 (iOS; contact@caloryn.app)"

    private static let searchFields = [
        "code",
        "product_name",
        "brands",
        "serving_size",
        "serving_quantity",
        "product_quantity",
        "quantity",
        "nutriments",
        "nutrition_grades",
        "categories_tags",
        "lang",
        "countries_tags"
    ].joined(separator: ",")

    private static let pageSize = 30

    init(
        policy: FoodProviderPolicy = .automatic,
        session: URLSession = .shared,
        countryCode: String? = Locale.current.region?.identifier,
        telemetry: any FoodLookupTelemetryReporting = OSFoodLookupTelemetryReporter()
    ) {
        self.policy = policy
        self.session = session
        self.countryCode = Self.normalizedCountryCode(countryCode)
        self.telemetry = telemetry

        #if DEBUG
        applyDebugFixtureIfRequested()
        #endif
    }

    func search(query: String) {
        searchTask?.cancel()

        #if DEBUG
        // The in-flight fixture stays in flight: a real search resolves in milliseconds,
        // which is too fast for the screenshot harness to photograph.
        if Self.pinsSearchInFlight {
            isSearching = true
            return
        }
        #endif

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            isSearching = false
            failure = nil
            return
        }

        isSearching = true
        failure = nil

        searchTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(300))
                try Task.checkCancellation()
                await performSearch(query: trimmed)
            } catch {
                // Search cancellation is expected when the query changes or the view clears.
            }
        }
    }

    func searchImmediately(query: String) async throws -> [FoodSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw FoodLookupError.invalidRequest }

        let locale = SearchLocaleContext.current
        let attempt = try await executeWithFailover(operation: .search) { provider in
            try await self.fetchResults(
                query: trimmed,
                locale: locale,
                provider: provider
            )
        }

        let source = Self.dataSource(for: attempt.provider)
        return Self.reconcile(
            attempt.value.map { product in
                FoodSearchResult(
                    product: product,
                    provenance: FoodProvenance(
                        provider: attempt.provider,
                        source: source,
                        completeness: product.nutritionCompleteness,
                        recoveredByFallback: attempt.usedFallback
                    )
                )
            }
        )
    }

    func clearResults() {
        searchTask?.cancel()
        searchResults = []
        isSearching = false
        failure = nil
    }

    func lookupBarcode(_ code: String) async throws -> FoodSearchResult {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isValidBarcode(trimmed) else { throw FoodLookupError.invalidRequest }

        let attempt = try await executeWithFailover(operation: .barcode) { provider in
            try await self.fetchBarcode(trimmed, provider: provider)
        }

        return FoodSearchResult(
            product: attempt.value,
            provenance: FoodProvenance(
                provider: attempt.provider,
                source: Self.dataSource(for: attempt.provider),
                completeness: attempt.value.nutritionCompleteness,
                recoveredByFallback: attempt.usedFallback
            )
        )
    }

    func createFoodItem(from result: FoodSearchResult) -> FoodItem {
        let product = result.product
        let nutriments = product.nutriments
        let (defaultServingG, servingDescription) = product.effectiveServingInfo
        let food = FoodItem(
            name: product.productName ?? "Unknown",
            brand: product.brands,
            barcode: product.code,
            caloriesPer100g: nutriments?.energyKcal100g ?? 0,
            proteinPer100g: nutriments?.proteins100g ?? 0,
            carbsPer100g: nutriments?.carbohydrates100g ?? 0,
            fatPer100g: nutriments?.fat100g ?? 0,
            fiberPer100g: nutriments?.fiber100g ?? 0,
            sugarsPer100g: nutriments?.sugars100g,
            addedSugarsPer100g: nutriments?.addedSugars100g,
            sucrosePer100g: nutriments?.sucrose100g,
            glucosePer100g: nutriments?.glucose100g,
            fructosePer100g: nutriments?.fructose100g,
            lactosePer100g: nutriments?.lactose100g,
            maltosePer100g: nutriments?.maltose100g,
            maltodextrinsPer100g: nutriments?.maltodextrins100g,
            starchPer100g: nutriments?.starch100g,
            polyolsPer100g: nutriments?.polyols100g,
            saturatedFatPer100g: nutriments?.saturatedFat100g,
            transFatPer100g: nutriments?.transFat100g,
            monounsaturatedFatPer100g: nutriments?.monounsaturatedFat100g,
            polyunsaturatedFatPer100g: nutriments?.polyunsaturatedFat100g,
            omega3FatPer100g: nutriments?.omega3Fat100g,
            omega6FatPer100g: nutriments?.omega6Fat100g,
            omega9FatPer100g: nutriments?.omega9Fat100g,
            saltPer100g: nutriments?.salt100g,
            sodiumPer100g: nutriments?.sodium100g,
            cholesterolPer100g: nutriments?.cholesterol100g,
            solubleFiberPer100g: nutriments?.solubleFiber100g,
            insolubleFiberPer100g: nutriments?.insolubleFiber100g,
            caseinPer100g: nutriments?.casein100g,
            serumProteinsPer100g: nutriments?.serumProteins100g,
            alcoholPer100g: nutriments?.alcohol100g,
            defaultServingG: defaultServingG,
            servingDescription: servingDescription,
            nutriscoreGrade: Self.validNutriscoreGrade(product.nutritionGrades),
            categoryTags: product.categoryTags ?? [],
            provenance: result.provenance
        )
        food.configureProviderMaterialization(from: result)
        return food
    }

    private func performSearch(query: String) async {
        do {
            let results = try await searchImmediately(query: query)
            guard !Task.isCancelled else { return }

            searchResults = results
            isSearching = false
            failure = nil
        } catch let lookupError as FoodLookupError {
            guard !Task.isCancelled, lookupError != .cancelled else { return }

            searchResults = []
            isSearching = false
            failure = lookupError
        } catch {
            guard !Task.isCancelled else { return }

            searchResults = []
            isSearching = false
            failure = .unavailable
        }
    }

    private func executeWithFailover<Value>(
        operation: FoodLookupOperation,
        request: (FoodSearchProvider) async throws -> Value
    ) async throws -> (value: Value, provider: FoodSearchProvider, usedFallback: Bool) {
        var failures: [FoodLookupError] = []

        for (index, provider) in policy.orderedProviders.enumerated() {
            try Task.checkCancellation()
            let startedAt = clock.now
            let isFallback = index > 0

            do {
                let value = try await request(provider)
                try Task.checkCancellation()
                telemetry.record(
                    FoodLookupTelemetryEvent(
                        operation: operation,
                        provider: provider,
                        outcome: .success,
                        latency: FoodLookupLatencyClass(elapsed: startedAt.duration(to: clock.now)),
                        attempt: index + 1,
                        isFallback: isFallback,
                        fallbackSucceeded: isFallback ? true : nil
                    )
                )
                return (value, provider, isFallback)
            } catch {
                let lookupError = Self.classify(error)
                failures.append(lookupError)
                telemetry.record(
                    FoodLookupTelemetryEvent(
                        operation: operation,
                        provider: provider,
                        outcome: lookupError.outcome,
                        latency: FoodLookupLatencyClass(elapsed: startedAt.duration(to: clock.now)),
                        attempt: index + 1,
                        isFallback: isFallback,
                        fallbackSucceeded: isFallback ? false : nil
                    )
                )

                let hasSecondaryAttempt = index + 1 < policy.orderedProviders.count
                guard lookupError.permitsFallback, hasSecondaryAttempt else {
                    throw Self.finalFailure(from: failures)
                }
            }
        }

        throw Self.finalFailure(from: failures)
    }

    private func fetchResults(
        query: String,
        locale: SearchLocaleContext,
        provider: FoodSearchProvider
    ) async throws -> [OpenFoodFactsProduct] {
        let components: URLComponents?
        switch provider {
        case .calorynAPI:
            var calorynComponents = URLComponents(string: "\(Self.calorynAPIBaseURL)/api/v1/search")
            var queryItems = [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "limit", value: String(Self.pageSize))
            ]
            if let countryCode {
                queryItems.append(URLQueryItem(name: "country", value: countryCode))
            }
            calorynComponents?.queryItems = queryItems
            components = calorynComponents

        case .openFoodFacts:
            var offComponents = URLComponents(string: "\(Self.openFoodFactsSearchBaseURL)/search")
            offComponents?.queryItems = [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "fields", value: Self.searchFields),
                URLQueryItem(name: "page_size", value: String(Self.pageSize)),
                URLQueryItem(name: "langs", value: locale.preferredLanguageCodes.joined(separator: ","))
            ]
            components = offComponents
        }

        guard let url = components?.url else { throw FoodLookupError.invalidRequest }
        let data = try await responseData(for: request(url: url))
        let decodedResponse: SearchResponse
        do {
            decodedResponse = try JSONDecoder().decode(SearchResponse.self, from: data)
        } catch {
            throw FoodLookupError.invalidData
        }

        guard !decodedResponse.hits.isEmpty else { throw FoodLookupError.notFound }
        let validProducts = decodedResponse.hits.filter(\.hasMinimumUsableNutrition)
        guard !validProducts.isEmpty else { throw FoodLookupError.invalidData }
        return Self.deduplicate(validProducts)
    }

    private func fetchBarcode(
        _ code: String,
        provider: FoodSearchProvider
    ) async throws -> OpenFoodFactsProduct {
        let encodedCode = code.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? code
        let urlString: String
        switch provider {
        case .calorynAPI:
            urlString = "\(Self.calorynAPIBaseURL)/api/v1/products/\(encodedCode)"
        case .openFoodFacts:
            urlString = "\(Self.openFoodFactsBarcodeBaseURL)/api/v0/product/\(encodedCode).json"
        }

        guard let url = URL(string: urlString) else { throw FoodLookupError.invalidRequest }
        let data = try await responseData(for: request(url: url))
        let decodedResponse: BarcodeLookupResponse
        do {
            decodedResponse = try JSONDecoder().decode(BarcodeLookupResponse.self, from: data)
        } catch {
            throw FoodLookupError.invalidData
        }

        guard decodedResponse.status == 1, let product = decodedResponse.product else {
            throw FoodLookupError.notFound
        }
        guard product.hasMinimumUsableNutrition else { throw FoodLookupError.invalidData }
        return product
    }

    private func request(url: URL) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: 8)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func responseData(for request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw FoodLookupError.unavailable
            }

            switch httpResponse.statusCode {
            case 200..<300:
                return data
            case 401, 403:
                throw FoodLookupError.unauthorized
            case 404:
                throw FoodLookupError.notFound
            case 408, 500...599:
                throw FoodLookupError.unavailable
            case 429:
                throw FoodLookupError.rateLimited
            case 400..<500:
                throw FoodLookupError.invalidRequest
            default:
                throw FoodLookupError.unavailable
            }
        } catch {
            throw Self.classify(error)
        }
    }

    static func reconcile(_ results: [FoodSearchResult]) -> [FoodSearchResult] {
        var reconciled: [FoodSearchResult] = []
        var indexes: [String: Int] = [:]

        for result in results {
            let key = result.product.reconciliationKey
            guard let existingIndex = indexes[key] else {
                indexes[key] = reconciled.count
                reconciled.append(result)
                continue
            }

            let existing = reconciled[existingIndex]
            if result.product.richnessScore > existing.product.richnessScore {
                reconciled[existingIndex] = result
            }
        }

        return reconciled
    }

    private static func deduplicate(_ products: [OpenFoodFactsProduct]) -> [OpenFoodFactsProduct] {
        var deduplicated: [OpenFoodFactsProduct] = []
        var indexes: [String: Int] = [:]

        for product in products {
            let key = product.reconciliationKey
            guard let existingIndex = indexes[key] else {
                indexes[key] = deduplicated.count
                deduplicated.append(product)
                continue
            }

            if product.richnessScore > deduplicated[existingIndex].richnessScore {
                deduplicated[existingIndex] = product
            }
        }

        return deduplicated
    }

    private static func classify(_ error: Error) -> FoodLookupError {
        if let lookupError = error as? FoodLookupError {
            return lookupError
        }
        if error is CancellationError {
            return .cancelled
        }
        guard let urlError = error as? URLError else {
            return .unavailable
        }

        switch urlError.code {
        case .cancelled:
            return .cancelled
        case .notConnectedToInternet, .internationalRoamingOff, .dataNotAllowed, .callIsActive:
            return .offline
        case .badURL, .unsupportedURL:
            return .invalidRequest
        default:
            return .unavailable
        }
    }

    private static func finalFailure(from failures: [FoodLookupError]) -> FoodLookupError {
        guard !failures.isEmpty else { return .unavailable }
        if failures.allSatisfy({ $0 == .notFound }) { return .notFound }
        if failures.contains(.cancelled) { return .cancelled }
        if failures.contains(.offline) { return .offline }
        if failures.contains(.unauthorized) { return .unauthorized }
        if failures.contains(.rateLimited) { return .rateLimited }
        if failures.contains(.invalidRequest) { return .invalidRequest }
        if failures.contains(.unavailable) { return .unavailable }
        if failures.contains(.invalidData) { return .invalidData }
        return failures.last ?? .unavailable
    }

    private static func dataSource(for provider: FoodSearchProvider) -> FoodDataSource {
        switch provider {
        case .calorynAPI: .calorynCatalog
        case .openFoodFacts: .openFoodFactsCommunity
        }
    }

    private static func isValidBarcode(_ value: String) -> Bool {
        BarcodeIdentity.normalized(value) != nil
    }

    private static func validNutriscoreGrade(_ raw: String?) -> String? {
        guard let letter = raw?.lowercased(), ["a", "b", "c", "d", "e"].contains(letter) else { return nil }
        return letter
    }

    nonisolated private static func normalizedCountryCode(_ rawValue: String?) -> String? {
        guard let rawValue,
              rawValue.utf8.count == 2,
              rawValue.utf8.allSatisfy({ byte in
                  (65...90).contains(byte) || (97...122).contains(byte)
              }) else {
            return nil
        }

        return rawValue.uppercased()
    }

    private struct SearchLocaleContext {
        let preferredLanguageCodes: [String]

        static var current: SearchLocaleContext {
            let codes = orderedUnique(
                Locale.preferredLanguages.compactMap(languageCode(from:)) + ["en"]
            )
            return SearchLocaleContext(preferredLanguageCodes: codes)
        }

        nonisolated private static func orderedUnique(_ values: [String]) -> [String] {
            var seen = Set<String>()
            return values.compactMap { value in
                let normalized = value.lowercased()
                guard seen.insert(normalized).inserted else { return nil }
                return normalized
            }
        }

        nonisolated private static func languageCode(from identifier: String) -> String? {
            identifier
                .split(whereSeparator: { $0 == "-" || $0 == "_" })
                .first?
                .lowercased()
        }
    }

    #if DEBUG
    static var debugInitialSearchText: String {
        guard ProcessInfo.processInfo.environment["CALORYN_LOOKUP_FIXTURE"]?.hasPrefix("search-") == true else {
            return ""
        }
        // The in-flight fixture wants the list that shows *results and* a spinner, which
        // needs a local match: with none, the view shows a full-screen spinner instead.
        // "salad" matches the `customFoods` seed.
        return pinsSearchInFlight ? "salad" : "fixture"
    }

    static var debugInitialBarcodeFailure: FoodLookupError? {
        switch ProcessInfo.processInfo.environment["CALORYN_LOOKUP_FIXTURE"] {
        case "barcode-not-found": .notFound
        case "barcode-invalid-data": .invalidData
        case "barcode-unavailable": .unavailable
        case "barcode-offline": .offline
        default: nil
        }
    }

    static var debugInitialBarcode: String? {
        ProcessInfo.processInfo.environment["CALORYN_LOOKUP_FIXTURE"]?
            .hasPrefix("barcode-") == true ? "5711953150388" : nil
    }

    /// Holds the search spinner on screen instead of letting it resolve. The trailing
    /// "still searching" row is only visible for a few hundred milliseconds in a real
    /// search, so every settled capture misses it — which is how it painted its own
    /// white background over the sheet canvas unnoticed.
    static var pinsSearchInFlight: Bool {
        ProcessInfo.processInfo.environment["CALORYN_LOOKUP_FIXTURE"] == "search-loading"
    }

    private func applyDebugFixtureIfRequested() {
        switch ProcessInfo.processInfo.environment["CALORYN_LOOKUP_FIXTURE"] {
        case "search-results", "search-loading":
            isSearching = Self.pinsSearchInFlight
            searchResults = [
                FoodSearchResult(
                    product: OpenFoodFactsProduct.fixture(
                        code: "570000000001",
                        name: "Caloryn Greek Yogurt",
                        brand: "Nordic Dairy",
                        energy: 74,
                        protein: 10.2,
                        carbohydrates: 4.1,
                        fat: 1.8,
                        fiber: 0
                    ),
                    provenance: FoodProvenance(
                        provider: .calorynAPI,
                        source: .calorynCatalog,
                        completeness: .complete,
                        recoveredByFallback: false
                    )
                ),
                FoodSearchResult(
                    product: OpenFoodFactsProduct.fixture(
                        code: "570000000002",
                        name: "Community Oat Bar",
                        brand: "Open Pantry",
                        energy: 389,
                        protein: nil,
                        carbohydrates: 62,
                        fat: nil,
                        fiber: 7.2
                    ),
                    provenance: FoodProvenance(
                        provider: .openFoodFacts,
                        source: .openFoodFactsCommunity,
                        completeness: .partial,
                        recoveredByFallback: true
                    )
                )
            ]
        case "search-offline":
            failure = .offline
        case "search-unavailable":
            failure = .unavailable
        case "search-not-found":
            failure = .notFound
        case "search-invalid-data":
            failure = .invalidData
        default:
            break
        }
    }
    #else
    static let debugInitialSearchText = ""
    static let debugInitialBarcodeFailure: FoodLookupError? = nil
    static let debugInitialBarcode: String? = nil
    #endif
}
