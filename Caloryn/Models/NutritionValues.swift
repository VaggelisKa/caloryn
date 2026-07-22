import Foundation

struct NutritionValues: Codable, Equatable {
    var calories: Double = 0
    var proteinG: Double = 0
    var carbsG: Double = 0
    var fatG: Double = 0
    var fiberG: Double = 0
    var sugarsG: Double?
    var addedSugarsG: Double?
    var sucroseG: Double?
    var glucoseG: Double?
    var fructoseG: Double?
    var lactoseG: Double?
    var maltoseG: Double?
    var maltodextrinsG: Double?
    var starchG: Double?
    var polyolsG: Double?
    var saturatedFatG: Double?
    var transFatG: Double?
    var monounsaturatedFatG: Double?
    var polyunsaturatedFatG: Double?
    var omega3FatG: Double?
    var omega6FatG: Double?
    var omega9FatG: Double?
    var saltG: Double?
    var sodiumG: Double?
    var cholesterolG: Double?
    var solubleFiberG: Double?
    var insolubleFiberG: Double?
    var caseinG: Double?
    var serumProteinsG: Double?
    var alcoholG: Double?

    nonisolated static let zero = NutritionValues()

    nonisolated init(
        calories: Double = 0,
        proteinG: Double = 0,
        carbsG: Double = 0,
        fatG: Double = 0,
        fiberG: Double = 0,
        sugarsG: Double? = nil,
        addedSugarsG: Double? = nil,
        sucroseG: Double? = nil,
        glucoseG: Double? = nil,
        fructoseG: Double? = nil,
        lactoseG: Double? = nil,
        maltoseG: Double? = nil,
        maltodextrinsG: Double? = nil,
        starchG: Double? = nil,
        polyolsG: Double? = nil,
        saturatedFatG: Double? = nil,
        transFatG: Double? = nil,
        monounsaturatedFatG: Double? = nil,
        polyunsaturatedFatG: Double? = nil,
        omega3FatG: Double? = nil,
        omega6FatG: Double? = nil,
        omega9FatG: Double? = nil,
        saltG: Double? = nil,
        sodiumG: Double? = nil,
        cholesterolG: Double? = nil,
        solubleFiberG: Double? = nil,
        insolubleFiberG: Double? = nil,
        caseinG: Double? = nil,
        serumProteinsG: Double? = nil,
        alcoholG: Double? = nil
    ) {
        self.calories = calories
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.fiberG = fiberG
        self.sugarsG = sugarsG
        self.addedSugarsG = addedSugarsG
        self.sucroseG = sucroseG
        self.glucoseG = glucoseG
        self.fructoseG = fructoseG
        self.lactoseG = lactoseG
        self.maltoseG = maltoseG
        self.maltodextrinsG = maltodextrinsG
        self.starchG = starchG
        self.polyolsG = polyolsG
        self.saturatedFatG = saturatedFatG
        self.transFatG = transFatG
        self.monounsaturatedFatG = monounsaturatedFatG
        self.polyunsaturatedFatG = polyunsaturatedFatG
        self.omega3FatG = omega3FatG
        self.omega6FatG = omega6FatG
        self.omega9FatG = omega9FatG
        self.saltG = saltG
        self.sodiumG = sodiumG
        self.cholesterolG = cholesterolG
        self.solubleFiberG = solubleFiberG
        self.insolubleFiberG = insolubleFiberG
        self.caseinG = caseinG
        self.serumProteinsG = serumProteinsG
        self.alcoholG = alcoholG
    }

