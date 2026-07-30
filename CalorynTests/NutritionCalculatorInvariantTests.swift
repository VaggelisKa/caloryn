import Foundation
import Testing
@testable import Caloryn

// MARK: - Fixtures

/// A plausible human body used to drive property-based sweeps.
struct NutritionInvariantBody: Sendable, CustomStringConvertible {
    let weightKg: Double
    let heightCm: Double
    let age: Int

    var description: String {
        "\(Int(weightKg))kg/\(Int(heightCm))cm/\(age)y"
    }
}

/// A protein/carb/fat calorie split of the kind the macro sliders can produce.
struct NutritionInvariantMacroSplit: Sendable, CustomStringConvertible {
    let protein: Double
    let carbs: Double
    let fat: Double

    var description: String {
        "P\(Int(protein * 100))/C\(Int(carbs * 100))/F\(Int(fat * 100))"
    }
}

private let plausibleBodies: [NutritionInvariantBody] = [
    NutritionInvariantBody(weightKg: 40, heightCm: 140, age: 18),
    NutritionInvariantBody(weightKg: 52, heightCm: 155, age: 25),
    NutritionInvariantBody(weightKg: 68, heightCm: 165, age: 34),
    NutritionInvariantBody(weightKg: 80, heightCm: 175, age: 45),
    NutritionInvariantBody(weightKg: 95, heightCm: 185, age: 60),
    NutritionInvariantBody(weightKg: 130, heightCm: 195, age: 75),
    NutritionInvariantBody(weightKg: 250, heightCm: 220, age: 100),
]

/// Every split sums to 1.0 and every component sits inside the slider ranges the UI exposes.
private let macroRatioPresets: [NutritionInvariantMacroSplit] = [
    NutritionInvariantMacroSplit(protein: 0.30, carbs: 0.40, fat: 0.30),
    NutritionInvariantMacroSplit(protein: 0.25, carbs: 0.50, fat: 0.25),
    NutritionInvariantMacroSplit(protein: 0.40, carbs: 0.30, fat: 0.30),
    NutritionInvariantMacroSplit(protein: 0.10, carbs: 0.60, fat: 0.30),
    NutritionInvariantMacroSplit(protein: 0.50, carbs: 0.20, fat: 0.30),
    NutritionInvariantMacroSplit(protein: 0.35, carbs: 0.35, fat: 0.30),
    NutritionInvariantMacroSplit(protein: 0.20, carbs: 0.50, fat: 0.30),
    NutritionInvariantMacroSplit(protein: 0.10, carbs: 0.40, fat: 0.50),
]

private let calorieTargets: [Int] = [1_200, 1_450, 1_800, 2_000, 2_350, 3_000, 4_500]

/// A published Mifflin-St Jeor result used as a golden value.
struct NutritionInvariantBMRGolden: Sendable, CustomStringConvertible {
    let sex: Sex
    let weightKg: Double
    let heightCm: Double
    let age: Int
    let expected: Double

    var description: String {
        "\(sex.rawValue) \(Int(weightKg))kg/\(Int(heightCm))cm/\(age)y -> \(expected)"
    }
}

struct NutritionInvariantTDEEGolden: Sendable, CustomStringConvertible {
    let activity: ActivityLevel
    let expected: Double

    var description: String { "\(activity.rawValue) -> \(expected)" }
}

private let proteinKcalPerGram = 4.0
private let carbKcalPerGram = 4.0
private let fatKcalPerGram = 9.0

private func isClose(_ lhs: Double, _ rhs: Double, tolerance: Double = 1e-9) -> Bool {
    abs(lhs - rhs) <= tolerance * max(1, abs(lhs), abs(rhs))
}

// MARK: - BMR properties

@Suite("NutritionCalculator BMR invariants")
struct NutritionCalculatorBMRInvariantTests {
    @Test(
        "Given identical height and age, when weight increases, then BMR increases",
        arguments: Sex.allCases, plausibleBodies
    )
    func heavierBodyBurnsMore(sex: Sex, body: NutritionInvariantBody) {
        let lighter = NutritionCalculator.bmr(
            sex: sex, weightKg: body.weightKg, heightCm: body.heightCm, age: body.age
        )
        let heavier = NutritionCalculator.bmr(
            sex: sex, weightKg: body.weightKg + 10, heightCm: body.heightCm, age: body.age
        )

        #expect(heavier > lighter)
        #expect(isClose(heavier - lighter, 100))
    }

