import SwiftData
import SwiftUI

struct MealSectionView: View {
    let mealType: MealType
    let entries: [FoodLogEntry]
    var snackIndex: Int
    var titleOverride: String?
    var onAdd: () -> Void
    var onEdit: (FoodLogEntry) -> Void
    var onDelete: (FoodLogEntry) -> Void

    init(
        mealType: MealType,
        entries: [FoodLogEntry],
        snackIndex: Int = 0,
        titleOverride: String? = nil,
        onAdd: @escaping () -> Void,
        onEdit: @escaping (FoodLogEntry) -> Void,
        onDelete: @escaping (FoodLogEntry) -> Void
    ) {
        self.mealType = mealType
        self.entries = entries
        self.snackIndex = snackIndex
        self.titleOverride = titleOverride
        self.onAdd = onAdd
        self.onEdit = onEdit
        self.onDelete = onDelete
    }

    private var sectionTitle: String {
        if let titleOverride { return titleOverride }
        return mealType == .snack ? mealType.displayName(snackIndex: snackIndex) : mealType.displayName
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
        Section {
            if entries.isEmpty {
                EmptyMealRow()
            } else {
                ForEach(entries) { entry in
                    Button {
                        onEdit(entry)
                    } label: {
                        MealEntryRow(entry: entry)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            onEdit(entry)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(CalorynTheme.sage)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            onDelete(entry)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .accessibilityHint("Double tap to edit")
                }
            }
        } header: {
            Button(action: onAdd) {
                sectionHeader
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add food to \(sectionTitle)")
            .accessibilityHint("Double tap to add food")
        }
    }

    private var sectionHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: mealType.iconName)
                .foregroundStyle(CalorynTheme.sage)
                .font(CalorynTheme.compactIcon)

            Text(sectionTitle)
                .font(CalorynTheme.caption)
                .foregroundStyle(CalorynTheme.textSecondary)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if !totalCalories.isZero {
                    Text(totalCalories.kcalFormatted)
                        .font(CalorynTheme.numericMicroCaption)
                        .foregroundStyle(CalorynTheme.textSecondary)
                }

                if !entries.isEmpty {
                    HStack(spacing: 6) {
                        if !totalProtein.isZero {
                            Text("\(totalProtein.macroFormatted) P")
                                .font(CalorynTheme.numericMicroCaption)
                                .foregroundStyle(CalorynTheme.proteinColor)
                        }
                        if !totalCarbs.isZero {
                            Text("\(totalCarbs.macroFormatted) C")
                                .font(CalorynTheme.numericMicroCaption)
                                .foregroundStyle(CalorynTheme.carbColor)
                        }
                        if !totalFat.isZero {
                            Text("\(totalFat.macroFormatted) F")
                                .font(CalorynTheme.numericMicroCaption)
                                .foregroundStyle(CalorynTheme.fatColor)
                        }
                    }
                }
            }

            Image(systemName: "plus.circle.fill")
                .font(.system(.title3, weight: .semibold))
                .foregroundStyle(CalorynTheme.sage)
        }
        .contentShape(Rectangle())
    }
}

private struct EmptyMealRow: View {
    var body: some View {
        Text("No foods logged yet")
            .font(CalorynTheme.caption)
            .foregroundStyle(CalorynTheme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}

private struct MealEntryRow: View {
    let entry: FoodLogEntry

    @AppStorage("showNutriscore") private var showNutriscore = true

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(entry.foodName)
                        .font(CalorynTheme.itemTitle)
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

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(entry.calories.rounded()))")
                    .font(CalorynTheme.numericBody)
                    .foregroundStyle(CalorynTheme.textPrimary)

                Text("kcal")
                    .font(CalorynTheme.numericMicroCaption)
                    .foregroundStyle(CalorynTheme.textSecondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
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

    return List {
        MealSectionView(
            mealType: .breakfast,
            entries: entries,
            onAdd: {},
            onEdit: { _ in },
            onDelete: { _ in }
        )
    }
    .listStyle(.insetGrouped)
}

#Preview("Empty") {
    List {
        MealSectionView(
            mealType: .lunch,
            entries: [],
            onAdd: {},
            onEdit: { _ in },
            onDelete: { _ in }
        )
    }
    .listStyle(.insetGrouped)
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

    return List {
        MealSectionView(
            mealType: .snack,
            entries: [entry],
            snackIndex: 1,
            onAdd: {},
            onEdit: { _ in },
            onDelete: { _ in }
        )
    }
    .listStyle(.insetGrouped)
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

    return List {
        MealSectionView(
            mealType: .snack,
            entries: [entry],
            snackIndex: 1,
            onAdd: {},
            onEdit: { _ in },
            onDelete: { _ in }
        )
    }
    .listStyle(.insetGrouped)
}
