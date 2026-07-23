#if DEBUG
import SwiftData
import SwiftUI

enum Issue74ScreenshotScenario: String {
    case creation
    case destination
    case reuse
    case missingSource = "missing-source"
    case duplicatePrevention = "duplicate-prevention"

    static var current: Issue74ScreenshotScenario? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flagIndex = arguments.firstIndex(of: "-issue74Screenshot"),
              arguments.indices.contains(flagIndex + 1) else {
            return nil
        }
        return Issue74ScreenshotScenario(rawValue: arguments[flagIndex + 1])
    }
}

struct Issue74ScreenshotHost: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodLogEntry.createdAt) private var entries: [FoodLogEntry]
    @Query(sort: \MealTemplate.updatedAt, order: .reverse) private var templates: [MealTemplate]

    let scenario: Issue74ScreenshotScenario

    @State private var hasSeeded = false
    @State private var duplicateOperationID: UUID?
    @State private var seedError: String?

    private var sourceEntries: [FoodLogEntry] {
        entries.filter { $0.replicationOperationID == nil && $0.foodItem != nil }
    }

    private var missingEntry: FoodLogEntry? {
        entries.first { $0.foodItem == nil }
    }

    private var template: MealTemplate? {
        templates.first
    }

    var body: some View {
        Group {
            if let seedError {
                ContentUnavailableView(
                    "Fixture Failed",
                    systemImage: "xmark.octagon",
                    description: Text(seedError)
                )
            } else if !hasSeeded {
                ProgressView("Preparing meal data…")
            } else {
                scenarioContent
            }
        }
        .task {
            seedIfNeeded()
        }
    }

    @ViewBuilder
    private var scenarioContent: some View {
        switch scenario {
        case .creation:
            MealFormView()
        case .destination:
            FoodSearchView(
                mealType: .lunch,
                logDate: .now,
                automaticallyFocusSearch: false
            )
        case .reuse:
            FoodSearchView(
                mealType: .breakfast,
                logDate: .now,
                automaticallyFocusSearch: false
            )
        case .missingSource:
            FoodSearchView(
                mealType: .lunch,
                logDate: .now,
                automaticallyFocusSearch: false
            )
        case .duplicatePrevention:
            DuplicatePreventionEvidenceView(
                entries: duplicateEntries,
                plannedCount: sourceEntries.count
            )
        }
    }

    private var duplicateEntries: [FoodLogEntry] {
        guard let duplicateOperationID else { return [] }
        return entries
            .filter { $0.replicationOperationID == duplicateOperationID }
            .sorted { ($0.replicationItemIndex ?? 0) < ($1.replicationItemIndex ?? 0) }
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
                produceKind: .unclassified
            )
            let berries = FoodItem(
                name: "Blueberries",
                caloriesPer100g: 57,
                proteinPer100g: 0.7,
                carbsPer100g: 14.5,
                fatPer100g: 0.3,
                fiberPer100g: 2.4,
                nutriscoreGrade: "a",
                produceKind: .fruit
            )
            modelContext.insert(oats)
            modelContext.insert(berries)

            let breakfastDate = Date.now.startOfDay
            let oatsEntry = FoodLogEntry(
                date: breakfastDate,
                mealType: .breakfast,
                foodItem: oats,
                portionGrams: 80,
                snackIndex: 0
            )
            oatsEntry.createdAt = breakfastDate.addingTimeInterval(8 * 3_600)
            let berriesEntry = FoodLogEntry(
                date: breakfastDate,
                mealType: .breakfast,
                foodItem: berries,
                portionGrams: 120,
                snackIndex: 0
            )
            berriesEntry.createdAt = breakfastDate.addingTimeInterval(8 * 3_600 + 1)
            modelContext.insert(oatsEntry)
            modelContext.insert(berriesEntry)

            var archivedSnapshot = FoodLogEntrySnapshot(entry: oatsEntry)
            archivedSnapshot.foodName = "Old Cafe Soup"
            archivedSnapshot.sourceFoodID = UUID()
            archivedSnapshot.portionGrams = 300
            archivedSnapshot.nutrition = NutritionValues(
                calories: 240,
                proteinG: 12,
                carbsG: 30,
                fatG: 8,
                fiberG: 5
            )
            let missing = FoodLogEntry(
                date: breakfastDate,
                mealType: .lunch,
                foodItem: nil,
                snapshot: archivedSnapshot,
                snackIndex: 0
            )
            modelContext.insert(missing)
            try modelContext.save()

            let template = try MealTemplateCommands.createTemplate(
                name: "Morning Bowl",
                entries: [oatsEntry, berriesEntry],
                defaultMeal: .breakfast,
                modelContext: modelContext
            )

            if scenario == .duplicatePrevention {
                let operationID = UUID(uuidString: "74000000-0000-0000-0000-000000000074")!
                let plan = try MealTemplateCommands.plan(
                    sourceName: template.name,
                    snapshots: MealTemplateCommands.snapshots(for: template),
                    destinationDate: breakfastDate,
                    destinationMeal: .lunch,
                    operationID: operationID
                )
                let foods = [oats, berries]
                try MealTemplateCommands.log(
                    plan: plan,
                    availableFoods: foods,
                    modelContext: modelContext
                )
                try MealTemplateCommands.log(
                    plan: plan,
                    availableFoods: foods,
                    modelContext: modelContext
                )
                duplicateOperationID = operationID
            }

            hasSeeded = true
        } catch {
            seedError = error.localizedDescription
        }
    }
}

private struct DuplicatePreventionEvidenceView: View {
    let entries: [FoodLogEntry]
    let plannedCount: Int

    private var preventedDuplicate: Bool {
        plannedCount > 0 && entries.count == plannedCount
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 14) {
                        Image(systemName: preventedDuplicate ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundStyle(preventedDuplicate ? CalorynTheme.sage : CalorynTheme.terracotta)

                        Text(preventedDuplicate ? "Repeated Add Prevented" : "Duplicate Check Failed")
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)

                        Text("The same \(plannedCount)-item commit was submitted twice. \(entries.count) log entries were stored — one complete batch.")
                            .font(CalorynTheme.bodyText)
                            .foregroundStyle(CalorynTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("mealReuse.duplicateEvidence")
                }

                Section("Stored Entries") {
                    ForEach(entries) { entry in
                        HStack {
                            Text(entry.foodName)
                            Spacer()
                            Text(entry.calories.kcalFormatted)
                                .foregroundStyle(CalorynTheme.textSecondary)
                        }
                    }
                }
            }
            .navigationTitle("Duplicate Prevention")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
#else
enum Issue74ScreenshotScenario {
    static var current: Issue74ScreenshotScenario? { nil }
}
#endif
