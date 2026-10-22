import Foundation
import Testing
@testable import Caloryn

private func isNear(_ lhs: Double, _ rhs: Double, tolerance: Double = 1e-9) -> Bool {
    abs(lhs - rhs) <= tolerance * max(1, abs(lhs), abs(rhs))
}

@Suite("Energy maths, hand-computed")
struct EnergyMathHandComputedTests {
    @Test("BMR takes fractional weight and height at face value")
    func bmrWithFractionalBody() {
        #expect(isNear(NutritionCalculator.bmr(sex: .male, weightKg: 72.5, heightCm: 178.5, age: 29), 1_700.625))
        #expect(isNear(NutritionCalculator.bmr(sex: .female, weightKg: 72.5, heightCm: 178.5, age: 29), 1_534.625))
    }

    @Test("A negative age is not guarded and adds to BMR")
    func bmrWithNegativeAge() {
        #expect(isNear(NutritionCalculator.bmr(sex: .male, weightKg: 70, heightCm: 170, age: -10), 1_817.5))
    }

    @Test("A very large body stays finite and follows the formula exactly")
    func bmrWithVeryLargeBody() {
        #expect(NutritionCalculator.bmr(sex: .male, weightKg: 1e12, heightCm: 0, age: 0) == 10_000_000_000_005)
    }

    @Test(
        "TDEE multiplies BMR by the activity factor at every level",
        arguments: [
            (ActivityLevel.sedentary, 1_841.55),
            (.lightlyActive, 2_110.109375),
            (.moderatelyActive, 2_378.66875),
            (.veryActive, 2_647.228125),
            (.extraActive, 2_915.7875),
        ]
    )
    func tdeeAtEveryLevel(activity: ActivityLevel, expected: Double) {
        #expect(isNear(NutritionCalculator.tdee(bmr: 1_534.625, activity: activity), expected))
    }

    @Test("A negative BMR is multiplied straight through, not floored")
    func tdeeOfNegativeBMR() {
        #expect(isNear(NutritionCalculator.tdee(bmr: -161, activity: .sedentary), -193.2))
    }

    @Test(
        "The whole chain from body to daily target truncates each level's remainder",
        arguments: [
            (ActivityLevel.sedentary, 1_341),
            (.lightlyActive, 1_610),
            (.moderatelyActive, 1_878),
            (.veryActive, 2_147),
            (.extraActive, 2_415),
        ]
    )
    func bodyToTargetChain(activity: ActivityLevel, expected: Int) {
        let bmr = NutritionCalculator.bmr(sex: .female, weightKg: 72.5, heightCm: 178.5, age: 29)
        let tdee = NutritionCalculator.tdee(bmr: bmr, activity: activity)

        #expect(NutritionCalculator.defaultTarget(tdee: tdee, deficit: 500) == expected)
    }

    @Test("Alcohol's 7 kcal per gram converts like any other macro")
    func macroGramsForAlcohol() {
        #expect(isNear(NutritionCalculator.macroGrams(calories: 700, ratio: 0.1, caloriesPerGram: 7), 10))
    }

    @Test("A ratio above 100% is not capped")
    func macroGramsAboveOneHundredPercent() {
        #expect(isNear(NutritionCalculator.macroGrams(calories: 2_000, ratio: 1.5, caloriesPerGram: 4), 750))
    }

    @Test("Negative calories or a negative divisor produce negative grams, only zero is guarded")
    func macroGramsWithNegativeInputs() {
        #expect(isNear(NutritionCalculator.macroGrams(calories: -400, ratio: 0.5, caloriesPerGram: 4), -50))
        #expect(isNear(NutritionCalculator.macroGrams(calories: 2_000, ratio: 0.3, caloriesPerGram: -4), -150))
        #expect(NutritionCalculator.macroGrams(calories: -400, ratio: 0.5, caloriesPerGram: 0) == 0)
        #expect(NutritionCalculator.macroGrams(calories: 2_000, ratio: -0.3, caloriesPerGram: -0.0) == 0)
    }

    @Test("A calorie target at the top of the domain still converts to exact grams")
    func macroGramsAtTheCalorieCeiling() {
        #expect(isNear(NutritionCalculator.macroGrams(calories: 1e9, ratio: 0.3, caloriesPerGram: 4), 75_000_000))
        #expect(isNear(NutritionCalculator.macroGrams(calories: 1e9, ratio: 0.3, caloriesPerGram: 9), 33_333_333.333_333_33))
    }

