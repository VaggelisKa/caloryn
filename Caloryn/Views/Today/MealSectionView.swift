import SwiftData
import SwiftUI

struct MealSectionView: View {
    let mealType: MealType
    let entries: [FoodLogEntry]
    var snackIndex: Int
    var onAdd: () -> Void
    var onDelete: (FoodLogEntry) -> Void

    @State private var entryToDelete: FoodLogEntry?

    init(mealType: MealType, entries: [FoodLogEntry], snackIndex: Int = 0, onAdd: @escaping () -> Void, onDelete: @escaping (FoodLogEntry) -> Void) {
        self.mealType = mealType
        self.entries = entries
        self.snackIndex = snackIndex
        self.onAdd = onAdd
        self.onDelete = onDelete
    }

    private var sectionTitle: String {
        mealType == .snack ? mealType.displayName(snackIndex: snackIndex) : mealType.displayName
    }

    private var totalCalories: Double {
        entries.reduce(0) { $0 + $1.calories }
    }

    private var totalProtein: Double {
        entries.reduce(0) { $0 + $1.proteinG }
    }

    private var totalCarbs: Double {
        entries.reduce(0) { $0 + $1.carbsG }
    }

    private var totalFat: Double {
        entries.reduce(0) { $0 + $1.fatG }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onAdd) {
                HStack {
                    Image(systemName: mealType.iconName)
                        .foregroundStyle(CalorynTheme.sage)
                        .font(CalorynTheme.inlineIcon)

                    Text(sectionTitle)
                        .font(CalorynTheme.itemTitle)
                        .foregroundStyle(CalorynTheme.textPrimary)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        if !totalCalories.isZero {
                            Text(totalCalories.kcalFormatted)
                                .font(CalorynTheme.numericCaption)
                                .foregroundStyle(CalorynTheme.textSecondary)
                        }

                        if !entries.isEmpty {
                            HStack(spacing: 6) {
                                if !totalProtein.isZero {
                                    Text("\(totalProtein.macroFormatted) P")
                                        .font(CalorynTheme.numericCaption)
                                        .foregroundStyle(CalorynTheme.proteinColor)
                                }
                                if !totalCarbs.isZero {
                                    Text("\(totalCarbs.macroFormatted) C")
                                        .font(CalorynTheme.numericCaption)
                                        .foregroundStyle(CalorynTheme.carbColor)
                                }
                                if !totalFat.isZero {
                                    Text("\(totalFat.macroFormatted) F")
                                        .font(CalorynTheme.numericCaption)
                                        .foregroundStyle(CalorynTheme.fatColor)
                                }
                            }
                        }
                    }

                    Image(systemName: "plus.circle.fill")
                        .font(CalorynTheme.inlineIcon)
                        .foregroundStyle(CalorynTheme.sage)
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add food to \(sectionTitle)")
            .accessibilityHint("Double tap to add food")

            if entries.isEmpty {
                Button(action: onAdd) {
                    VStack(spacing: 4) {
                        Text("No food logged yet")
                            .font(CalorynTheme.caption)
                            .foregroundStyle(CalorynTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add food to \(sectionTitle)")
            } else {
                ForEach(entries) { entry in
                    MealEntryRow(entry: entry) {
                        entryToDelete = entry
                    }
                    if entry.id != entries.last?.id {
                        Divider()
                            .foregroundStyle(CalorynTheme.stone.opacity(0.3))
                    }
                }
            }
        }
        .glassCard()
        .confirmationDialog(
            "Delete Entry",
            isPresented: Binding(
                get: { entryToDelete != nil },
                set: { if !$0 { entryToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let entry = entryToDelete {
                    onDelete(entry)
                    entryToDelete = nil
                }
            }
        } message: {
            if let entry = entryToDelete {
                Text("Remove \(entry.foodName) from \(sectionTitle)?")
            }
        }
    }
}

private struct MealEntryRow: View {
    let entry: FoodLogEntry
    var onDelete: () -> Void

    @AppStorage("showNutriscore") private var showNutriscore = true

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.foodName)
                        .font(CalorynTheme.bodyText)
                        .foregroundStyle(CalorynTheme.textPrimary)
                        .lineLimit(1)

                    if showNutriscore, let grade = entry.foodItem?.nutriscoreGrade {
                        NutriscoreBadge(grade: grade)
                    }
                }

                Text(entry.proteinG.isZero
                     ? "\(Int(entry.portionGrams))g"
                     : "\(Int(entry.portionGrams))g · \(entry.proteinG.macroFormatted) protein")
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)
            }

