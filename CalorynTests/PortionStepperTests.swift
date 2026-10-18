import Testing
@testable import Caloryn

/// The Portion sheet's stepper pill: minus and plus move the portion ten grams.
@Suite("Portion stepper")
struct PortionStepperTests {
    private var plainFood: PortionSelection.Shape { PortionSelection.Shape() }

    private var slicedFood: PortionSelection.Shape {
        PortionSelection.Shape(servingGramsPerUnit: 45, defaultServingGrams: 45)
    }

    @Test("Plus adds ten grams and the field follows")
    func plusAddsTenGrams() {
        var portion = PortionSelection(shape: plainFood, initialGrams: 150, preservesExactGrams: false)

        portion.gramsStepped(.more)

        #expect(portion.portionGrams == 160)
        #expect(portion.gramsInput == "160")
    }

    @Test("Minus takes ten grams away and the field follows")
    func minusTakesTenGrams() {
        var portion = PortionSelection(shape: plainFood, initialGrams: 150, preservesExactGrams: false)

        portion.gramsStepped(.less)

        #expect(portion.portionGrams == 140)
        #expect(portion.gramsInput == "140")
    }

    @Test("A fractional portion keeps its fraction rather than snapping to a multiple of ten")
    func fractionIsKept() {
        #expect(PortionSelection.stepped(137.5, .more) == 147.5)
        #expect(PortionSelection.stepped(137.5, .less) == 127.5)
    }

    @Test(
        "A step never leaves the range a typed weight is held to",
        arguments: [
            (5.0, PortionSelection.GramStep.less, 1.0),
            (1.0, .less, 1.0),
            (9_995.0, .more, 10_000.0),
            (10_000.0, .more, 10_000.0),
        ]
    )
    func stepIsClamped(grams: Double, step: PortionSelection.GramStep, expected: Double) {
        #expect(PortionSelection.stepped(grams, step) == expected)
    }

    @Test("A non-finite portion steps to the minimum rather than propagating")
    func nonFiniteStepsToMinimum() {
        #expect(PortionSelection.stepped(.nan, .more) == Double(PortionSelection.minimumGrams))
        #expect(PortionSelection.stepped(.infinity, .less) == Double(PortionSelection.minimumGrams))
    }

    @Test("The stepper does nothing while the portion is counted in servings")
    func stepperIsInertInServings() {
        var portion = PortionSelection(shape: slicedFood, initialGrams: 45, preservesExactGrams: false)
        #expect(portion.mode == .serving)

        portion.gramsStepped(.more)

        #expect(portion.portionGrams == 45)
    }
}
