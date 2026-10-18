import Foundation
import Testing
@testable import Caloryn

private func isNear(_ lhs: Double, _ rhs: Double, tolerance: Double = 1e-9) -> Bool {
    abs(lhs - rhs) <= tolerance * max(1, abs(lhs), abs(rhs))
}

// MARK: - BMR, TDEE, macro grams and the default target, by hand

@Suite("Energy maths, hand-computed")
struct EnergyMathHandComputedTests {

    @Test("BMR takes fractional weight and height at face value")
    func bmrWithFractionalBody() {
        // 10 × 72.5 + 6.25 × 178.5 − 5 × 29 = 725 + 1115.625 − 145 = 1695.625
        #expect(isNear(NutritionCalculator.bmr(sex: .male, weightKg: 72.5, heightCm: 178.5, age: 29), 1_700.625))
        #expect(isNear(NutritionCalculator.bmr(sex: .female, weightKg: 72.5, heightCm: 178.5, age: 29), 1_534.625))
    }

    @Test("A negative age is not guarded and adds to BMR")
    func bmrWithNegativeAge() {
        // 10 × 70 + 6.25 × 170 − 5 × (−10) + 5 = 700 + 1062.5 + 50 + 5
        #expect(isNear(NutritionCalculator.bmr(sex: .male, weightKg: 70, heightCm: 170, age: -10), 1_817.5))
    }

    @Test("A very large body stays finite and follows the formula exactly")
    func bmrWithVeryLargeBody() {
        // 10 × 1e12 + 0 − 0 + 5
        #expect(NutritionCalculator.bmr(sex: .male, weightKg: 1e12, heightCm: 0, age: 0) == 10_000_000_000_005)
    }

    @Test(
        "TDEE multiplies BMR by the activity factor at every level",
        arguments: [
            // 1534.625 × 1.2, × 1.375, × 1.55, × 1.725, × 1.9
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
        // −161 × 1.2
        #expect(isNear(NutritionCalculator.tdee(bmr: -161, activity: .sedentary), -193.2))
    }

    @Test(
        "The whole chain from body to daily target truncates each level's remainder",
        arguments: [
            // female 72.5 kg / 178.5 cm / 29 y: BMR 1534.625, TDEE as above, minus 500, truncated
            (ActivityLevel.sedentary, 1_341),       // 1341.55
            (.lightlyActive, 1_610),                // 1610.109375
            (.moderatelyActive, 1_878),             // 1878.66875
            (.veryActive, 2_147),                   // 2147.228125
            (.extraActive, 2_415),                  // 2415.7875
        ]
    )
    func bodyToTargetChain(activity: ActivityLevel, expected: Int) {
        let bmr = NutritionCalculator.bmr(sex: .female, weightKg: 72.5, heightCm: 178.5, age: 29)
        let tdee = NutritionCalculator.tdee(bmr: bmr, activity: activity)

        #expect(NutritionCalculator.defaultTarget(tdee: tdee, deficit: 500) == expected)
    }

    @Test("Alcohol's 7 kcal per gram converts like any other macro")
    func macroGramsForAlcohol() {
        // 700 × 0.1 / 7
        #expect(isNear(NutritionCalculator.macroGrams(calories: 700, ratio: 0.1, caloriesPerGram: 7), 10))
    }

    @Test("A ratio above 100% is not capped")
    func macroGramsAboveOneHundredPercent() {
        // 2000 × 1.5 / 4
        #expect(isNear(NutritionCalculator.macroGrams(calories: 2_000, ratio: 1.5, caloriesPerGram: 4), 750))
    }

    @Test("Negative calories or a negative divisor produce negative grams, only zero is guarded")
    func macroGramsWithNegativeInputs() {
        // −400 × 0.5 / 4 and 2000 × 0.3 / −4
        #expect(isNear(NutritionCalculator.macroGrams(calories: -400, ratio: 0.5, caloriesPerGram: 4), -50))
        #expect(isNear(NutritionCalculator.macroGrams(calories: 2_000, ratio: 0.3, caloriesPerGram: -4), -150))
    }

    @Test("A calorie target at the top of the domain still converts to exact grams")
    func macroGramsAtTheCalorieCeiling() {
        // 1e9 × 0.3 / 4 and 1e9 × 0.3 / 9
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
            (2_500.0, 499.5, 2_000),   // 2000.5 → 2000
            (2_500.0, 500.5, 1_999),   // 1999.5 → 1999
            (1_700.5, 500.0, 1_200),   // 1200.5 → 1200
            (1_701.5, 500.0, 1_201),   // 1201.5 → 1201
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
        // 1_000_000_500 − 500 = 1_000_000_000, exactly the ceiling
        #expect(NutritionCalculator.defaultTarget(energyExpenditure: 1_000_000_500, deficit: 500) == CalorieDomain.maximum)
        // 1_000_000_501 − 500 = 1_000_000_001, one past it
        #expect(NutritionCalculator.defaultTarget(energyExpenditure: 1_000_000_501, deficit: 500) == CalorieDomain.maximum)
        // 999_999_999 + 500 − 500 stays as it is
        #expect(NutritionCalculator.defaultTarget(energyExpenditure: 1_000_000_499, deficit: 500) == 999_999_999)
    }

    @Test("A non-finite deficit lands on the floor or the ceiling, never traps")
    func nonFiniteDeficit() {
        // 2000 − NaN is NaN, and `max` returns the floor for NaN.
        #expect(NutritionCalculator.defaultTarget(energyExpenditure: 2_000, deficit: .nan) == 1_200)
        // 2000 − ∞ = −∞ → floor; 2000 − (−∞) = +∞ → ceiling.
        #expect(NutritionCalculator.defaultTarget(energyExpenditure: 2_000, deficit: .infinity) == 1_200)
        #expect(NutritionCalculator.defaultTarget(energyExpenditure: 2_000, deficit: -.infinity) == CalorieDomain.maximum)
    }
}

// MARK: - What each choice is called

@Suite("Energy calculation mode copy")
struct EnergyCalculationModeCopyTests {

    @Test(
        "Each mode names itself and explains itself in the words Settings shows",
        arguments: [
            (EnergyCalculationMode.lifestyleEstimate, "lifestyleEstimate", "Activity Level Estimate", "Uses your selected activity level."),
            (.dynamicHealth, "dynamicHealth", "Auto-adjust Calories", "Uses Apple Health when activity data is available."),
        ]
    )
    func copy(mode: EnergyCalculationMode, raw: String, name: String, description: String) {
        #expect(mode.id == raw)
        #expect(mode.rawValue == raw)
        #expect(mode.displayName == name)
        #expect(mode.shortDescription == description)
    }

    @Test("The persisted raw values decode back to their modes")
    func rawValuesDecode() throws {
        let decoded = try JSONDecoder().decode(
            [EnergyCalculationMode].self,
            from: Data(#"["lifestyleEstimate","dynamicHealth"]"#.utf8)
        )

        #expect(decoded == [.lifestyleEstimate, .dynamicHealth])
        #expect(EnergyCalculationMode(rawValue: "legacy") == nil)
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
