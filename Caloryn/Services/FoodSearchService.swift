import Foundation
import OSLog
import SwiftData

struct FoodProviderPolicy: Equatable, Sendable {
    let primary: FoodSearchProvider
    let secondary: FoodSearchProvider?

    static let automatic = FoodProviderPolicy(
        primary: .calorynAPI,
        secondary: .openFoodFacts
    )

    init(primary: FoodSearchProvider, secondary: FoodSearchProvider?) {
        self.primary = primary
        self.secondary = secondary == primary ? nil : secondary
    }

    static func only(_ provider: FoodSearchProvider) -> FoodProviderPolicy {
        FoodProviderPolicy(primary: provider, secondary: nil)
    }

    var orderedProviders: [FoodSearchProvider] {
        if let secondary {
            [primary, secondary]
        } else {
            [primary]
        }
    }
}

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

    var errorDescription: String? {
        presentation.message
    }
}

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
        return FoodItem(
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
        (4...32).contains(value.count) && value.allSatisfy(\.isNumber)
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
        return "fixture"
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

    private func applyDebugFixtureIfRequested() {
        switch ProcessInfo.processInfo.environment["CALORYN_LOOKUP_FIXTURE"] {
        case "search-results":
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
    #endif
}

struct SearchResponse: Decodable {
    let hits: [OpenFoodFactsProduct]
}

struct OpenFoodFactsProduct: Decodable, Identifiable, Hashable {
    let code: String?
    let productName: String?
    let brands: String?
    let servingSize: String?
    let servingQuantityG: Double?
    let productQuantity: Double?
    let quantity: String?
    let nutriments: OFFNutriments?
    let nutritionGrades: String?
    let categoryTags: [String]?
    let lang: String?
    let countriesTags: [String]?

    private let stableId: String
    var id: String { stableId }

    var hasMinimumUsableNutrition: Bool {
        guard let productName else { return false }
        return !productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && nutriments?.energyKcal100g != nil
    }

    var nutritionCompleteness: NutritionCompleteness {
        guard hasMinimumUsableNutrition else { return .unknown }
        let coreValues = [
            nutriments?.proteins100g,
            nutriments?.carbohydrates100g,
            nutriments?.fat100g
        ]
        return coreValues.allSatisfy { $0 != nil } ? .complete : .partial
    }

    var missingCoreNutritionLabels: [String] {
        var labels: [String] = []
        if nutriments?.proteins100g == nil { labels.append("protein") }
        if nutriments?.carbohydrates100g == nil { labels.append("carbohydrates") }
        if nutriments?.fat100g == nil { labels.append("fat") }
        return labels
    }

    fileprivate var reconciliationKey: String {
        if let code {
            let normalizedCode = String(code.filter { $0.isLetter || $0.isNumber }).lowercased()
            if !normalizedCode.isEmpty { return "code:\(normalizedCode)" }
        }

        let normalizedName = Self.normalizedIdentityComponent(productName)
        let normalizedBrand = Self.normalizedIdentityComponent(brands)
        if !normalizedName.isEmpty {
            return "name:\(normalizedName)|brand:\(normalizedBrand)"
        }
        return "id:\(stableId)"
    }

    fileprivate var richnessScore: Int {
        let nutrientValues: [Double?] = [
            nutriments?.energyKcal100g,
            nutriments?.proteins100g,
            nutriments?.carbohydrates100g,
            nutriments?.fat100g,
            nutriments?.fiber100g,
            nutriments?.sugars100g,
            nutriments?.saturatedFat100g,
            nutriments?.sodium100g
        ]
        return nutrientValues.compactMap { $0 }.count * 10
            + (brands?.isEmpty == false ? 2 : 0)
            + (effectiveServingInfo.defaultServingG != nil ? 2 : 0)
            + (nutritionGrades != nil ? 1 : 0)
    }

    private var quantityGrams: Double? {
        guard let quantity, !quantity.isEmpty else { return nil }
        let pattern = #"(\d+(?:[.,]\d+)?)\s*g\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(quantity.startIndex..., in: quantity)
        guard let match = regex.firstMatch(in: quantity, range: range), match.numberOfRanges > 1 else { return nil }
        let numberRange = match.range(at: 1)
        guard let swiftRange = Range(numberRange, in: quantity) else { return nil }
        let numberString = String(quantity[swiftRange]).replacingOccurrences(of: ",", with: ".")
        guard let value = Double(numberString), value > 0 else { return nil }
        return value
    }

    var formattedServingDescription: String? {
        if let servingSize, !servingSize.isEmpty {
            return servingSize
        }
        if let servingQuantityG, servingQuantityG > 0 {
            return "\(Int(servingQuantityG))g"
        }
        return nil
    }

    var effectiveServingInfo: (defaultServingG: Double?, servingDescription: String?) {
        if let servingQuantityG, servingQuantityG > 0 {
            return (servingQuantityG, formattedServingDescription)
        }
        if let productQuantity, productQuantity > 0 {
            return (productQuantity, "1 pack (\(Int(productQuantity))g)")
        }
        if let quantityGrams {
            return (quantityGrams, "1 pack (\(Int(quantityGrams))g)")
        }
        return (nil, nil)
    }

    var caloriesPerServing: Double? {
        let grams = servingQuantityG ?? productQuantity ?? quantityGrams
        guard let grams, grams > 0,
              let caloriesPer100g = nutriments?.energyKcal100g else { return nil }
        return caloriesPer100g * grams / 100
    }

    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case brands
        case servingSize = "serving_size"
        case servingQuantityG = "serving_quantity"
        case productQuantity = "product_quantity"
        case quantity
        case nutriments
        case nutritionGrades = "nutrition_grades"
        case categoryTags = "categories_tags"
        case lang
        case countriesTags = "countries_tags"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedCode = try container.decodeIfPresent(String.self, forKey: .code)
        code = decodedCode
        stableId = decodedCode ?? UUID().uuidString
        productName = try container.decodeIfPresent(String.self, forKey: .productName)
        servingSize = try container.decodeIfPresent(String.self, forKey: .servingSize)
        quantity = try container.decodeIfPresent(String.self, forKey: .quantity)
        nutriments = try container.decodeIfPresent(OFFNutriments.self, forKey: .nutriments)
        nutritionGrades = try container.decodeIfPresent(String.self, forKey: .nutritionGrades)
        categoryTags = try container.decodeIfPresent([String].self, forKey: .categoryTags)
        lang = try container.decodeIfPresent(String.self, forKey: .lang)
        countriesTags = try container.decodeIfPresent([String].self, forKey: .countriesTags)

        if let number = try? container.decodeIfPresent(Double.self, forKey: .servingQuantityG) {
            servingQuantityG = number
        } else if let string = try? container.decodeIfPresent(String.self, forKey: .servingQuantityG) {
            servingQuantityG = Double(string)
        } else {
            servingQuantityG = nil
        }

        if let number = try? container.decodeIfPresent(Double.self, forKey: .productQuantity) {
            productQuantity = number
        } else if let string = try? container.decodeIfPresent(String.self, forKey: .productQuantity) {
            productQuantity = Double(string)
        } else {
            productQuantity = nil
        }

        if let string = try? container.decodeIfPresent(String.self, forKey: .brands) {
            brands = string
        } else if let array = try? container.decodeIfPresent([String].self, forKey: .brands) {
            brands = array.joined(separator: ", ")
        } else {
            brands = nil
        }
    }

    private init(
        code: String?,
        productName: String?,
        brands: String?,
        nutriments: OFFNutriments?
    ) {
        self.code = code
        self.productName = productName
        self.brands = brands
        self.servingSize = nil
        self.servingQuantityG = nil
        self.productQuantity = nil
        self.quantity = nil
        self.nutriments = nutriments
        self.nutritionGrades = nil
        self.categoryTags = nil
        self.lang = nil
        self.countriesTags = nil
        self.stableId = code ?? UUID().uuidString
    }

    private static func normalizedIdentityComponent(_ value: String?) -> String {
        value.map {
            String(
                $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                    .filter { $0.isLetter || $0.isNumber }
            )
            .lowercased()
        } ?? ""
    }

    #if DEBUG
    static func fixture(
        code: String,
        name: String,
        brand: String,
        energy: Double,
        protein: Double?,
        carbohydrates: Double?,
        fat: Double?,
        fiber: Double?
    ) -> OpenFoodFactsProduct {
        OpenFoodFactsProduct(
            code: code,
            productName: name,
            brands: brand,
            nutriments: OFFNutriments.fixture(
                energy: energy,
                protein: protein,
                carbohydrates: carbohydrates,
                fat: fat,
                fiber: fiber
            )
        )
    }
    #endif
}

struct BarcodeLookupResponse: Decodable {
    let code: String?
    let status: Int
    let product: OpenFoodFactsProduct?
}

struct OFFNutriments: Decodable, Hashable {
    let energyKcal100g: Double?
    let proteins100g: Double?
    let carbohydrates100g: Double?
    let fat100g: Double?
    let fiber100g: Double?
    let sugars100g: Double?
    let addedSugars100g: Double?
    let sucrose100g: Double?
    let glucose100g: Double?
    let fructose100g: Double?
    let lactose100g: Double?
    let maltose100g: Double?
    let maltodextrins100g: Double?
    let starch100g: Double?
    let polyols100g: Double?
    let saturatedFat100g: Double?
    let transFat100g: Double?
    let monounsaturatedFat100g: Double?
    let polyunsaturatedFat100g: Double?
    let omega3Fat100g: Double?
    let omega6Fat100g: Double?
    let omega9Fat100g: Double?
    let salt100g: Double?
    let sodium100g: Double?
    let cholesterol100g: Double?
    let solubleFiber100g: Double?
    let insolubleFiber100g: Double?
    let casein100g: Double?
    let serumProteins100g: Double?
    let alcohol100g: Double?

    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case proteins100g = "proteins_100g"
        case carbohydrates100g = "carbohydrates_100g"
        case fat100g = "fat_100g"
        case fiber100g = "fiber_100g"
        case sugars100g = "sugars_100g"
        case addedSugars100g = "added-sugars_100g"
        case sucrose100g = "sucrose_100g"
        case glucose100g = "glucose_100g"
        case fructose100g = "fructose_100g"
        case lactose100g = "lactose_100g"
        case maltose100g = "maltose_100g"
        case maltodextrins100g = "maltodextrins_100g"
        case starch100g = "starch_100g"
        case polyols100g = "polyols_100g"
        case saturatedFat100g = "saturated-fat_100g"
        case transFat100g = "trans-fat_100g"
        case monounsaturatedFat100g = "monounsaturated-fat_100g"
        case polyunsaturatedFat100g = "polyunsaturated-fat_100g"
        case omega3Fat100g = "omega-3-fat_100g"
        case omega6Fat100g = "omega-6-fat_100g"
        case omega9Fat100g = "omega-9-fat_100g"
        case salt100g = "salt_100g"
        case sodium100g = "sodium_100g"
        case cholesterol100g = "cholesterol_100g"
        case solubleFiber100g = "soluble-fiber_100g"
        case insolubleFiber100g = "insoluble-fiber_100g"
        case casein100g = "casein_100g"
        case serumProteins100g = "serum-proteins_100g"
        case alcohol100g = "alcohol_100g"
    }

    #if DEBUG
    static func fixture(
        energy: Double,
        protein: Double?,
        carbohydrates: Double?,
        fat: Double?,
        fiber: Double?
    ) -> OFFNutriments {
        OFFNutriments(
            energyKcal100g: energy,
            proteins100g: protein,
            carbohydrates100g: carbohydrates,
            fat100g: fat,
            fiber100g: fiber,
            sugars100g: nil,
            addedSugars100g: nil,
            sucrose100g: nil,
            glucose100g: nil,
            fructose100g: nil,
            lactose100g: nil,
            maltose100g: nil,
            maltodextrins100g: nil,
            starch100g: nil,
            polyols100g: nil,
            saturatedFat100g: nil,
            transFat100g: nil,
            monounsaturatedFat100g: nil,
            polyunsaturatedFat100g: nil,
            omega3Fat100g: nil,
            omega6Fat100g: nil,
            omega9Fat100g: nil,
            salt100g: nil,
            sodium100g: nil,
            cholesterol100g: nil,
            solubleFiber100g: nil,
            insolubleFiber100g: nil,
            casein100g: nil,
            serumProteins100g: nil,
            alcohol100g: nil
        )
    }
    #endif
}