    @Test(
        "Given identical weight and age, when height increases, then BMR increases",
        arguments: Sex.allCases, plausibleBodies
    )
    func tallerBodyBurnsMore(sex: Sex, body: NutritionInvariantBody) {
        let shorter = NutritionCalculator.bmr(
            sex: sex, weightKg: body.weightKg, heightCm: body.heightCm, age: body.age
        )
        let taller = NutritionCalculator.bmr(
            sex: sex, weightKg: body.weightKg, heightCm: body.heightCm + 10, age: body.age
        )

        #expect(taller > shorter)
        #expect(isClose(taller - shorter, 62.5))
    }

    @Test(
        "Given identical body size, when age increases, then BMR decreases",
        arguments: Sex.allCases, plausibleBodies
    )
    func olderBodyBurnsLess(sex: Sex, body: NutritionInvariantBody) {
        let younger = NutritionCalculator.bmr(
            sex: sex, weightKg: body.weightKg, heightCm: body.heightCm, age: body.age
        )
        let older = NutritionCalculator.bmr(
            sex: sex, weightKg: body.weightKg, heightCm: body.heightCm, age: body.age + 10
        )

        #expect(older < younger)
        #expect(isClose(younger - older, 50))
    }

    @Test(
        "Given the same body, when sex differs, then male BMR is exactly 166 kcal above female",
        arguments: plausibleBodies
    )
    func sexOffsetIsConstant(body: NutritionInvariantBody) {
        let male = NutritionCalculator.bmr(
            sex: .male, weightKg: body.weightKg, heightCm: body.heightCm, age: body.age
        )
        let female = NutritionCalculator.bmr(
            sex: .female, weightKg: body.weightKg, heightCm: body.heightCm, age: body.age
        )

        #expect(isClose(male - female, 166))
    }

    @Test(
        "Given every sex, when BMR is computed twice for one body, then the result is identical",
        arguments: Sex.allCases, plausibleBodies
    )
    func bmrIsDeterministic(sex: Sex, body: NutritionInvariantBody) {
        let first = NutritionCalculator.bmr(
            sex: sex, weightKg: body.weightKg, heightCm: body.heightCm, age: body.age
        )
        let second = NutritionCalculator.bmr(
            sex: sex, weightKg: body.weightKg, heightCm: body.heightCm, age: body.age
        )

        #expect(first == second)
    }

    @Test(
        "Given a plausible adult body, when BMR is computed, then it is a finite positive value",
        arguments: Sex.allCases, plausibleBodies
    )
    func plausibleBodiesProducePositiveBMR(sex: Sex, body: NutritionInvariantBody) {
        let value = NutritionCalculator.bmr(
            sex: sex, weightKg: body.weightKg, heightCm: body.heightCm, age: body.age
        )

        #expect(value.isFinite)
        #expect(value > 0)
    }

    @Test("Given degenerate zero measurements, when BMR is computed, then only the sex offset remains")
    func degenerateInputsCollapseToSexOffset() {
        #expect(NutritionCalculator.bmr(sex: .male, weightKg: 0, heightCm: 0, age: 0) == 5)
        #expect(NutritionCalculator.bmr(sex: .female, weightKg: 0, heightCm: 0, age: 0) == -161)
    }

    @Test("Given an empty body with a high age, when BMR is computed, then it goes negative unchecked")
    func degenerateInputsCanProduceNegativeBMR() {
        // Characterization: the formula has no floor of its own; callers rely on
        // `defaultTarget` clamping downstream.
        let value = NutritionCalculator.bmr(sex: .female, weightKg: 0, heightCm: 0, age: 100)

        #expect(value == -661)
        #expect(NutritionCalculator.defaultTarget(energyExpenditure: value) == 1_200)
    }

    @Test("Given extreme but representable measurements, when BMR is computed, then it stays finite")
    func extremeInputsStayFinite() {
        let huge = NutritionCalculator.bmr(sex: .male, weightKg: 1_000_000, heightCm: 1_000_000, age: 1_000_000)
        #expect(huge.isFinite)
        #expect(huge > 0)

        let tiny = NutritionCalculator.bmr(sex: .female, weightKg: 0.0001, heightCm: 0.0001, age: 0)
        #expect(tiny.isFinite)
    }

