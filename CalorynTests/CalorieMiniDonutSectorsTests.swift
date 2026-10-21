import Foundation
import Testing
@testable import Caloryn

struct CalorieMiniDonutSectorsTests {
    private func sectors(
        _ meals: [MealType: Double],
        budget: Double = 2_000,
        mergesEaten: Bool
    ) -> [CalorieMiniDonutSectors.Sector] {
        let eaten = meals.values.reduce(0, +)
        let summary = CalorieDonutSummary(mealTotals: meals, budget: budget, isOver: eaten > budget)
        return CalorieMiniDonutSectors(sectors: summary.sectors, mergesEaten: mergesEaten).sectors
    }

    @Test("A near-full day paints what was eaten from 12 o'clock and leaves the rest of the plate bare")
    func nearFullDay() {
        let plate = sectors([.dinner: 1_990], mergesEaten: true)

        #expect(plate.map(\.fill) == [.eaten])
        #expect(plate[0].start == 0)
        #expect(abs(plate[0].end - 0.995) < 0.000_001)
        #expect(plate[0].isWholePlate == false)
    }

    @Test("Eating exactly the target fills the whole plate")
    func exactlyOnTarget() {
        let plate = sectors([.dinner: 2_000], mergesEaten: true)

        #expect(plate.map(\.fill) == [.eaten])
        #expect(plate[0].isWholePlate)
    }

    @Test("An over-target day fills the whole plate in one colour, the excess included")
    func overTargetMerged() {
        let plate = sectors([.breakfast: 900, .lunch: 800, .dinner: 600], mergesEaten: true)

        #expect(plate.map(\.fill) == [.eaten])
        #expect(plate[0].isWholePlate)
    }

    @Test("A day with nothing logged paints nothing")
    func nothingLogged() {
        #expect(sectors([:], mergesEaten: true).isEmpty)
        #expect(sectors([:], mergesEaten: false).isEmpty)
        #expect(sectors([:], budget: 0, mergesEaten: false).isEmpty)
    }

    @Test("Meals are painted in meal order, back to back, with no room kept for unlogged ones")
    func mealsInOrder() {
        let plate = sectors([.dinner: 900, .breakfast: 300], mergesEaten: false)

        #expect(plate.map(\.fill) == [.meal(.breakfast), .meal(.dinner)])
        #expect(plate[0].start == 0)
        #expect(abs(plate[0].end - 0.15) < 0.000_001)
        #expect(plate[1].start == plate[0].end)
        #expect(abs(plate[1].end - 0.6) < 0.000_001)
    }

    @Test("Over target, the meals share the target and the excess is painted last, closing the plate")
    func overTargetByMeal() {
        let plate = sectors([.breakfast: 900, .lunch: 800, .dinner: 700], mergesEaten: false)

        #expect(plate.map(\.fill) == [.meal(.breakfast), .meal(.lunch), .meal(.dinner), .over])
        #expect(abs(plate[2].end - 2_000.0 / 2_400.0) < 0.000_001)
        #expect(plate[3].start == plate[2].end)
        #expect(plate[3].end == 1)
        #expect(plate.contains(where: \.isWholePlate) == false)
    }

    @Test("A single meal that meets the target fills the whole plate in that meal's colour")
    func singleMealOnTarget() {
        let plate = sectors([.lunch: 2_000], mergesEaten: false)

        #expect(plate.map(\.fill) == [.meal(.lunch)])
        #expect(plate[0].isWholePlate)
    }
}
