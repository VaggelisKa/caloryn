import Foundation
import SwiftData

@Model
final class UserProfile {
    var id: UUID = UUID()
    var age: Int = 0
    var sex: Sex = Sex.male
    var heightCm: Double = 0
    var weightKg: Double = 0
    var activityLevel: ActivityLevel = ActivityLevel.sedentary
    var energyCalculationModeRaw: String = EnergyCalculationMode.lifestyleEstimate.rawValue

    var bmr: Double = 0
    var tdee: Double = 0
    var dailyCalorieTarget: Int = 0
    var manualOverride: Bool = false

    var calorieDeficit: Double = 500

    var proteinTargetG: Double = 0
    var carbTargetG: Double = 0
    var fatTargetG: Double = 0
    var fiberTargetG: Double = 0
    var sugarsTargetG: Double = 0
    var addedSugarsTargetG: Double = 0
    var saturatedFatTargetG: Double = 0
    var sodiumTargetG: Double = 0
    var cholesterolTargetG: Double = 0
    var alcoholTargetG: Double = 0

    var fiberGoalEnabled: Bool = false
    var sugarsGoalEnabled: Bool = false
    var addedSugarsGoalEnabled: Bool = false
    var saturatedFatGoalEnabled: Bool = false
    var sodiumGoalEnabled: Bool = false
    var cholesterolGoalEnabled: Bool = false
    var alcoholGoalEnabled: Bool = false

