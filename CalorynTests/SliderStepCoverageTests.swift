import Testing
@testable import Caloryn

@Suite("Slider step at the edges")
@MainActor
struct SliderStepCoverageTests {
    @Test(
        "Exactly half a step rounds up, counted from the lower bound",
        arguments: [
            (525.0, -500.0...1_000.0, 50.0, 550.0),
            (-475.0, -500.0...1_000.0, 50.0, -450.0),
            (75.25, 40.0...200.0, 0.5, 75.5),
            (174.5, 120.0...220.0, 1.0, 175.0),
        ]
    )
    func halfStepRoundsUp(value: Double, range: ClosedRange<Double>, step: Double, expected: Double) {
        #expect(SliderStep.snap(value, in: range, step: step) == expected)
    }

    @Test("A range the step does not divide is held at its upper bound when rounding would pass it")
    func unevenRangeIsHeldAtTheTop() {
        #expect(SliderStep.snap(10, in: 0...10, step: 4) == 10)
        #expect(SliderStep.snap(9, in: 0...10, step: 4) == 8)
        #expect(SliderStep.snap(200, in: 40...200, step: 3) == 199)
    }

    @Test("A step wider than the range settles on the lower bound")
    func oversizedStep() {
        #expect(SliderStep.snap(150, in: 40...200, step: 1_000) == 40)
    }

    @Test(
        "A step that is zero, negative or not finite only clamps the value",
        arguments: [0.0, -5.0, .nan, .infinity]
    )
    func unusableStepOnlyClamps(step: Double) {
        #expect(SliderStep.snap(73.3, in: 40...200, step: step) == 73.3)
        #expect(SliderStep.snap(500, in: 40...200, step: step) == 200)
        #expect(SliderStep.snap(-500, in: 40...200, step: step) == 40)
    }

    @Test("Negative infinity settles on the lower bound like any other non-finite value")
    func negativeInfinity() {
        #expect(SliderStep.snap(-.infinity, in: 40...200, step: 0.5) == 40)
    }

    @Test("A single-point range always settles on that point")
    func singlePointRange() {
        #expect(SliderStep.snap(7, in: 5...5, step: 1) == 5)
        #expect(SliderStep.snap(3, in: 5...5, step: 1) == 5)
    }

    @Test(
        "Macro steps read back as the decimal written, not its binary neighbour",
        arguments: [
            (0.30, 0.3),
            (0.35, 0.35),
            (0.45, 0.45),
            (0.6, 0.6),
        ]
    )
    func sixPlaceRounding(value: Double, expected: Double) {
        #expect(SliderStep.snap(value, in: 0.10...0.60, step: 0.05) == expected)
    }
}
