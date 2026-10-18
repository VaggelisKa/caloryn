import XCTest
@testable import Caloryn

final class LibraryFoodRowSummaryTests: XCTestCase {
    func testTheDetailLineJoinsBrandAndServingWithAComma() {
        let summary = makeSummary(brand: "Arla", servingDescription: "1 pot 150 g")

        XCTAssertEqual(summary.detail, "Arla, 1 pot 150 g · per 100 g: 63 kcal")
    }

    func testAFoodWithNoBrandIsDescribedByItsServingAlone() {
        XCTAssertEqual(
            makeSummary(brand: nil, servingDescription: "1 glass 300 g").detail,
            "1 glass 300 g · per 100 g: 63 kcal"
        )
    }

    func testAFoodWithNoServingIsDescribedByItsBrandAlone() {
        XCTAssertEqual(makeSummary(brand: "Schulstad", servingDescription: nil).detail, "Schulstad")
    }

    func testEmptyFactsAreLeftOutRatherThanJoined() {
        XCTAssertEqual(
            makeSummary(brand: "", servingDescription: "1 slice 45 g").detail,
            "1 slice 45 g · per 100 g: 63 kcal"
        )
        XCTAssertEqual(makeSummary(brand: "Arla", servingDescription: "").detail, "Arla")
    }

    func testAFoodWithNeitherBrandNorServingHasNoDetailLine() {
        XCTAssertNil(makeSummary(brand: nil, servingDescription: nil).detail)
        XCTAssertNil(makeSummary(brand: "", servingDescription: "").detail)
    }

    func testAServingWithNoDescriptionIsWrittenAsItsWeight() {
        XCTAssertEqual(
            makeSummary(brand: nil, servingDescription: nil, servingGrams: 250).detail,
            "250 g · per 100 g: 63 kcal"
        )
        XCTAssertEqual(
            makeSummary(brand: "Arla", servingDescription: nil, servingGrams: 180).detail,
            "Arla, 180 g · per 100 g: 63 kcal"
        )
    }

    func testADeclaredServingIsWrittenInTheHouseForm() {
        XCTAssertEqual(
            makeSummary(brand: "Arla", servingDescription: "1 pot (150g)", servingGrams: 150).detail,
            "Arla, 1 pot 150 g · per 100 g: 63 kcal"
        )
    }

    func testTheDetailLineIsSpokenWithoutTheMiddleDot() {
        XCTAssertEqual(
            makeSummary(brand: "Arla", servingDescription: nil, servingGrams: 180).detailAccessibilityLabel,
            "Arla, 180 grams, 63 kcal per 100 grams"
        )
    }

    func testACountableServingIsPricedAsAWhole() {
        let summary = makeSummary(servingDescription: "1 pot (150g)", caloriesPer100g: 63, servingGrams: 150)

        XCTAssertEqual(summary.caloriesText, "95")
        XCTAssertEqual(summary.caloriesCaption, "kcal")
    }

    func testAServingWithNoUnitIsPricedForItsWeight() {
        let summary = makeSummary(caloriesPer100g: 120, servingGrams: 250)

        XCTAssertEqual(summary.caloriesText, "300")
        XCTAssertEqual(summary.caloriesCaption, "kcal")
    }

    func testAFoodWithNoServingIsPricedPer100Grams() {
        let summary = makeSummary(caloriesPer100g: 380.4)

        XCTAssertEqual(summary.caloriesText, "380")
        XCTAssertEqual(summary.caloriesCaption, "kcal per 100 g")
    }

    private func makeSummary(
        name: String = "Skyr",
        brand: String? = nil,
        servingDescription: String? = nil,
        caloriesPer100g: Double = 63,
        servingGrams: Double? = nil
    ) -> LibraryFoodRowSummary {
        LibraryFoodRowSummary(
            name: name,
            brand: brand,
            servingDescription: servingDescription,
            caloriesPer100g: caloriesPer100g,
            servingGrams: servingGrams
        )
    }
}