    var proteinGoalKindRaw: String = NutrientGoalKind.minimum.rawValue
    var carbGoalKindRaw: String = NutrientGoalKind.target.rawValue
    var fatGoalKindRaw: String = NutrientGoalKind.target.rawValue
    var fiberGoalKindRaw: String = NutrientGoalKind.minimum.rawValue
    var sugarsGoalKindRaw: String = NutrientGoalKind.maximum.rawValue
    var addedSugarsGoalKindRaw: String = NutrientGoalKind.maximum.rawValue
    var saturatedFatGoalKindRaw: String = NutrientGoalKind.maximum.rawValue
    var sodiumGoalKindRaw: String = NutrientGoalKind.maximum.rawValue
    var cholesterolGoalKindRaw: String = NutrientGoalKind.maximum.rawValue
    var alcoholGoalKindRaw: String = NutrientGoalKind.maximum.rawValue

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        age: Int,
        sex: Sex,
        heightCm: Double,
        weightKg: Double,
        activityLevel: ActivityLevel,
        dailyCalorieTarget: Int? = nil,
        manualOverride: Bool = false,
        calorieDeficit: Double = 500,
        energyCalculationMode: EnergyCalculationMode = .lifestyleEstimate,
        proteinRatio: Double = 0.30,
        carbRatio: Double = 0.40,
        fatRatio: Double = 0.30,
        fiberTargetG: Double = 0
    ) {
        self.id = UUID()
        self.age = age
        self.sex = sex
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.activityLevel = activityLevel
        self.energyCalculationModeRaw = energyCalculationMode.rawValue
        self.manualOverride = manualOverride
        self.calorieDeficit = calorieDeficit
        self.createdAt = Date()
        self.updatedAt = Date()

        let computedBmr = NutritionCalculator.bmr(sex: sex, weightKg: weightKg, heightCm: heightCm, age: age)
        let computedTdee = NutritionCalculator.tdee(bmr: computedBmr, activity: activityLevel)
        let target = dailyCalorieTarget ?? NutritionCalculator.defaultTarget(tdee: computedTdee, deficit: calorieDeficit)

        self.bmr = computedBmr
        self.tdee = computedTdee
        self.dailyCalorieTarget = target
        self.proteinTargetG = NutritionCalculator.macroGrams(calories: Double(target), ratio: proteinRatio, caloriesPerGram: 4)
        self.carbTargetG = NutritionCalculator.macroGrams(calories: Double(target), ratio: carbRatio, caloriesPerGram: 4)
        self.fatTargetG = NutritionCalculator.macroGrams(calories: Double(target), ratio: fatRatio, caloriesPerGram: 9)
        self.fiberTargetG = fiberTargetG
    }

    var energyCalculationMode: EnergyCalculationMode {
        get {
            EnergyCalculationMode(rawValue: energyCalculationModeRaw) ?? .lifestyleEstimate
        }
        set {
            energyCalculationModeRaw = newValue.rawValue
        }
    }

    var effectiveEnergyCalculationMode: EnergyCalculationMode {
        manualOverride ? .lifestyleEstimate : energyCalculationMode
    }

    var macroRatios: (protein: Double, carbs: Double, fat: Double) {
        let calories = Double(max(dailyCalorieTarget, 1))
        return (
            protein: (proteinTargetG * 4.0) / calories,
            carbs: (carbTargetG * 4.0) / calories,
            fat: (fatTargetG * 9.0) / calories
        )
    }

    func recalculate(proteinRatio: Double = 0.30, carbRatio: Double = 0.40, fatRatio: Double = 0.30) {
        bmr = NutritionCalculator.bmr(sex: sex, weightKg: weightKg, heightCm: heightCm, age: age)
        tdee = NutritionCalculator.tdee(bmr: bmr, activity: activityLevel)
        if !manualOverride {
            dailyCalorieTarget = NutritionCalculator.defaultTarget(tdee: tdee, deficit: calorieDeficit)
        }
        proteinTargetG = NutritionCalculator.macroGrams(calories: Double(dailyCalorieTarget), ratio: proteinRatio, caloriesPerGram: 4)
        carbTargetG = NutritionCalculator.macroGrams(calories: Double(dailyCalorieTarget), ratio: carbRatio, caloriesPerGram: 4)
        fatTargetG = NutritionCalculator.macroGrams(calories: Double(dailyCalorieTarget), ratio: fatRatio, caloriesPerGram: 9)
        updatedAt = Date()
    }

    var activeEnergyBaseCalorieTarget: Int {
        guard !manualOverride else { return dailyCalorieTarget }
        return NutritionCalculator.defaultTarget(energyExpenditure: bmr, deficit: calorieDeficit)
    }

    func calorieBaseTarget(usesActiveEnergy: Bool) -> Int {
        usesActiveEnergy ? activeEnergyBaseCalorieTarget : dailyCalorieTarget
    }

    func activityBudget(
        consumed: Double,
        activeEnergyKcal: Double,
        recentActiveEnergySamples: [DailyActiveEnergySample],
        isActivityLoading: Bool,
        activityMessage: String?,
        date: Date
    ) -> ActivityCalorieBudget {
        ActivityCalorieBudget(
            consumed: consumed,
            staticTarget: dailyCalorieTarget,
            bmr: bmr,
            calorieDeficit: calorieDeficit,
            activeEnergyKcal: activeEnergyKcal,
            recentActiveEnergySamples: recentActiveEnergySamples,
            calculationMode: effectiveEnergyCalculationMode,
            isManualOverride: manualOverride,
            isActivityLoading: isActivityLoading,
            activityMessage: activityMessage,
            date: date
        )
    }

    func nutrientTargets(forCalorieTarget calorieTarget: Int? = nil) -> [TrackedNutrient: Double] {
        var targets = nutrientTargets

        if let calorieTarget {
            let ratios = macroRatios
            targets[.protein] = NutritionCalculator.macroGrams(
                calories: Double(calorieTarget),
                ratio: ratios.protein,
                caloriesPerGram: 4
            )
            targets[.carbs] = NutritionCalculator.macroGrams(
                calories: Double(calorieTarget),
                ratio: ratios.carbs,
                caloriesPerGram: 4
            )
            targets[.fat] = NutritionCalculator.macroGrams(
                calories: Double(calorieTarget),
                ratio: ratios.fat,
                caloriesPerGram: 9
            )
        }

        return targets
    }

    var nutrientTargets: [TrackedNutrient: Double] {
        TrackedNutrient.allCases.reduce(into: [TrackedNutrient: Double]()) { targets, nutrient in
            if let target = target(for: nutrient) {
                targets[nutrient] = target
            }
        }
    }

    var nutrientGoalKinds: [TrackedNutrient: NutrientGoalKind] {
        TrackedNutrient.allCases.reduce(into: [TrackedNutrient: NutrientGoalKind]()) { kinds, nutrient in
            kinds[nutrient] = goalKind(for: nutrient)
        }
    }

    func target(for nutrient: TrackedNutrient) -> Double? {
        let value: Double
        switch nutrient {
        case .protein:
            value = proteinTargetG
        case .carbs:
            value = carbTargetG
        case .fat:
            value = fatTargetG
        case .fiber:
            value = fiberTargetG
        case .sugars:
            value = sugarsTargetG
        case .addedSugars:
            value = addedSugarsTargetG
        case .saturatedFat:
            value = saturatedFatTargetG
        case .sodium:
            value = sodiumTargetG
        case .cholesterol:
            value = cholesterolTargetG
        case .alcohol:
            value = alcoholTargetG
        }

        return isGoalEnabled(for: nutrient) && value > 0 ? value : nil
    }

    func setTarget(_ target: Double?, for nutrient: TrackedNutrient) {
        let value = max(target ?? 0, 0)
        switch nutrient {
        case .protein:
            proteinTargetG = value
        case .carbs:
            carbTargetG = value
        case .fat:
            fatTargetG = value
        case .fiber:
            fiberTargetG = value
            fiberGoalEnabled = value > 0
        case .sugars:
            sugarsTargetG = value
            sugarsGoalEnabled = value > 0
        case .addedSugars:
            addedSugarsTargetG = value
            addedSugarsGoalEnabled = value > 0
        case .saturatedFat:
            saturatedFatTargetG = value
            saturatedFatGoalEnabled = value > 0
        case .sodium:
            sodiumTargetG = value
            sodiumGoalEnabled = value > 0
        case .cholesterol:
            cholesterolTargetG = value
            cholesterolGoalEnabled = value > 0
        case .alcohol:
            alcoholTargetG = value
            alcoholGoalEnabled = value > 0
        }
        updatedAt = Date()
    }

    func isGoalEnabled(for nutrient: TrackedNutrient) -> Bool {
        switch nutrient {
        case .protein, .carbs, .fat:
            true
        case .fiber:
            fiberGoalEnabled
        case .sugars:
            sugarsGoalEnabled
        case .addedSugars:
            addedSugarsGoalEnabled
        case .saturatedFat:
            saturatedFatGoalEnabled
        case .sodium:
            sodiumGoalEnabled
        case .cholesterol:
            cholesterolGoalEnabled
        case .alcohol:
            alcoholGoalEnabled
        }
    }

    func goalKind(for nutrient: TrackedNutrient) -> NutrientGoalKind {
        let rawValue: String
        switch nutrient {
        case .protein:
            rawValue = proteinGoalKindRaw
        case .carbs:
            rawValue = carbGoalKindRaw
        case .fat:
            rawValue = fatGoalKindRaw
        case .fiber:
            rawValue = fiberGoalKindRaw
        case .sugars:
            rawValue = sugarsGoalKindRaw
        case .addedSugars:
            rawValue = addedSugarsGoalKindRaw
        case .saturatedFat:
            rawValue = saturatedFatGoalKindRaw
        case .sodium:
            rawValue = sodiumGoalKindRaw
        case .cholesterol:
            rawValue = cholesterolGoalKindRaw
        case .alcohol:
            rawValue = alcoholGoalKindRaw
        }
        return NutrientGoalKind(rawValue: rawValue) ?? nutrient.defaultGoalKind
    }

    func setGoalKind(_ kind: NutrientGoalKind, for nutrient: TrackedNutrient) {
        switch nutrient {
        case .protein:
            proteinGoalKindRaw = kind.rawValue
        case .carbs:
            carbGoalKindRaw = kind.rawValue
        case .fat:
            fatGoalKindRaw = kind.rawValue
        case .fiber:
            fiberGoalKindRaw = kind.rawValue
        case .sugars:
            sugarsGoalKindRaw = kind.rawValue
        case .addedSugars:
            addedSugarsGoalKindRaw = kind.rawValue
        case .saturatedFat:
            saturatedFatGoalKindRaw = kind.rawValue
        case .sodium:
            sodiumGoalKindRaw = kind.rawValue
        case .cholesterol:
            cholesterolGoalKindRaw = kind.rawValue
        case .alcohol:
            alcoholGoalKindRaw = kind.rawValue
        }
        updatedAt = Date()
    }
}
