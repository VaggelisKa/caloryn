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
    static func drillDownDayDetail() -> HistoryDayDetail {
        let profile = previewProfile()
        let day = date(dayOffset: 0)

        return HistoryDayDetail(
            date: day,
            entries: drillDownEntries(for: day),
            dailyCalorieTarget: profile.dailyCalorieTarget
        )
    }

    @MainActor
    static func drillDownWeekSummary() -> HistoryWeekSummary {
        let profile = previewProfile()
        let calendar = Calendar.current
        let weekStart = date(dayOffset: 0).startOfWeek
        let days = (0..<7).compactMap { offset -> HistoryDaySummary? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart) else {
                return nil
            }

            let entries: [FoodLogEntry]
            switch offset {
            case 0:
                entries = drillDownEntries(for: day)
            case 1:
                entries = []
            case 2:
                entries = [entry(for: .under, date: day, mealType: .lunch)]
            case 3:
                entries = [entry(for: .onTrack, date: day, mealType: .dinner)]
            case 4:
                entries = [entry(for: .over, date: day, mealType: .dinner)]
            default:
                entries = [entry(for: .onTrack, date: day, mealType: .breakfast)]
            }

            return HistoryDaySummary(
                date: day,
                entries: entries,
                dailyCalorieTarget: profile.dailyCalorieTarget
            )
        }

        return HistoryWeekSummary(startDate: weekStart, days: days)
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

    @MainActor
    static func drillDownEntries(for date: Date) -> [FoodLogEntry] {
        [
            entry(
                name: "Greek yogurt",
                caloriesPer100g: 85,
                proteinPer100g: 9,
                carbsPer100g: 7,
                fatPer100g: 2,
                fiberPer100g: 0,
                nutriscoreGrade: "a",
                mealType: .breakfast,
                portionGrams: 180,
                date: date
            ),
            entry(
                name: "Blueberries",
                caloriesPer100g: 57,
                proteinPer100g: 0.7,
                carbsPer100g: 14,
                fatPer100g: 0.3,
                fiberPer100g: 2.4,
                nutriscoreGrade: "a",
                produceKind: .fruit,
                mealType: .breakfast,
                portionGrams: 90,
                date: date
            ),
            entry(
                name: "Chicken rice bowl",
                caloriesPer100g: 172,
                proteinPer100g: 13,
                carbsPer100g: 21,
                fatPer100g: 4.5,
                fiberPer100g: 2,
                nutriscoreGrade: "b",
                mealType: .lunch,
                portionGrams: 420,
                date: date
            ),
            entry(
                name: "Apple",
                caloriesPer100g: 52,
                proteinPer100g: 0.3,
                carbsPer100g: 14,
                fatPer100g: 0.2,
                fiberPer100g: 2.4,
                nutriscoreGrade: "a",
                produceKind: .fruit,
                mealType: .snack,
                portionGrams: 160,
                date: date
            ),
            entry(
                name: "Salmon",
                caloriesPer100g: 208,
                proteinPer100g: 20,
                carbsPer100g: 0,
                fatPer100g: 13,
                fiberPer100g: 0,
                nutriscoreGrade: "b",
                mealType: .dinner,
                portionGrams: 180,
                date: date
            ),
            entry(
                name: "Broccoli",
                caloriesPer100g: 35,
                proteinPer100g: 2.4,
                carbsPer100g: 7,
                fatPer100g: 0.4,
                fiberPer100g: 3.3,
                nutriscoreGrade: "a",
                produceKind: .vegetable,
                mealType: .dinner,
                portionGrams: 140,
                date: date
            )
        ]
    }

    @MainActor
    static func entry(
        for plan: HistoryPreviewDayPlan,
        date: Date,
        mealType: MealType
    ) -> FoodLogEntry {
        entry(
            name: "Preview meal",
            caloriesPer100g: plan.calories,
            proteinPer100g: plan.proteinG,
            carbsPer100g: plan.carbsG,
            fatPer100g: plan.fatG,
            fiberPer100g: plan.fiberG,
            nutriscoreGrade: plan.nutriscoreGrade,
            mealType: mealType,
            portionGrams: 100,
            date: date
        )
    }

    @MainActor
    static func entry(
        name: String,
        caloriesPer100g: Double,
        proteinPer100g: Double,
        carbsPer100g: Double,
        fatPer100g: Double,
        fiberPer100g: Double,
        nutriscoreGrade: String?,
        produceKind: ProduceKind? = nil,
        mealType: MealType,
        portionGrams: Double,
        date: Date
    ) -> FoodLogEntry {
        let food = FoodItem(
            name: name,
            caloriesPer100g: caloriesPer100g,
            proteinPer100g: proteinPer100g,
            carbsPer100g: carbsPer100g,
            fatPer100g: fatPer100g,
            fiberPer100g: fiberPer100g,
            nutriscoreGrade: nutriscoreGrade,
            produceKind: produceKind
        )

        return FoodLogEntry(
            date: date,
            mealType: mealType,
            foodItem: food,
            portionGrams: portionGrams
        )
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