    nonisolated func scaled(by multiplier: Double) -> NutritionValues {
        NutritionValues(
            calories: calories * multiplier,
            proteinG: proteinG * multiplier,
            carbsG: carbsG * multiplier,
            fatG: fatG * multiplier,
            fiberG: fiberG * multiplier,
            sugarsG: scaled(sugarsG, by: multiplier),
            addedSugarsG: scaled(addedSugarsG, by: multiplier),
            sucroseG: scaled(sucroseG, by: multiplier),
            glucoseG: scaled(glucoseG, by: multiplier),
            fructoseG: scaled(fructoseG, by: multiplier),
            lactoseG: scaled(lactoseG, by: multiplier),
            maltoseG: scaled(maltoseG, by: multiplier),
            maltodextrinsG: scaled(maltodextrinsG, by: multiplier),
            starchG: scaled(starchG, by: multiplier),
            polyolsG: scaled(polyolsG, by: multiplier),
            saturatedFatG: scaled(saturatedFatG, by: multiplier),
            transFatG: scaled(transFatG, by: multiplier),
            monounsaturatedFatG: scaled(monounsaturatedFatG, by: multiplier),
            polyunsaturatedFatG: scaled(polyunsaturatedFatG, by: multiplier),
            omega3FatG: scaled(omega3FatG, by: multiplier),
            omega6FatG: scaled(omega6FatG, by: multiplier),
            omega9FatG: scaled(omega9FatG, by: multiplier),
            saltG: scaled(saltG, by: multiplier),
            sodiumG: scaled(sodiumG, by: multiplier),
            cholesterolG: scaled(cholesterolG, by: multiplier),
            solubleFiberG: scaled(solubleFiberG, by: multiplier),
            insolubleFiberG: scaled(insolubleFiberG, by: multiplier),
            caseinG: scaled(caseinG, by: multiplier),
            serumProteinsG: scaled(serumProteinsG, by: multiplier),
            alcoholG: scaled(alcoholG, by: multiplier)
        )
    }

    nonisolated static func per100g(
        fromServing servingValues: NutritionValues,
        servingGrams: Double
    ) -> NutritionValues {
        guard servingGrams > 0 else { return .zero }
        return servingValues.scaled(by: 100 / servingGrams)
    }

    nonisolated static func per100g(
        fromPortions portions: [NutritionValues],
        totalGrams: Double
    ) -> NutritionValues {
        guard totalGrams > 0 else { return .zero }
        return portions.reduce(.zero, +).scaled(by: 100 / totalGrams)
    }

    nonisolated func value(for nutrient: TrackedNutrient) -> Double {
        switch nutrient {
        case .protein:
            proteinG
        case .carbs:
            carbsG
        case .fat:
            fatG
        case .fiber:
            fiberG
        case .sugars:
            sugarsG ?? 0
        case .addedSugars:
            addedSugarsG ?? 0
        case .saturatedFat:
            saturatedFatG ?? 0
        case .sodium:
            sodiumG ?? 0
        case .cholesterol:
            cholesterolG ?? 0
        case .alcohol:
            alcoholG ?? 0
        }
    }

    nonisolated static func + (lhs: NutritionValues, rhs: NutritionValues) -> NutritionValues {
        NutritionValues(
            calories: lhs.calories + rhs.calories,
            proteinG: lhs.proteinG + rhs.proteinG,
            carbsG: lhs.carbsG + rhs.carbsG,
            fatG: lhs.fatG + rhs.fatG,
            fiberG: lhs.fiberG + rhs.fiberG,
            sugarsG: sum(lhs.sugarsG, rhs.sugarsG),
            addedSugarsG: sum(lhs.addedSugarsG, rhs.addedSugarsG),
            sucroseG: sum(lhs.sucroseG, rhs.sucroseG),
            glucoseG: sum(lhs.glucoseG, rhs.glucoseG),
            fructoseG: sum(lhs.fructoseG, rhs.fructoseG),
            lactoseG: sum(lhs.lactoseG, rhs.lactoseG),
            maltoseG: sum(lhs.maltoseG, rhs.maltoseG),
            maltodextrinsG: sum(lhs.maltodextrinsG, rhs.maltodextrinsG),
            starchG: sum(lhs.starchG, rhs.starchG),
            polyolsG: sum(lhs.polyolsG, rhs.polyolsG),
            saturatedFatG: sum(lhs.saturatedFatG, rhs.saturatedFatG),
            transFatG: sum(lhs.transFatG, rhs.transFatG),
            monounsaturatedFatG: sum(lhs.monounsaturatedFatG, rhs.monounsaturatedFatG),
            polyunsaturatedFatG: sum(lhs.polyunsaturatedFatG, rhs.polyunsaturatedFatG),
            omega3FatG: sum(lhs.omega3FatG, rhs.omega3FatG),
            omega6FatG: sum(lhs.omega6FatG, rhs.omega6FatG),
            omega9FatG: sum(lhs.omega9FatG, rhs.omega9FatG),
            saltG: sum(lhs.saltG, rhs.saltG),
            sodiumG: sum(lhs.sodiumG, rhs.sodiumG),
            cholesterolG: sum(lhs.cholesterolG, rhs.cholesterolG),
            solubleFiberG: sum(lhs.solubleFiberG, rhs.solubleFiberG),
            insolubleFiberG: sum(lhs.insolubleFiberG, rhs.insolubleFiberG),
            caseinG: sum(lhs.caseinG, rhs.caseinG),
            serumProteinsG: sum(lhs.serumProteinsG, rhs.serumProteinsG),
            alcoholG: sum(lhs.alcoholG, rhs.alcoholG)
        )
    }

