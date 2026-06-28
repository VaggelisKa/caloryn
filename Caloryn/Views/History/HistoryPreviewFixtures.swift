#if DEBUG
import SwiftData
import SwiftUI

enum HistoryPreviewScenario: String, CaseIterable, Identifiable {
    case empty
    case lowCoverage
    case mostlyOnTrack
    case mostlyUnder
    case mostlyOver
    case macroMisses
    case quarterWeekly

    var id: String { rawValue }

    var initialRange: HistoryRange {
        switch self {
        case .empty, .mostlyOnTrack, .mostlyUnder, .mostlyOver:
            .week
        case .lowCoverage:
            .twoWeeks
        case .macroMisses:
            .month
        case .quarterWeekly:
            .quarter
        }
    }

    var title: String {
        switch self {
        case .empty:
            "Empty"
        case .lowCoverage:
            "Low Coverage"
        case .mostlyOnTrack:
            "Mostly On Track"
        case .mostlyUnder:
            "Mostly Under"
        case .mostlyOver:
            "Mostly Over"
        case .macroMisses:
            "Macro Misses"
        case .quarterWeekly:
            "90-Day Weekly"
        }
    }
}

enum HistoryPreviewFixtures {
    @MainActor
    static func preview(for scenario: HistoryPreviewScenario) -> some View {
        HistoryView(initialRange: scenario.initialRange)
            .modelContainer(try! container(for: scenario))
    }

    @MainActor
    static func analytics(for scenario: HistoryPreviewScenario) -> HistoryAnalytics {
        let profile = previewProfile()
        let entries = datedPlans(for: scenario).compactMap { datedPlan -> FoodLogEntry? in
            guard let plan = datedPlan.plan else { return nil }
            let food = FoodItem(
                name: "\(scenario.title) Day \(datedPlan.dayOffset + 1)",
                caloriesPer100g: plan.calories,
                proteinPer100g: plan.proteinG,
                carbsPer100g: plan.carbsG,
                fatPer100g: plan.fatG,
                fiberPer100g: plan.fiberG,
                nutriscoreGrade: plan.nutriscoreGrade
            )
            return FoodLogEntry(
                date: date(dayOffset: datedPlan.dayOffset),
                mealType: MealType.allCases[datedPlan.dayOffset % MealType.allCases.count],
                foodItem: food,
                portionGrams: 100
            )
        }

        return HistoryAnalytics(
            entries: entries,
            profile: profile,
            range: scenario.initialRange
        )
    }

    @MainActor
    static func container(for scenario: HistoryPreviewScenario) throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: UserProfile.self,
            FoodItem.self,
            FoodLogEntry.self,
            RecipeIngredient.self,
            configurations: config
        )
        let context = ModelContext(container)
        let profile = previewProfile()
        context.insert(profile)

        for datedPlan in datedPlans(for: scenario) {
            guard let plan = datedPlan.plan else { continue }
            let food = FoodItem(
                name: "\(scenario.title) Day \(datedPlan.dayOffset + 1)",
                caloriesPer100g: plan.calories,
                proteinPer100g: plan.proteinG,
                carbsPer100g: plan.carbsG,
                fatPer100g: plan.fatG,
                fiberPer100g: plan.fiberG,
                nutriscoreGrade: plan.nutriscoreGrade
            )
            context.insert(food)

            let entry = FoodLogEntry(
                date: date(dayOffset: datedPlan.dayOffset),
                mealType: MealType.allCases[datedPlan.dayOffset % MealType.allCases.count],
                foodItem: food,
                portionGrams: 100
            )
            context.insert(entry)
        }

        try context.save()
        return container
    }
}

private extension HistoryPreviewFixtures {
    struct DatedPlan {
        let dayOffset: Int
        let plan: HistoryPreviewDayPlan?
    }

    static func previewProfile() -> UserProfile {
        let profile = UserProfile(
            age: 34,
            sex: .male,
            heightCm: 178,
            weightKg: 76,
            activityLevel: .moderatelyActive,
            dailyCalorieTarget: 2_000,
            manualOverride: true,
            proteinRatio: 0.30,
            carbRatio: 0.40,
            fatRatio: 0.30
        )
        profile.setGoalKind(.minimum, for: .protein)
        profile.setGoalKind(.target, for: .carbs)
        profile.setGoalKind(.target, for: .fat)
        return profile
    }

