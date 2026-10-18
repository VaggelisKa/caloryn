import Testing
@testable import Caloryn

/// Where a stepped onboarding slider settles at the awkward values: exactly half a step,
/// a range the step does not divide, and a step that is not a step at all.
@Suite("Slider step at the edges")
struct SliderStepCoverageTests {

    @Test(
        "Exactly half a step rounds up, counted from the lower bound",
        arguments: [
            (525.0, -500.0...1_000.0, 50.0, 550.0),   // 1025 / 50 = 20.5 steps → 21
            (-475.0, -500.0...1_000.0, 50.0, -450.0), // 25 / 50 = 0.5 steps → 1, even below zero
            (75.25, 40.0...200.0, 0.5, 75.5),         // 35.25 / 0.5 = 70.5 steps → 71
            (174.5, 120.0...220.0, 1.0, 175.0),       // 54.5 steps → 55
        ]
    )
    func halfStepRoundsUp(value: Double, range: ClosedRange<Double>, step: Double, expected: Double) {
        #expect(SliderStep.snap(value, in: range, step: step) == expected)
    }

    @Test("A range the step does not divide is held at its upper bound when rounding would pass it")
    func unevenRangeIsHeldAtTheTop() {
        // 10 / 4 = 2.5 steps → 3 → 12, held at 10.
        #expect(SliderStep.snap(10, in: 0...10, step: 4) == 10)
        // 9 / 4 = 2.25 steps → 2 → 8.
        #expect(SliderStep.snap(9, in: 0...10, step: 4) == 8)
        // 200 is 53⅓ steps of 3 above 40, so the top settles on 199.
        #expect(SliderStep.snap(200, in: 40...200, step: 3) == 199)
    }

    @Test("A step wider than the range settles on the lower bound")
    func oversizedStep() {
        // 110 / 1000 = 0.11 steps → 0.
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
            (0.30, 0.3),    // 0.1 + 4 × 0.05 = 0.30000000000000004 before the six-place rounding
            (0.35, 0.35),
            (0.45, 0.45),
            (0.6, 0.6),
        ]
    )
    func sixPlaceRounding(value: Double, expected: Double) {
        #expect(SliderStep.snap(value, in: 0.10...0.60, step: 0.05) == expected)
    }
}