    nonisolated private func scaled(_ value: Double?, by multiplier: Double) -> Double? {
        value.map { $0 * multiplier }
    }

    nonisolated private static func sum(_ lhs: Double?, _ rhs: Double?) -> Double? {
        guard lhs != nil || rhs != nil else { return nil }
        return (lhs ?? 0) + (rhs ?? 0)
    }
}

extension FoodItem {
    var nutritionPer100g: NutritionValues {
        get {
            NutritionValues(
                calories: caloriesPer100g,
                proteinG: proteinPer100g,
                carbsG: carbsPer100g,
                fatG: fatPer100g,
                fiberG: fiberPer100g,
                sugarsG: sugarsPer100g,
                addedSugarsG: addedSugarsPer100g,
                sucroseG: sucrosePer100g,
                glucoseG: glucosePer100g,
                fructoseG: fructosePer100g,
                lactoseG: lactosePer100g,
                maltoseG: maltosePer100g,
                maltodextrinsG: maltodextrinsPer100g,
                starchG: starchPer100g,
                polyolsG: polyolsPer100g,
                saturatedFatG: saturatedFatPer100g,
                transFatG: transFatPer100g,
                monounsaturatedFatG: monounsaturatedFatPer100g,
                polyunsaturatedFatG: polyunsaturatedFatPer100g,
                omega3FatG: omega3FatPer100g,
                omega6FatG: omega6FatPer100g,
                omega9FatG: omega9FatPer100g,
                saltG: saltPer100g,
                sodiumG: sodiumPer100g,
                cholesterolG: cholesterolPer100g,
                solubleFiberG: solubleFiberPer100g,
                insolubleFiberG: insolubleFiberPer100g,
                caseinG: caseinPer100g,
                serumProteinsG: serumProteinsPer100g,
                alcoholG: alcoholPer100g
            )
        }
        set {
            caloriesPer100g = newValue.calories
            proteinPer100g = newValue.proteinG
            carbsPer100g = newValue.carbsG
            fatPer100g = newValue.fatG
            fiberPer100g = newValue.fiberG
            sugarsPer100g = newValue.sugarsG
            addedSugarsPer100g = newValue.addedSugarsG
            sucrosePer100g = newValue.sucroseG
            glucosePer100g = newValue.glucoseG
            fructosePer100g = newValue.fructoseG
            lactosePer100g = newValue.lactoseG
            maltosePer100g = newValue.maltoseG
            maltodextrinsPer100g = newValue.maltodextrinsG
            starchPer100g = newValue.starchG
            polyolsPer100g = newValue.polyolsG
            saturatedFatPer100g = newValue.saturatedFatG
            transFatPer100g = newValue.transFatG
            monounsaturatedFatPer100g = newValue.monounsaturatedFatG
            polyunsaturatedFatPer100g = newValue.polyunsaturatedFatG
            omega3FatPer100g = newValue.omega3FatG
            omega6FatPer100g = newValue.omega6FatG
            omega9FatPer100g = newValue.omega9FatG
            saltPer100g = newValue.saltG
            sodiumPer100g = newValue.sodiumG
            cholesterolPer100g = newValue.cholesterolG
            solubleFiberPer100g = newValue.solubleFiberG
            insolubleFiberPer100g = newValue.insolubleFiberG
            caseinPer100g = newValue.caseinG
            serumProteinsPer100g = newValue.serumProteinsG
            alcoholPer100g = newValue.alcoholG
        }
    }

    func nutrition(forGrams grams: Double) -> NutritionValues {
        nutritionPer100g.scaled(by: grams / 100)
    }
}

