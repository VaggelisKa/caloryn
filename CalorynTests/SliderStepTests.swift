import Testing
@testable import Caloryn

@Suite("Slider step")
struct SliderStepTests {
    @Test("A value moves to the nearest step counted from the lower bound")
    func snapsToTheNearestStep() {
        #expect(SliderStep.snap(522, in: -500...1_000, step: 50) == 500)
        #expect(SliderStep.snap(526, in: -500...1_000, step: 50) == 550)
        #expect(SliderStep.snap(75.3, in: 40...200, step: 0.5) == 75.5)
        #expect(SliderStep.snap(175.4, in: 120...220, step: 1) == 175)
    }

    @Test("A value outside the range is held at its ends")
    func clampsToTheRange() {
        #expect(SliderStep.snap(-900, in: -500...1_000, step: 50) == -500)
        #expect(SliderStep.snap(5_000, in: -500...1_000, step: 50) == 1_000)
    }

    @Test("Every 5% macro step reads back as its whole percentage", arguments: Array(0...10))
    func macroStepsReadAsWholePercentages(step: Int) {
        let expected = 10 + 5 * step
        let dragged = 0.10 + Double(step) * 0.05 + 0.004
        let ratio = SliderStep.snap(dragged, in: 0.10...0.60, step: 0.05)
        let selection = MacroRatioSelection(calorieTarget: 2_000, protein: ratio, carbs: 0.4, fat: 0.3)

        #expect(selection.percentText(for: .protein) == "\(expected)%")
    }

    @Test("A value that is not finite settles on the lower bound")
    func nonFiniteValueSettlesOnTheLowerBound() {
        #expect(SliderStep.snap(.nan, in: 40...200, step: 0.5) == 40)
        #expect(SliderStep.snap(.infinity, in: 40...200, step: 0.5) == 40)
    }
}