    @Test(
        "Given known Mifflin-St Jeor inputs, when BMR is computed, then it matches the published value",
        arguments: [
            NutritionInvariantBMRGolden(sex: .female, weightKg: 60, heightCm: 165, age: 25, expected: 1_345.25),
            NutritionInvariantBMRGolden(sex: .male, weightKg: 100, heightCm: 190, age: 55, expected: 1_917.5),
            NutritionInvariantBMRGolden(sex: .female, weightKg: 45, heightCm: 150, age: 70, expected: 876.5),
            NutritionInvariantBMRGolden(sex: .male, weightKg: 55, heightCm: 160, age: 18, expected: 1_465),
            NutritionInvariantBMRGolden(sex: .female, weightKg: 120, heightCm: 175, age: 33, expected: 1_967.75),
        ]
    )
    func goldenBMRValues(golden: NutritionInvariantBMRGolden) {
        let value = NutritionCalculator.bmr(
            sex: golden.sex, weightKg: golden.weightKg, heightCm: golden.heightCm, age: golden.age
        )
        #expect(isClose(value, golden.expected, tolerance: 1e-9))
    }
}

// MARK: - TDEE properties

@Suite("NutritionCalculator TDEE invariants")
struct NutritionCalculatorTDEEInvariantTests {
    @Test("Given the activity ladder, when each level is applied, then daily burn never decreases")
    func activityLadderIsMonotonic() {
        let bmr = 1_600.0
        let burns = ActivityLevel.allCases.map { NutritionCalculator.tdee(bmr: bmr, activity: $0) }

        #expect(burns == burns.sorted())
        #expect(Set(burns).count == ActivityLevel.allCases.count, "Each activity level should be distinguishable")
    }

    @Test(
        "Given a positive BMR, when any activity level is applied, then daily burn exceeds BMR",
        arguments: ActivityLevel.allCases, [800.0, 1_200.0, 1_600.0, 2_400.0]
    )
    func anyActivityLevelRaisesBurnAboveBMR(activity: ActivityLevel, bmr: Double) {
        let burn = NutritionCalculator.tdee(bmr: bmr, activity: activity)

        #expect(burn > bmr)
        #expect(isClose(burn, bmr * activity.multiplier))
    }

    @Test(
        "Given each activity level, when BMR grows, then daily burn grows with it",
        arguments: ActivityLevel.allCases
    )
    func burnIsMonotonicInBMR(activity: ActivityLevel) {
        var previous = -Double.infinity
        for bmr in stride(from: 500.0, through: 3_000.0, by: 250.0) {
            let burn = NutritionCalculator.tdee(bmr: bmr, activity: activity)
            #expect(burn > previous)
            previous = burn
        }
    }

    @Test(
        "Given a zero BMR, when any activity level is applied, then daily burn is zero",
        arguments: ActivityLevel.allCases
    )
    func zeroBMRProducesZeroBurn(activity: ActivityLevel) {
        #expect(NutritionCalculator.tdee(bmr: 0, activity: activity) == 0)
    }

    @Test(
        "Given a full body sweep, when BMR feeds TDEE, then the ordering across activity levels is preserved",
        arguments: Sex.allCases, plausibleBodies
    )
    func orderingHoldsAcrossTheInputSpace(sex: Sex, body: NutritionInvariantBody) {
        let bmr = NutritionCalculator.bmr(
            sex: sex, weightKg: body.weightKg, heightCm: body.heightCm, age: body.age
        )
        let burns = ActivityLevel.allCases.map { NutritionCalculator.tdee(bmr: bmr, activity: $0) }

        #expect(burns == burns.sorted())
    }

    @Test(
        "Given a BMR of 1730, when each activity level is applied, then the golden burn is produced",
        arguments: [
            NutritionInvariantTDEEGolden(activity: .sedentary, expected: 2_076),
            NutritionInvariantTDEEGolden(activity: .lightlyActive, expected: 2_378.75),
            NutritionInvariantTDEEGolden(activity: .moderatelyActive, expected: 2_681.5),
            NutritionInvariantTDEEGolden(activity: .veryActive, expected: 2_984.25),
            NutritionInvariantTDEEGolden(activity: .extraActive, expected: 3_287),
        ]
    )
    func goldenTDEEValues(golden: NutritionInvariantTDEEGolden) {
        #expect(isClose(NutritionCalculator.tdee(bmr: 1_730, activity: golden.activity), golden.expected))
    }
}