    static func datedPlans(for scenario: HistoryPreviewScenario) -> [DatedPlan] {
        let range = scenario.initialRange
        return plans(for: scenario).enumerated().map { offset, plan in
            DatedPlan(dayOffset: offset, plan: plan)
        } + previousPlans(for: scenario).enumerated().map { offset, plan in
            DatedPlan(dayOffset: range.days + offset, plan: plan)
        }
    }

    static func plans(for scenario: HistoryPreviewScenario) -> [HistoryPreviewDayPlan?] {
        switch scenario {
        case .empty:
            return Array(repeating: nil, count: HistoryRange.week.days)
        case .lowCoverage:
            return [
                .onTrack,
                nil,
                nil,
                .under,
                nil,
                nil,
                nil,
                .over,
                nil,
                nil,
                nil,
                nil,
                .onTrack,
                nil,
            ]
        case .mostlyOnTrack:
            return [.onTrack, .onTrack, .onTrack, .onTrack, .onTrack, .under, .over]
        case .mostlyUnder:
            return [.under, .under, .under, .under, .under, .onTrack, nil]
        case .mostlyOver:
            return [.over, .over, .over, .over, .over, .onTrack, .over]
        case .macroMisses:
            return (0..<HistoryRange.month.days).map { offset in
                if offset % 10 == 0 { return nil }
                if offset % 3 == 0 { return .lowProteinOnCalories }
                if offset % 3 == 1 { return .highCarbOnCalories }
                return .lowFatOnCalories
            }
        case .quarterWeekly:
            return quarterPlans()
        }
    }

    static func previousPlans(for scenario: HistoryPreviewScenario) -> [HistoryPreviewDayPlan?] {
        switch scenario {
        case .empty:
            return Array(repeating: nil, count: HistoryRange.week.days)
        case .lowCoverage:
            return [.under, nil, .onTrack, nil, nil, nil, nil, nil, nil, .over, nil, nil, nil, nil]
        case .mostlyOnTrack:
            return [.under, .over, .onTrack, nil, .under, .over, nil]
        case .mostlyUnder:
            return [.onTrack, .onTrack, .onTrack, .under, .under, nil, nil]
        case .mostlyOver:
            return [.onTrack, .onTrack, .under, nil, .over, nil, nil]
        case .macroMisses:
            return (0..<HistoryRange.month.days).map { offset in
                offset % 7 == 0 ? nil : .onTrack
            }
        case .quarterWeekly:
            return quarterPlans(seed: 2)
        }
    }

    static func quarterPlans(seed: Int = 0) -> [HistoryPreviewDayPlan?] {
        (0..<HistoryRange.quarter.days).map { offset in
            if (offset + seed) % 6 == 0 { return nil }

            switch ((offset / 7) + seed) % 4 {
            case 0:
                return .onTrack
            case 1:
                return offset % 2 == 0 ? .onTrack : .under
            case 2:
                return offset % 3 == 0 ? .onTrack : .over
            default:
                return offset % 2 == 0 ? .under : .over
            }
        }
    }

    static func date(dayOffset: Int) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return calendar.date(byAdding: .day, value: -dayOffset, to: today) ?? today
    }
}

private struct HistoryPreviewDayPlan {
    let calories: Double
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let fiberG: Double
    let nutriscoreGrade: String?

    static let under = HistoryPreviewDayPlan(
        calories: 1_720,
        proteinG: 128,
        carbsG: 155,
        fatG: 48,
        fiberG: 24,
        nutriscoreGrade: "b"
    )
    static let onTrack = HistoryPreviewDayPlan(
        calories: 1_990,
        proteinG: 164,
        carbsG: 202,
        fatG: 66,
        fiberG: 31,
        nutriscoreGrade: "a"
    )
    static let over = HistoryPreviewDayPlan(
        calories: 2_280,
        proteinG: 176,
        carbsG: 252,
        fatG: 88,
        fiberG: 22,
        nutriscoreGrade: "c"
    )
    static let lowProteinOnCalories = HistoryPreviewDayPlan(
        calories: 2_010,
        proteinG: 92,
        carbsG: 238,
        fatG: 65,
        fiberG: 26,
        nutriscoreGrade: "b"
    )
    static let highCarbOnCalories = HistoryPreviewDayPlan(
        calories: 1_980,
        proteinG: 158,
        carbsG: 262,
        fatG: 61,
        fiberG: 28,
        nutriscoreGrade: "b"
    )
    static let lowFatOnCalories = HistoryPreviewDayPlan(
        calories: 1_970,
        proteinG: 168,
        carbsG: 204,
        fatG: 44,
        fiberG: 29,
        nutriscoreGrade: "a"
    )
}
#endif