extension FoodLogEntry {
    var nutrition: NutritionValues {
        NutritionValues(
            calories: calories,
            proteinG: proteinG,
            carbsG: carbsG,
            fatG: fatG,
            fiberG: fiberG,
            sugarsG: sugarsG,
            addedSugarsG: addedSugarsG,
            sucroseG: sucroseG,
            glucoseG: glucoseG,
            fructoseG: fructoseG,
            lactoseG: lactoseG,
            maltoseG: maltoseG,
            maltodextrinsG: maltodextrinsG,
            starchG: starchG,
            polyolsG: polyolsG,
            saturatedFatG: saturatedFatG,
            transFatG: transFatG,
            monounsaturatedFatG: monounsaturatedFatG,
            polyunsaturatedFatG: polyunsaturatedFatG,
            omega3FatG: omega3FatG,
            omega6FatG: omega6FatG,
            omega9FatG: omega9FatG,
            saltG: saltG,
            sodiumG: sodiumG,
            cholesterolG: cholesterolG,
            solubleFiberG: solubleFiberG,
            insolubleFiberG: insolubleFiberG,
            caseinG: caseinG,
            serumProteinsG: serumProteinsG,
            alcoholG: alcoholG
        )
    }
}

extension RecipeIngredient {
    var nutritionPer100g: NutritionValues {
        NutritionValues(
            calories: caloriesPer100g,
            proteinG: proteinPer100g,
            carbsG: carbsPer100g,
            fatG: fatPer100g,
            fiberG: fiberPer100g,
            sugarsG: sugarsPer100g,
            addedSugarsG: addedSugarsPer100g,
            sucroseG: sucrosePer100g,
            glucoseG: glucosePer100g,
            fructoseG: fructosePer100g,
            lactoseG: lactosePer100g,
            maltoseG: maltosePer100g,
            maltodextrinsG: maltodextrinsPer100g,
            starchG: starchPer100g,
            polyolsG: polyolsPer100g,
            saturatedFatG: saturatedFatPer100g,
            transFatG: transFatPer100g,
            monounsaturatedFatG: monounsaturatedFatPer100g,
            polyunsaturatedFatG: polyunsaturatedFatPer100g,
            omega3FatG: omega3FatPer100g,
            omega6FatG: omega6FatPer100g,
            omega9FatG: omega9FatPer100g,
            saltG: saltPer100g,
            sodiumG: sodiumPer100g,
            cholesterolG: cholesterolPer100g,
            solubleFiberG: solubleFiberPer100g,
            insolubleFiberG: insolubleFiberPer100g,
            caseinG: caseinPer100g,
            serumProteinsG: serumProteinsPer100g,
            alcoholG: alcoholPer100g
        )
    }

    var nutrition: NutritionValues {
        nutritionPer100g.scaled(by: portionGrams / 100)
    }
}

extension RecipeIngredientDraft {
    var nutritionPer100g: NutritionValues {
        NutritionValues(
            calories: caloriesPer100g,
            proteinG: proteinPer100g,
            carbsG: carbsPer100g,
            fatG: fatPer100g,
            fiberG: fiberPer100g,
            sugarsG: sugarsPer100g,
            addedSugarsG: addedSugarsPer100g,
            sucroseG: sucrosePer100g,
            glucoseG: glucosePer100g,
            fructoseG: fructosePer100g,
            lactoseG: lactosePer100g,
            maltoseG: maltosePer100g,
            maltodextrinsG: maltodextrinsPer100g,
            starchG: starchPer100g,
            polyolsG: polyolsPer100g,
            saturatedFatG: saturatedFatPer100g,
            transFatG: transFatPer100g,
            monounsaturatedFatG: monounsaturatedFatPer100g,
            polyunsaturatedFatG: polyunsaturatedFatPer100g,
            omega3FatG: omega3FatPer100g,
            omega6FatG: omega6FatPer100g,
            omega9FatG: omega9FatPer100g,
            saltG: saltPer100g,
            sodiumG: sodiumPer100g,
            cholesterolG: cholesterolPer100g,
            solubleFiberG: solubleFiberPer100g,
            insolubleFiberG: insolubleFiberPer100g,
            caseinG: caseinPer100g,
            serumProteinsG: serumProteinsPer100g,
            alcoholG: alcoholPer100g
        )
    }

    var nutrition: NutritionValues {
        nutritionPer100g.scaled(by: portionGrams / 100)
    }
}
