import XCTest
@testable import Caloryn

final class LibraryFoodRowSummaryTests: XCTestCase {
    // MARK: - Detail line

    /// Brand then serving, comma-joined: the Plate copy has no middle dots.
    func testTheDetailLineJoinsBrandAndServingWithAComma() {
        let summary = makeSummary(brand: "Arla", servingDescription: "1 pot 150 g")

        XCTAssertEqual(summary.detail, "Arla, 1 pot 150 g")
    }

    func testAFoodWithNoBrandIsDescribedByItsServingAlone() {
        XCTAssertEqual(makeSummary(brand: nil, servingDescription: "1 glass 300 g").detail, "1 glass 300 g")
    }

    func testAFoodWithNoServingIsDescribedByItsBrandAlone() {
        XCTAssertEqual(makeSummary(brand: "Schulstad", servingDescription: nil).detail, "Schulstad")
    }

    /// An empty string is as absent as a missing one, so it leaves no stray comma.
    func testEmptyFactsAreLeftOutRatherThanJoined() {
        XCTAssertEqual(makeSummary(brand: "", servingDescription: "1 slice 45 g").detail, "1 slice 45 g")
        XCTAssertEqual(makeSummary(brand: "Arla", servingDescription: "").detail, "Arla")
    }

    func testAFoodWithNeitherBrandNorServingHasNoDetailLine() {
        XCTAssertNil(makeSummary(brand: nil, servingDescription: nil).detail)
        XCTAssertNil(makeSummary(brand: "", servingDescription: "").detail)
    }

    /// A serving recorded only as a weight is written as that weight, so "kcal a serving"
    /// beside it says what the serving is.
    func testAServingWithNoDescriptionIsWrittenAsItsWeight() {
        XCTAssertEqual(makeSummary(brand: nil, servingDescription: nil, servingGrams: 250).detail, "250 g")
        XCTAssertEqual(makeSummary(brand: "Arla", servingDescription: nil, servingGrams: 180).detail, "Arla, 180 g")
    }

    /// The declared serving is written in the house form, as Add Food writes it.
    func testADeclaredServingIsWrittenInTheHouseForm() {
        XCTAssertEqual(
            makeSummary(brand: "Arla", servingDescription: "1 pot (150g)", servingGrams: 150).detail,
            "Arla, 1 pot 150 g"
        )
    }

    // MARK: - Trailing figure

    func testACountableServingIsPricedPerUnit() {
        let summary = makeSummary(
            caloriesPer100g: 63,
            servingGrams: 150,
            servingUnitName: "pot",
            servingUnitCount: 1
        )

        XCTAssertEqual(summary.caloriesText, "95")
        XCTAssertEqual(summary.caloriesCaption, "kcal a pot")
    }

    func testAServingWithNoUnitIsPricedPerServing() {
        let summary = makeSummary(caloriesPer100g: 120, servingGrams: 250)

        XCTAssertEqual(summary.caloriesText, "300")
        XCTAssertEqual(summary.caloriesCaption, "kcal a serving")
    }

    /// No serving at all: the figure is per 100 g and says so, as Add Food does, rather than
    /// calling 100 g a serving.
    func testAFoodWithNoServingIsPricedPer100Grams() {
        let summary = makeSummary(caloriesPer100g: 380.4)

        XCTAssertEqual(summary.caloriesText, "380")
        XCTAssertEqual(summary.caloriesCaption, "kcal per 100 g")
    }

    // MARK: - Helpers

    private func makeSummary(
        name: String = "Skyr",
        brand: String? = nil,
        servingDescription: String? = nil,
        caloriesPer100g: Double = 63,
        servingGrams: Double? = nil,
        servingUnitName: String? = nil,
        servingUnitCount: Double? = nil
    ) -> LibraryFoodRowSummary {
        LibraryFoodRowSummary(
            name: name,
            brand: brand,
            servingDescription: servingDescription,
            caloriesPer100g: caloriesPer100g,
            servingGrams: servingGrams,
            servingUnitName: servingUnitName,
            servingUnitCount: servingUnitCount
        )
    }
}
