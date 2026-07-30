import XCTest
@testable import Caloryn

final class MacroRatioSelectionTests: XCTestCase {
    // MARK: - Validity

    func testASplitThatTotalsOneHundredPercentIsValid() {
        XCTAssertTrue(makeSelection(protein: 0.30, carbs: 0.40, fat: 0.30).isValid)
        XCTAssertNil(makeSelection(protein: 0.30, carbs: 0.40, fat: 0.30).validationMessage)
    }

    func testASplitThatFallsShortIsRejected() {
        let selection = makeSelection(protein: 0.20, carbs: 0.40, fat: 0.30)

        XCTAssertFalse(selection.isValid)
        XCTAssertEqual(selection.validationMessage, "Ratios should total 100% (currently 90%)")
    }

    func testASplitThatOverspendsIsRejected() {
        let selection = makeSelection(protein: 0.40, carbs: 0.50, fat: 0.30)

        XCTAssertFalse(selection.isValid)
        XCTAssertEqual(selection.validationMessage, "Ratios should total 100% (currently 120%)")
    }

    /// The tolerance exists for the binary representation of 5% slider steps,
    /// not to let a split that is genuinely short through.
    func testTheToleranceCoversRoundingButNotARealShortfall() {
        XCTAssertTrue(makeSelection(protein: 0.30, carbs: 0.40, fat: 0.305).isValid)
        XCTAssertFalse(makeSelection(protein: 0.30, carbs: 0.40, fat: 0.32).isValid)
    }

    func testEveryReachableSliderCombinationOfTheDefaultsStaysValid() {
        let split = MacroRatioSelection.defaultSplit
        let selection = makeSelection(protein: split.protein, carbs: split.carbs, fat: split.fat)

        XCTAssertTrue(selection.isValid)
    }

    // MARK: - Grams

    func testGramsAreTheTargetSplitByEnergyDensity() {
        let selection = makeSelection(calorieTarget: 2_000, protein: 0.30, carbs: 0.40, fat: 0.30)

        XCTAssertEqual(selection.grams(for: .protein), 150, accuracy: 0.0001)
        XCTAssertEqual(selection.grams(for: .carbs), 200, accuracy: 0.0001)
        XCTAssertEqual(selection.grams(for: .fat), 66.6667, accuracy: 0.001)
    }

    /// The preview here has to match what the profile save writes, or the
    /// targets change the moment onboarding finishes.
    func testThePreviewedGramsAreTheOnesTheProfileSaveWouldWrite() {
        let selection = makeSelection(calorieTarget: 2_400, protein: 0.35, carbs: 0.35, fat: 0.30)

        XCTAssertEqual(
            selection.grams(for: .fat),
            NutritionCalculator.macroGrams(calories: 2_400, ratio: 0.30, caloriesPerGram: 9),
            accuracy: 0.0001
        )
    }

    func testAZeroTargetBuysNoGrams() {
        let selection = makeSelection(calorieTarget: 0, protein: 0.30, carbs: 0.40, fat: 0.30)

        XCTAssertEqual(selection.grams(for: .protein), 0)
        XCTAssertEqual(selection.gramsText(for: .protein), "0g")
    }

    // MARK: - Text

    func testTheSliderReadoutsAreWholePercentagesAndWholeGrams() {
        let selection = makeSelection(calorieTarget: 2_000, protein: 0.30, carbs: 0.40, fat: 0.30)

        XCTAssertEqual(selection.percentText(for: .protein), "30%")
        XCTAssertEqual(selection.gramsText(for: .carbs), "200g")
        XCTAssertEqual(selection.gramsText(for: .fat), "66g")
    }

    /// `Int(_:)` terminates the process on a value that is not finite. These
    /// strings only ever describe what the sliders currently hold, so a bad
    /// number has to come out as text.
    func testARatioThatIsNotANumberIsRenderedRatherThanCrashing() {
        let selection = makeSelection(protein: .nan, carbs: .infinity, fat: 0.30)

        XCTAssertEqual(selection.percentText(for: .protein), "0%")
        XCTAssertEqual(selection.gramsText(for: .protein), "0g")
        XCTAssertFalse(selection.isValid)
        XCTAssertNotNil(selection.validationMessage)
    }

    // MARK: - Slider bounds

    func testNoMacroCanBeDraggedOutOfTheSplitEntirely() {
        for macro in MacroRatioSelection.Macro.allCases {
            XCTAssertEqual(macro.sliderRange.lowerBound, 0.10, "\(macro)")
        }
    }

    func testCarbsAreAllowedTheHighestCeilingAsTheUsualRemainder() {
        XCTAssertEqual(MacroRatioSelection.Macro.carbs.sliderRange.upperBound, 0.60)
        XCTAssertEqual(MacroRatioSelection.Macro.protein.sliderRange.upperBound, 0.50)
        XCTAssertEqual(MacroRatioSelection.Macro.fat.sliderRange.upperBound, 0.50)
    }

    /// Every macro's floor has to leave the other two able to reach 100%,
    /// otherwise a slider could park the step on a split it cannot leave.
    func testTheFloorsAndCeilingsAlwaysAllowAValidSplit() {
        for macro in MacroRatioSelection.Macro.allCases {
            let others = MacroRatioSelection.Macro.allCases.filter { $0 != macro }
            let othersCeiling = others.reduce(0) { $0 + $1.sliderRange.upperBound }
            let othersFloor = others.reduce(0) { $0 + $1.sliderRange.lowerBound }

            XCTAssertGreaterThanOrEqual(othersCeiling + macro.sliderRange.lowerBound, 1, "\(macro)")
            XCTAssertLessThanOrEqual(othersFloor + macro.sliderRange.lowerBound, 1, "\(macro)")
        }
    }

    func testFatIsTheOnlyMacroCountedAtNineCaloriesAGram() {
        XCTAssertEqual(MacroRatioSelection.Macro.protein.caloriesPerGram, 4)
        XCTAssertEqual(MacroRatioSelection.Macro.carbs.caloriesPerGram, 4)
        XCTAssertEqual(MacroRatioSelection.Macro.fat.caloriesPerGram, 9)
    }

    // MARK: - The default split

    /// Skipping the step and saving a profile must land on the same split, so
    /// the default is taken from the settings type rather than restated.
    func testTheDefaultSplitIsTheOneTheProfileAlreadyUses() {
        XCTAssertEqual(MacroRatioSelection.defaultSplit, ProfileEditMacroRatios.defaultSplit)
        XCTAssertEqual(MacroRatioSelection.defaultSplit.protein, 0.30)
        XCTAssertEqual(MacroRatioSelection.defaultSplit.carbs, 0.40)
        XCTAssertEqual(MacroRatioSelection.defaultSplit.fat, 0.30)
    }

    // MARK: - Helpers

    private func makeSelection(
        calorieTarget: Int = 2_000,
        protein: Double,
        carbs: Double,
        fat: Double
    ) -> MacroRatioSelection {
        MacroRatioSelection(calorieTarget: calorieTarget, protein: protein, carbs: carbs, fat: fat)
    }
}