// MARK: - Macro properties

@Suite("NutritionCalculator macro invariants")
struct NutritionCalculatorMacroInvariantTests {
    @Test(
        "Given a macro split that totals 100%, when grams are converted back to calories, then they reconcile with the target",
        arguments: macroRatioPresets, calorieTargets
    )
    func macroGramsReconcileWithTheCalorieTarget(preset: NutritionInvariantMacroSplit, target: Int) {
        let calories = Double(target)
        let protein = NutritionCalculator.macroGrams(
            calories: calories, ratio: preset.protein, caloriesPerGram: proteinKcalPerGram
        )
        let carbs = NutritionCalculator.macroGrams(
            calories: calories, ratio: preset.carbs, caloriesPerGram: carbKcalPerGram
        )
        let fat = NutritionCalculator.macroGrams(
            calories: calories, ratio: preset.fat, caloriesPerGram: fatKcalPerGram
        )

        let reconstructed = protein * proteinKcalPerGram + carbs * carbKcalPerGram + fat * fatKcalPerGram
        #expect(abs(reconstructed - calories) <= 0.5, "Reconstructed \(reconstructed) vs target \(calories)")
    }

    @Test("Given every selectable macro preset, when the components are summed, then they total 100%")
    func presetsSumToOneHundredPercent() {
        for preset in macroRatioPresets {
            #expect(isClose(preset.protein + preset.carbs + preset.fat, 1.0, tolerance: 1e-9))
        }
    }

    @Test(
        "Given every selectable macro preset, when grams are computed, then no target is negative",
        arguments: macroRatioPresets, calorieTargets
    )
    func presetsNeverProduceNegativeGramTargets(preset: NutritionInvariantMacroSplit, target: Int) {
        let calories = Double(target)
        let grams = [
            NutritionCalculator.macroGrams(calories: calories, ratio: preset.protein, caloriesPerGram: proteinKcalPerGram),
            NutritionCalculator.macroGrams(calories: calories, ratio: preset.carbs, caloriesPerGram: carbKcalPerGram),
            NutritionCalculator.macroGrams(calories: calories, ratio: preset.fat, caloriesPerGram: fatKcalPerGram),
        ]

        for value in grams {
            #expect(value.isFinite)
            #expect(value >= 0)
        }
    }

    @Test(
        "Given a fixed ratio, when the calorie target grows, then the gram target grows proportionally",
        arguments: macroRatioPresets
    )
    func gramsScaleLinearlyWithCalories(preset: NutritionInvariantMacroSplit) {
        let single = NutritionCalculator.macroGrams(
            calories: 1_000, ratio: preset.protein, caloriesPerGram: proteinKcalPerGram
        )
        let double = NutritionCalculator.macroGrams(
            calories: 2_000, ratio: preset.protein, caloriesPerGram: proteinKcalPerGram
        )

        #expect(isClose(double, single * 2))
    }

    @Test(
        "Given a fixed ratio and calories, when calories-per-gram rises, then fewer grams are required",
        arguments: calorieTargets
    )
    func denserMacrosRequireFewerGrams(target: Int) {
        let carbGrams = NutritionCalculator.macroGrams(
            calories: Double(target), ratio: 0.3, caloriesPerGram: carbKcalPerGram
        )
        let fatGrams = NutritionCalculator.macroGrams(
            calories: Double(target), ratio: 0.3, caloriesPerGram: fatKcalPerGram
        )

        #expect(fatGrams < carbGrams)
    }

    @Test("Given a zero ratio or zero calories, when grams are computed, then the target is zero")
    func degenerateMacroInputsProduceZeroGrams() {
        #expect(NutritionCalculator.macroGrams(calories: 2_000, ratio: 0, caloriesPerGram: 4) == 0)
        #expect(NutritionCalculator.macroGrams(calories: 0, ratio: 0.3, caloriesPerGram: 9) == 0)
        #expect(NutritionCalculator.macroGrams(calories: 0, ratio: 0, caloriesPerGram: 4) == 0)
    }

