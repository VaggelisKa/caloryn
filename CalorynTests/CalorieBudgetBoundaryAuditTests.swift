import Foundation
import Testing
@testable import Caloryn

nonisolated private let auditTargetOffsets: [(Double, Int)] = [
    (-1, -1),
    (-0.6, -1),
    (-0.5, 0),
    (-0.4, 0),
    (0, 0),
    (0.4, 0),
    (0.5, 1),
    (0.6, 1),
    (1, 1),
]

@MainActor
@Suite("Calorie rounding and domain audit")
struct AuditCalorieRoundingTests {
    @Test(
        "Calorie figures round half away from zero, then stay inside the calorie domain",
        arguments: [
            (0.0, 0),
            (0.49, 0),
            (0.5, 1),
            (-0.49, 0),
            (-0.5, -1),
            (2.5, 3),
            (1_999.5, 2_000),
            (2_000.5, 2_001),
            (999_999_999.5, 1_000_000_000),
            (1_000_000_000.5, 1_000_000_000),
            (1e12, 1_000_000_000),
            (-1e12, -1_000_000_000),
            (Double(Int.max), 1_000_000_000),
            (-Double(Int.max), -1_000_000_000),
        ]
    )
    func roundedCaloriesRoundsAndClamps(value: Double, expected: Int) {
        #expect(value.roundedCalories == expected)
    }

    @Test("A figure that is not a number rounds to zero", arguments: [Double.nan, .infinity, -.infinity])
    func nonFiniteFiguresRoundToZero(value: Double) {
        #expect(value.roundedCalories == 0)
    }

    @Test(
        "The calorie domain clamps at a billion either way and passes everything inside it",
        arguments: [
            (Int.max, 1_000_000_000),
            (1_000_000_001, 1_000_000_000),
            (1_000_000_000, 1_000_000_000),
            (999_999_999, 999_999_999),
            (2_000, 2_000),
            (0, 0),
            (-999_999_999, -999_999_999),
            (-1_000_000_000, -1_000_000_000),
            (-1_000_000_001, -1_000_000_000),
            (Int.min, -1_000_000_000),
        ]
    )
    func domainClampsAtItsBounds(value: Int, expected: Int) {
        #expect(CalorieDomain.clamped(value) == expected)
    }
}

@MainActor
@Suite("Calorie budget target boundary audit")
struct AuditCalorieBudgetTargetBoundaryTests {
    @Test(
        "At, and within a calorie of, the target the budget reports from the rounded total",
        arguments: auditTargetOffsets
    )
    func boundaryAroundTheTarget(offset: Double, roundedOffset: Int) {
        for target in [1_200, 2_000, 2_537] {
            let budget = CalorieBudget(consumed: Double(target) + offset, target: target)

            #expect(budget.target == target)
            #expect(budget.roundedConsumed == target + roundedOffset)
            #expect(budget.remaining == max(0, -roundedOffset))
            #expect(budget.overAmount == max(0, roundedOffset))
            #expect(budget.isOver == (roundedOffset > 0))
        }
    }

    @Test("Exactly on the target the day is neither over nor has anything left")
    func exactlyOnTheTarget() {
        let budget = CalorieBudget(consumed: 2_000, target: 2_000)

        #expect(budget.isOver == false)
        #expect(budget.remaining == 0)
        #expect(budget.overAmount == 0)
    }

    @Test("One whole calorie either side of the target is one calorie left or one calorie over")
    func oneCalorieEitherSide() {
        let under = CalorieBudget(consumed: 1_999, target: 2_000)
        let over = CalorieBudget(consumed: 2_001, target: 2_000)

        #expect(under.remaining == 1)
        #expect(under.overAmount == 0)
        #expect(under.isOver == false)
        #expect(over.remaining == 0)
        #expect(over.overAmount == 1)
        #expect(over.isOver)
    }

    @Test("A target saved past the calorie domain is clamped before anything is subtracted from it")
    func staticTargetIsClampedIntoTheDomain() {
        let high = CalorieBudget(consumed: 0, target: 5_000_000_000)
        let low = CalorieBudget(consumed: 0, target: -5_000_000_000)

        #expect(high.target == CalorieDomain.maximum)
        #expect(high.remaining == CalorieDomain.maximum)
        #expect(low.target == CalorieDomain.minimum)
        #expect(low.remaining == 0)
        #expect(low.overAmount == -CalorieDomain.minimum)
    }
}

@MainActor
@Suite("Calorie budget negative total audit")
struct AuditCalorieBudgetNegativeTotalTests {
    @Test("A negative total is not floored at zero, so it adds to what is left")
    func negativeTotalIsNotFloored() {
        let budget = CalorieBudget(consumed: -500, target: 2_000)

        #expect(budget.remaining == 2_500)
        #expect(budget.isOver == false)
    }
}
