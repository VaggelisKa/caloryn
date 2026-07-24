#if DEBUG
import SwiftData
import SwiftUI

enum Issue77ScreenshotScenario: String {
    case suggestions
    case review
    case recovery

    static var current: Issue77ScreenshotScenario? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flagIndex = arguments.firstIndex(of: "-issue77Screenshot"),
              arguments.indices.contains(flagIndex + 1) else {
            return nil
        }
        return Issue77ScreenshotScenario(rawValue: arguments[flagIndex + 1])
    }
}

struct Issue77ScreenshotHost: View {
    @Environment(\.modelContext) private var modelContext

    let scenario: Issue77ScreenshotScenario

    @State private var groups: [MultiAddSelectionGroup] = []
    @State private var hasSeeded = false
    @State private var seedError: String?

    var body: some View {
        Group {
            if let seedError {
                ContentUnavailableView(
                    "Fixture Failed",
                    systemImage: "xmark.octagon",
                    description: Text(seedError)
                )
            } else if !hasSeeded {
                ProgressView("Preparing suggestion history…")
            } else {
                scenarioContent
            }
        }
        .task { seedIfNeeded() }
    }

    @ViewBuilder
    private var scenarioContent: some View {
        switch scenario {
        case .suggestions:
            FoodSearchView(
                mealType: .breakfast,
                logDate: Date.now,
                automaticallyFocusSearch: false
            )
        case .review:
            MultiAddReviewView(
                groups: groups,
                initialDate: Date.now,
                initialMeal: .breakfast,
                onLogged: {}
            )
        case .recovery:
            MultiAddReviewView(
                groups: groups.first.map { [$0] } ?? [],
                initialDate: Date.now,
                initialMeal: .lunch,
                operationID: UUID(uuidString: "77000000-0000-0000-0000-000000000077")!,
                initialRecoveryState: MultiAddPartialBatch(
                    operationID: UUID(uuidString: "77000000-0000-0000-0000-000000000077")!,
                    expectedCount: 2,
                    persistedCount: 1,
                    persistedIndices: [0],
                    missingIndices: [1]
                ),
                onLogged: {}
            )
        }
    }

    private func seedIfNeeded() {
        guard !hasSeeded else { return }

        do {
            let oats = FoodItem(
                name: "Rolled Oats",
                caloriesPer100g: 389,
                proteinPer100g: 16.9,
                carbsPer100g: 66.3,
                fatPer100g: 6.9,
                fiberPer100g: 10.6,
                defaultServingG: 80
            )
            let blueberries = FoodItem(
                name: "Blueberries",
                caloriesPer100g: 57,
                proteinPer100g: 0.7,
                carbsPer100g: 14.5,
                fatPer100g: 0.3,
                fiberPer100g: 2.4,
                defaultServingG: 120,
                nutriscoreGrade: "a",
                produceKind: .fruit
            )
            let skyr = FoodItem(
                name: "Vanilla Skyr",
                caloriesPer100g: 68,
                proteinPer100g: 10.5,
                carbsPer100g: 5.1,
                fatPer100g: 0.3,
                defaultServingG: 180,
                nutriscoreGrade: "a"
            )
            oats.id = UUID(uuidString: "77000000-0000-0000-0000-000000000001")!
            blueberries.id = UUID(uuidString: "77000000-0000-0000-0000-000000000002")!
            skyr.id = UUID(uuidString: "77000000-0000-0000-0000-000000000003")!
            [oats, blueberries, skyr].forEach(modelContext.insert)

            for dayOffset in 0...2 {
                let logMoment = Calendar.current.date(
                    byAdding: .day,
                    value: -dayOffset,
                    to: Date.now
                )!
                for (index, food) in [oats, blueberries, skyr].enumerated() {
                    let entry = FoodLogEntry(
                        date: logMoment,
                        mealType: .breakfast,
                        foodItem: food,
                        portionGrams: food.defaultServingG ?? 100,
                        snackIndex: 0
                    )
                    entry.createdAt = logMoment.addingTimeInterval(Double(index))
                    modelContext.insert(entry)
                }
            }
            try modelContext.save()

            let breakfastMeal = try MealTemplateCommands.saveMeal(
                name: "Breakfast Bowl",
                snapshots: [
                    FoodLogEntrySnapshot(
                        foodItem: oats,
                        portionGrams: 80,
                        mealType: .breakfast,
                        snackIndex: 0
                    ),
                    FoodLogEntrySnapshot(
                        foodItem: blueberries,
                        portionGrams: 120,
                        mealType: .breakfast,
                        snackIndex: 0
                    ),
                ],
                modelContext: modelContext
            )
            groups = [
                .meal(
                    breakfastMeal,
                    snapshots: try MealTemplateCommands.snapshots(for: breakfastMeal)
                ),
                .savedFood(
                    skyr,
                    portionGrams: 180,
                    meal: .breakfast,
                    snackIndex: 0
                ),
            ]
            hasSeeded = true
        } catch {
            seedError = error.localizedDescription
        }
    }
}
#else
enum Issue77ScreenshotScenario {
    static var current: Issue77ScreenshotScenario? { nil }
}
#endif
