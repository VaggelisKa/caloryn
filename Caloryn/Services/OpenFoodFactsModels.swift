import Foundation

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

    /// Internal rather than fileprivate: `FoodSearchService.reconcile` and
    /// `deduplicate` key on it from their own file.
    var reconciliationKey: String {
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

    var richnessScore: Int {
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
            return "\(servingQuantityG.truncatedSafely)g"
        }
        return nil
    }

    var effectiveServingInfo: (defaultServingG: Double?, servingDescription: String?) {
        if let servingQuantityG, servingQuantityG > 0 {
            return (servingQuantityG, formattedServingDescription)
        }
        if let productQuantity, productQuantity > 0 {
            return (productQuantity, "1 pack (\(productQuantity.truncatedSafely)g)")
        }
        if let quantityGrams {
            return (quantityGrams, "1 pack (\(quantityGrams.truncatedSafely)g)")
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