    @Test("NaN calories come back as NaN rather than a plausible number")
    func macroGramsOfNaN() {
        #expect(NutritionCalculator.macroGrams(calories: .nan, ratio: 0.3, caloriesPerGram: 4).isNaN)
    }

    @Test(
        "A fractional deficit truncates the target either side of a half",
        arguments: [
            (2_500.0, 499.5, 2_000),
            (2_500.0, 500.5, 1_999),
            (1_700.5, 500.0, 1_200),
            (1_701.5, 500.0, 1_201),
        ]
    )
    func fractionalRemainderTruncates(expenditure: Double, deficit: Double, expected: Int) {
        #expect(NutritionCalculator.defaultTarget(energyExpenditure: expenditure, deficit: deficit) == expected)
    }

    @Test("The floor binds just below 1200 and lets exactly 1200 through")
    func floorAtTwelveHundred() {
        #expect(NutritionCalculator.defaultTarget(energyExpenditure: 1_199.999, deficit: 0) == 1_200)
        #expect(NutritionCalculator.defaultTarget(energyExpenditure: 1_200, deficit: 0) == 1_200)
        #expect(NutritionCalculator.defaultTarget(energyExpenditure: 1_201, deficit: 0) == 1_201)
    }

    @Test("A target past the calorie domain is clamped to its ceiling, one at it is kept")
    func ceilingOfTheCalorieDomain() {
        #expect(NutritionCalculator.defaultTarget(energyExpenditure: 1_000_000_500, deficit: 500) == CalorieDomain.maximum)
        #expect(NutritionCalculator.defaultTarget(energyExpenditure: 1_000_000_501, deficit: 500) == CalorieDomain.maximum)
        #expect(NutritionCalculator.defaultTarget(energyExpenditure: 1_000_000_499, deficit: 500) == 999_999_999)
    }

    @Test("A non-finite deficit lands on the floor or the ceiling, never traps")
    func nonFiniteDeficit() {
        #expect(NutritionCalculator.defaultTarget(energyExpenditure: 2_000, deficit: .nan) == 1_200)
        #expect(NutritionCalculator.defaultTarget(energyExpenditure: 2_000, deficit: .infinity) == 1_200)
        #expect(NutritionCalculator.defaultTarget(energyExpenditure: 2_000, deficit: -.infinity) == CalorieDomain.maximum)
    }
}

@Suite("Activity level table")
struct ActivityLevelTableTests {
    @Test(
        "Each level carries its multiplier, name, description and symbol",
        arguments: [
            (ActivityLevel.sedentary, 1.2, "Sedentary", "Little or no exercise, desk job", "figure.seated.side"),
            (.lightlyActive, 1.375, "Lightly Active", "Light exercise 1–3 days/week", "figure.walk"),
            (.moderatelyActive, 1.55, "Moderately Active", "Moderate exercise 3–5 days/week", "figure.run"),
            (.veryActive, 1.725, "Very Active", "Hard exercise 6–7 days/week", "figure.highintensity.intervaltraining"),
            (.extraActive, 1.9, "Extra Active", "Very hard exercise, physical job", "figure.strengthtraining.traditional"),
        ]
    )
    func table(level: ActivityLevel, multiplier: Double, name: String, description: String, icon: String) {
        #expect(level.multiplier == multiplier)
        #expect(level.displayName == name)
        #expect(level.description == description)
        #expect(level.iconName == icon)
    }

    @Test("Levels are offered least to most active, identified by their stored raw value")
    func orderAndIdentity() throws {
        #expect(ActivityLevel.allCases.map(\.id) == [
            "sedentary", "lightlyActive", "moderatelyActive", "veryActive", "extraActive",
        ])
        #expect(ActivityLevel.allCases.allSatisfy { $0.id == $0.rawValue })

        let decoded = try JSONDecoder().decode([ActivityLevel].self, from: Data(#"["veryActive","sedentary"]"#.utf8))
        #expect(decoded == [.veryActive, .sedentary])
    }
}

@Suite("Sex copy")
struct SexCopyTests {
    @Test("Each sex names itself and is identified by its stored raw value", arguments: [
        (Sex.male, "male", "Male"),
        (.female, "female", "Female"),
    ])
    func copy(sex: Sex, raw: String, name: String) {
        #expect(sex.id == raw)
        #expect(sex.rawValue == raw)
        #expect(sex.displayName == name)
    }

    @Test("Male is offered first")
    func order() {
        #expect(Sex.allCases == [.male, .female])
    }
}