    @Test("Given a zero calories-per-gram divisor, when grams are computed, then the result is a finite zero")
    func zeroDivisorYieldsZeroRatherThanANonFiniteValue() {
        // A zero divisor has no meaningful answer. Returning 0 keeps a bad
        // input from propagating as a plausible-looking infinity into a macro
        // target and only failing much later, at the formatter.
        let withCalories = NutritionCalculator.macroGrams(calories: 2_000, ratio: 0.3, caloriesPerGram: 0)
        #expect(withCalories == 0)

        let withoutCalories = NutritionCalculator.macroGrams(calories: 0, ratio: 0, caloriesPerGram: 0)
        #expect(withoutCalories == 0)
    }

    @Test("Given a non-finite expenditure, when the default target is computed, then it stays representable")
    func nonFiniteExpenditureDoesNotTrapTheTargetConversion() {
        // `Int(_:)` traps on a non-finite Double, and this is the one place
        // `defaultTarget` converts one. The ceiling is the calorie domain
        // rather than `Int.max`, because callers subtract from this number and
        // sum it across a period — `Int.max` only moves the trap there.
        #expect(NutritionCalculator.defaultTarget(energyExpenditure: .nan) == 1_200)
        #expect(NutritionCalculator.defaultTarget(energyExpenditure: -.infinity) == 1_200)
        #expect(NutritionCalculator.defaultTarget(energyExpenditure: .infinity) == CalorieDomain.maximum)
        #expect(NutritionCalculator.defaultTarget(energyExpenditure: 1e30) == CalorieDomain.maximum)
    }

    @Test(
        "Given identical macro inputs, when grams are computed twice, then the result is identical",
        arguments: macroRatioPresets
    )
    func macroGramsAreDeterministic(preset: NutritionInvariantMacroSplit) {
        let first = NutritionCalculator.macroGrams(calories: 2_137, ratio: preset.carbs, caloriesPerGram: 4)
        let second = NutritionCalculator.macroGrams(calories: 2_137, ratio: preset.carbs, caloriesPerGram: 4)

        #expect(first == second)
    }
}

// MARK: - Daily target properties

@Suite("NutritionCalculator daily target invariants")
struct NutritionCalculatorDailyTargetInvariantTests {
    @Test("Given a rising energy expenditure, when the daily target is derived, then it never decreases")
    func targetIsMonotonicInExpenditure() {
        var previous = Int.min
        for expenditure in stride(from: 0.0, through: 5_000.0, by: 50.0) {
            let target = NutritionCalculator.defaultTarget(energyExpenditure: expenditure, deficit: 500)
            #expect(target >= previous)
            previous = target
        }
    }

    @Test("Given a rising deficit, when the daily target is derived, then it never increases")
    func targetIsAntitonicInDeficit() {
        var previous = Int.max
        for deficit in stride(from: 0.0, through: 1_500.0, by: 25.0) {
            let target = NutritionCalculator.defaultTarget(energyExpenditure: 2_600, deficit: deficit)
            #expect(target <= previous)
            previous = target
        }
    }

    @Test(
        "Given any expenditure and deficit, when the daily target is derived, then it never drops below 1200",
        arguments: [0.0, 500.0, 1_200.0, 1_699.0, 1_700.0, 1_701.0, 3_000.0], [0.0, 250.0, 500.0, 1_000.0, 5_000.0]
    )
    func targetNeverBreaksTheSafetyFloor(expenditure: Double, deficit: Double) {
        #expect(NutritionCalculator.defaultTarget(energyExpenditure: expenditure, deficit: deficit) >= 1_200)
    }

    @Test("Given an expenditure exactly at the floor boundary, when the target is derived, then the floor binds")
    func floorBoundaryBehaviour() {
        #expect(NutritionCalculator.defaultTarget(energyExpenditure: 1_699.99, deficit: 500) == 1_200)
        #expect(NutritionCalculator.defaultTarget(energyExpenditure: 1_700, deficit: 500) == 1_200)
        #expect(NutritionCalculator.defaultTarget(energyExpenditure: 1_701, deficit: 500) == 1_201)
    }

    @Test("Given a fractional remainder, when the daily target is derived, then it truncates rather than rounds")
    func fractionalTargetsTruncate() {
        // Characterization: `Int(...)` truncates toward zero; 1900.99 - 500 = 1400.99 -> 1400.
        #expect(NutritionCalculator.defaultTarget(energyExpenditure: 1_900.99, deficit: 500) == 1_400)
        #expect(NutritionCalculator.defaultTarget(energyExpenditure: 2_000.5, deficit: 0) == 2_000)
    }

