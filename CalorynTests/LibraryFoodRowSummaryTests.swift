import XCTest
@testable import Caloryn

final class LibraryFoodRowSummaryTests: XCTestCase {
    // MARK: - Detail line

    /// Brand then serving, comma-joined, then what 100 g is worth after a middle dot.
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

    /// An empty string is as absent as a missing one, so it leaves no stray comma.
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

    /// A serving recorded only as a weight is written as that weight, so the figure beside
    /// it says what amount it is for.
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

    /// The declared serving is written in the house form, as Add Food writes it.
    func testADeclaredServingIsWrittenInTheHouseForm() {
        XCTAssertEqual(
            makeSummary(brand: "Arla", servingDescription: "1 pot (150g)", servingGrams: 150).detail,
            "Arla, 1 pot 150 g · per 100 g: 63 kcal"
        )
    }

    /// VoiceOver hears the weight in words, and no middle dot.
    func testTheDetailLineIsSpokenWithoutTheMiddleDot() {
        XCTAssertEqual(
            makeSummary(brand: "Arla", servingDescription: nil, servingGrams: 180).detailAccessibilityLabel,
            "Arla, 180 grams, 63 kcal per 100 grams"
        )
    }

    // MARK: - Trailing figure

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
