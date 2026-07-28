import Testing
@testable import Caloryn

/// Covers the bounds and readouts of the About You step.
@MainActor
@Suite("Onboarding personal info")
struct OnboardingPersonalInfoTests {

    @Test("The default answers the flow starts from are all inside their bounds")
    func defaultsAreInRange() {
        #expect(OnboardingPersonalInfo.ageRange.contains(30))
        #expect(OnboardingPersonalInfo.heightRange.contains(175))
        #expect(OnboardingPersonalInfo.weightRange.contains(75))
    }

    @Test("Age is bounded to a range a calorie calculation is meaningful over")
    func ageIsBounded() {
        #expect(OnboardingPersonalInfo.ageRange == 16...100)
        #expect(!OnboardingPersonalInfo.ageRange.contains(15))
        #expect(!OnboardingPersonalInfo.ageRange.contains(101))
    }

    @Test("Height and weight are bounded, so no slider can produce a value the BMR formula chokes on")
    func heightAndWeightAreBounded() {
        #expect(OnboardingPersonalInfo.heightRange == 120...220)
        #expect(OnboardingPersonalInfo.weightRange == 40...200)

        for height in [OnboardingPersonalInfo.heightRange.lowerBound, OnboardingPersonalInfo.heightRange.upperBound] {
            for weight in [OnboardingPersonalInfo.weightRange.lowerBound, OnboardingPersonalInfo.weightRange.upperBound] {
                for age in [OnboardingPersonalInfo.ageRange.lowerBound, OnboardingPersonalInfo.ageRange.upperBound] {
                    let bmr = NutritionCalculator.bmr(sex: .female, weightKg: weight, heightCm: height, age: age)
                    #expect(bmr.isFinite)
                }
            }
        }
    }

    @Test("Weight steps by half a kilogram and height by a whole centimetre")
    func stepsMatchTheReadouts() {
        #expect(OnboardingPersonalInfo.heightStep == 1)
        #expect(OnboardingPersonalInfo.weightStep == 0.5)
    }

    @Test("The age readout names its unit")
    func ageReadout() {
        #expect(OnboardingPersonalInfo.ageLabel(30) == "30 years")
        #expect(OnboardingPersonalInfo.ageLabel(16) == "16 years")
    }

    @Test("The height readout is whole centimetres, truncated rather than rounded")
    func heightReadout() {
        #expect(OnboardingPersonalInfo.heightLabel(175) == "175 cm")
        #expect(OnboardingPersonalInfo.heightLabel(175.9) == "175 cm")
    }

    @Test("The weight readout keeps the half kilogram the slider can land on")
    func weightReadout() {
        #expect(OnboardingPersonalInfo.weightLabel(75) == "75.0 kg")
        #expect(OnboardingPersonalInfo.weightLabel(75.5) == "75.5 kg")
        #expect(OnboardingPersonalInfo.weightLabel(200) == "200.0 kg")
    }
}