    @Test("Given a negative expenditure, when the daily target is derived, then the floor still applies")
    func negativeExpenditureIsFloored() {
        #expect(NutritionCalculator.defaultTarget(energyExpenditure: -5_000, deficit: 500) == 1_200)
    }

    @Test("Given a negative deficit, when the daily target is derived, then it becomes a surplus")
    func negativeDeficitBecomesSurplus() {
        #expect(NutritionCalculator.defaultTarget(energyExpenditure: 2_000, deficit: -300) == 2_300)
    }

    @Test(
        "Given the tdee-labelled overload, when it is called, then it matches the energy-expenditure overload",
        arguments: [1_000.0, 1_700.0, 2_480.0, 3_600.0], [0.0, 300.0, 500.0, 900.0]
    )
    func bothOverloadsAgree(value: Double, deficit: Double) {
        #expect(
            NutritionCalculator.defaultTarget(tdee: value, deficit: deficit)
                == NutritionCalculator.defaultTarget(energyExpenditure: value, deficit: deficit)
        )
    }

    @Test("Given no explicit deficit, when the daily target is derived, then a 500 kcal deficit is applied")
    func defaultDeficitIsFiveHundred() {
        #expect(NutritionCalculator.defaultTarget(energyExpenditure: 2_600) == 2_100)
        #expect(NutritionCalculator.defaultTarget(tdee: 2_600) == 2_100)
    }

    @Test(
        "Given any body and activity level, when the whole pipeline runs, then targets are safe and macros reconcile",
        arguments: Sex.allCases, plausibleBodies
    )
    func endToEndPipelineStaysCoherent(sex: Sex, body: NutritionInvariantBody) {
        for activity in ActivityLevel.allCases {
            let bmr = NutritionCalculator.bmr(
                sex: sex, weightKg: body.weightKg, heightCm: body.heightCm, age: body.age
            )
            let tdee = NutritionCalculator.tdee(bmr: bmr, activity: activity)
            let target = NutritionCalculator.defaultTarget(tdee: tdee, deficit: 500)

            #expect(target >= 1_200)

            for preset in macroRatioPresets {
                let protein = NutritionCalculator.macroGrams(
                    calories: Double(target), ratio: preset.protein, caloriesPerGram: proteinKcalPerGram
                )
                let carbs = NutritionCalculator.macroGrams(
                    calories: Double(target), ratio: preset.carbs, caloriesPerGram: carbKcalPerGram
                )
                let fat = NutritionCalculator.macroGrams(
                    calories: Double(target), ratio: preset.fat, caloriesPerGram: fatKcalPerGram
                )

                #expect(protein >= 0 && carbs >= 0 && fat >= 0)

                let reconstructed = protein * proteinKcalPerGram + carbs * carbKcalPerGram + fat * fatKcalPerGram
                #expect(abs(reconstructed - Double(target)) <= 0.5)
            }
        }
    }

    @Test(
        "Given the same profile inputs, when the pipeline runs twice, then it yields the same target",
        arguments: Sex.allCases, ActivityLevel.allCases
    )
    func pipelineIsDeterministic(sex: Sex, activity: ActivityLevel) {
        func run() -> Int {
            let bmr = NutritionCalculator.bmr(sex: sex, weightKg: 72.5, heightCm: 178, age: 37)
            return NutritionCalculator.defaultTarget(
                tdee: NutritionCalculator.tdee(bmr: bmr, activity: activity),
                deficit: 500
            )
        }

        #expect(run() == run())
    }

    @Test(
        "Given the same body, when the activity level rises, then the daily calorie target never falls",
        arguments: Sex.allCases, plausibleBodies
    )
    func moreActivityNeverLowersTheTarget(sex: Sex, body: NutritionInvariantBody) {
        let bmr = NutritionCalculator.bmr(
            sex: sex, weightKg: body.weightKg, heightCm: body.heightCm, age: body.age
        )
        let targets = ActivityLevel.allCases.map {
            NutritionCalculator.defaultTarget(tdee: NutritionCalculator.tdee(bmr: bmr, activity: $0), deficit: 500)
        }

        #expect(targets == targets.sorted())
    }
}