            Spacer()

            HStack(spacing: 12) {
                Text(entry.calories.kcalFormatted)
                    .font(CalorynTheme.numericCaption)
                    .foregroundStyle(CalorynTheme.textPrimary)

                Button(action: onDelete) {
                    Image(systemName: "minus.circle")
                        .font(CalorynTheme.compactIcon)
                        .foregroundStyle(CalorynTheme.terracotta.opacity(0.7))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete \(entry.foodName)")
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview("With entries") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: FoodItem.self, FoodLogEntry.self, RecipeIngredient.self, configurations: config)
    let context = ModelContext(container)

    let oatmeal = FoodItem(name: "Oatmeal", caloriesPer100g: 389, proteinPer100g: 16.9, carbsPer100g: 66.3, fatPer100g: 6.9)
    let apple = FoodItem(name: "Apple", caloriesPer100g: 52, proteinPer100g: 0.3, carbsPer100g: 14, fatPer100g: 0.2, nutriscoreGrade: "a")
    [oatmeal, apple].forEach { context.insert($0) }

    let entries = [
        FoodLogEntry(date: .now, mealType: .breakfast, foodItem: oatmeal, portionGrams: 80),
        FoodLogEntry(date: .now, mealType: .breakfast, foodItem: apple, portionGrams: 120),
    ]
    entries.forEach { context.insert($0) }
    try? context.save()

    return MealSectionView(
        mealType: .breakfast,
        entries: entries,
        onAdd: {},
        onDelete: { _ in }
    )
    .padding()
}

#Preview("Empty") {
    MealSectionView(
        mealType: .lunch,
        entries: [],
        onAdd: {},
        onDelete: { _ in }
    )
    .padding()
}

#Preview("Snack") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: FoodItem.self, FoodLogEntry.self, RecipeIngredient.self, configurations: config)
    let context = ModelContext(container)

    let yogurt = FoodItem(name: "Greek Yogurt", caloriesPer100g: 97, proteinPer100g: 9, carbsPer100g: 3.5, fatPer100g: 5)
    context.insert(yogurt)

    let entry = FoodLogEntry(date: .now, mealType: .snack, foodItem: yogurt, portionGrams: 150, snackIndex: 1)
    context.insert(entry)
    try? context.save()

    return MealSectionView(
        mealType: .snack,
        entries: [entry],
        snackIndex: 1,
        onAdd: {},
        onDelete: { _ in }
    )
    .padding()
}

#Preview("Snack with Nutriscore") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: FoodItem.self, FoodLogEntry.self, RecipeIngredient.self, configurations: config)
    let context = ModelContext(container)

    let yogurt = FoodItem(
        name: "Skyr Yogurt",
        caloriesPer100g: 62,
        proteinPer100g: 11,
        carbsPer100g: 3.5,
        fatPer100g: 0.2,
        nutriscoreGrade: "a"
    )
    context.insert(yogurt)

    let entry = FoodLogEntry(date: .now, mealType: .snack, foodItem: yogurt, portionGrams: 150, snackIndex: 1)
    context.insert(entry)
    try? context.save()

    return MealSectionView(
        mealType: .snack,
        entries: [entry],
        snackIndex: 1,
        onAdd: {},
        onDelete: { _ in }
    )
    .padding()
}
