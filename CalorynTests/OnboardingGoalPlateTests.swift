import Foundation
import Testing
@testable import Caloryn

@Suite("Onboarding goal plate")
@MainActor
struct OnboardingGoalPlateTests {
    @Test("The rows show the resting and daily burn truncated, like the target itself")
    func rowsTruncateTheBurn() {
        let plate = OnboardingGoalPlate(bmr: 1_700.9, tdee: 2_500.9, target: 2_000, calorieDeficit: 500)

        #expect(plate.restText == "\(1_700.formatted()) kcal")
        #expect(plate.burnText == "\(2_500.formatted()) kcal")
    }

    @Test("The adjustment row says which way the plate differs from the burn", arguments: [
        (2_000, "500 less"),
        (2_750, "250 more"),
        (2_500, "None"),
    ])
    func adjustmentNamesTheDirection(target: Int, expected: String) {
        let plate = OnboardingGoalPlate(bmr: 1_700, tdee: 2_500, target: target, calorieDeficit: 500)

        #expect(plate.adjustmentText == expected)
    }

    @Test("The adjustment is the real gap to the target, not the slider, once the floor applies")
    func adjustmentFollowsTheFlooredTarget() {
        let basis = OnboardingGoalSummaryDraft.Basis(
            age: 80,
            sex: .female,
            heightCm: 150,
            weightKg: 45,
            activityLevel: .sedentary,
            calorieDeficit: 1_000
        )
        let plate = OnboardingGoalPlate(basis: basis, target: basis.calculatedTarget)

        #expect(basis.calculatedTarget == 1_200)
        #expect(plate.difference == basis.tdee.truncatedSafely - 1_200)
        #expect(plate.adjustmentText.hasSuffix("more"))
    }

    @Test("A typed target is described against the burn, whatever the slider says")
    func manualTargetIsDescribedAgainstTheBurn() {
        let plate = OnboardingGoalPlate(bmr: 1_700, tdee: 2_500, target: 2_600, calorieDeficit: 500)

        #expect(plate.adjustmentText == "100 more")
        #expect(plate.explanation.contains("100 bigger"))
    }

    @Test("The explanation names the burn and how the plate compares to it")
    func explanationComparesThePlate() {
        let smaller = OnboardingGoalPlate(bmr: 1_700, tdee: 2_500, target: 2_000, calorieDeficit: 500)
        let same = OnboardingGoalPlate(bmr: 1_700, tdee: 2_500, target: 2_500, calorieDeficit: 0)

        #expect(smaller.explanation ==
            "You burn about \(2_500.formatted()). The dotted ring is that; the plate is 500 smaller, so you lose weight.")
        #expect(same.explanation.hasSuffix("the plate is the same size, so your weight stays put."))
    }

    @Test("The pace caption reads the slider in the Settings goal row's words", arguments: [
        (500.0, "500 under what you burn"),
        (-300.0, "300 over what you burn"),
        (0.0, "What you burn"),
    ])
    func paceCaptionReadsTheSlider(deficit: Double, expected: String) {
        let plate = OnboardingGoalPlate(bmr: 1_700, tdee: 2_500, target: 2_000, calorieDeficit: deficit)

        #expect(plate.paceCaption == expected)
    }

    @Test("A non-finite burn or adjustment still produces words, not a crash")
    func nonFiniteFiguresSurvive() {
        let plate = OnboardingGoalPlate(bmr: .nan, tdee: .infinity, target: 2_000, calorieDeficit: .nan)

        #expect(!plate.explanation.isEmpty)
        #expect(!plate.paceCaption.isEmpty)
        #expect(plate.plateDiameterRatio.isFinite)
    }

    @Test("Under the burn the dotted ring fills the drawing and the plate sits inside it")
    func plateSitsInsideTheRing() {
        let plate = OnboardingGoalPlate(bmr: 1_700, tdee: 2_500, target: 2_000, calorieDeficit: 500)

        #expect(plate.burnDiameterRatio == 1)
        #expect(abs(plate.plateDiameterRatio - (0.8).squareRoot()) < 0.0001)
    }

    @Test("Over the burn the plate fills the drawing and the ring sits inside it")
    func ringSitsInsideAnOversizedPlate() {
        let plate = OnboardingGoalPlate(bmr: 1_700, tdee: 2_000, target: 2_500, calorieDeficit: -500)

        #expect(plate.plateDiameterRatio == 1)
        #expect(plate.burnDiameterRatio < 1)
    }

    @Test("A very small plate is still drawn at half the ring's width")
    func smallPlateHasAFloor() {
        let plate = OnboardingGoalPlate(bmr: 2_000, tdee: 4_000, target: 800, calorieDeficit: 1_000)

        #expect(plate.plateDiameterRatio == OnboardingGoalPlate.minimumDiameterRatio)
    }

    @Test("Keep sits where the slider's adjustment is zero")
    func keepSitsAtZero() {
        let range = OnboardingGoalPlate.adjustmentRange
        let zero = range.lowerBound + OnboardingGoalPlate.maintenanceFraction * (range.upperBound - range.lowerBound)

        #expect(abs(zero) < 0.0001)
    }
}
