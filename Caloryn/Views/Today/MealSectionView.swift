import SwiftData
import SwiftUI

struct MealSectionView: View {
    let mealType: MealType
    let entries: [FoodLogEntry]
    var snackIndex: Int
    var titleOverride: String?
    var canCopyYesterday: Bool
    var onAdd: () -> Void
    var onEdit: (FoodLogEntry) -> Void
    var onDelete: (FoodLogEntry) -> Void

    private static let sectionSpacing: CGFloat = 22

    init(
        mealType: MealType,
        entries: [FoodLogEntry],
        snackIndex: Int = 0,
        titleOverride: String? = nil,
        canCopyYesterday: Bool = false,
        onAdd: @escaping () -> Void,
        onEdit: @escaping (FoodLogEntry) -> Void,
        onDelete: @escaping (FoodLogEntry) -> Void
    ) {
        self.mealType = mealType
        self.entries = entries
        self.snackIndex = snackIndex
        self.titleOverride = titleOverride
        self.canCopyYesterday = canCopyYesterday
        self.onAdd = onAdd
        self.onEdit = onEdit
        self.onDelete = onDelete
    }

    private var summary: MealSectionSummary {
        MealSectionSummary(
            mealType: mealType,
            snackIndex: snackIndex,
            titleOverride: titleOverride,
            entries: entries.map {
                MealSectionSummary.Entry(
                    calories: $0.calories,
                    proteinG: $0.proteinG,
                    carbsG: $0.carbsG,
                    fatG: $0.fatG
                )
            }
        )
    }

    var body: some View {
        let summary = summary

        Section {
            CalorynMealSectionHeader(
                meal: mealType,
                title: summary.title,
                totalText: summary.headerTotalText(),
                addAccessibilityIdentifier: "today.mealHeader.\(mealType.rawValue)",
                addAccessibilityLabel: summary.addAccessibilityLabel,
                onAdd: onAdd
            )
            .todayPlateRowLayout(top: Self.sectionSpacing, bottom: 8)
            .listRowSeparator(.hidden, edges: .top)

            if summary.usesSingleRowTransition {
                SingleMealTransitionRow(
                    entry: entries.first,
                    emptyText: summary.emptyRowText(canCopyYesterday: canCopyYesterday),
                    onEdit: onEdit,
                    onDelete: onDelete
                )
                .todayPlateRowLayout()
                .listRowSeparator(.hidden, edges: .bottom)
            } else {
                ForEach(entries) { entry in
                    MealEntryActionRow(
                        entry: entry,
                        onEdit: onEdit,
                        onDelete: onDelete
                    )
                    .todayPlateRowLayout()
                    .listRowSeparator(entry.id == entries.last?.id ? .hidden : .visible, edges: .bottom)
                }
            }
        }
        .calorynHairlineSeparators()
    }
}

extension View {
    func todayPlateRowLayout(top: CGFloat = 0, bottom: CGFloat = 0) -> some View {
        self
            .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
            .alignmentGuide(.listRowSeparatorTrailing) { $0[.trailing] }
            .listRowInsets(
                EdgeInsets(
                    top: top,
                    leading: CalorynTheme.pagePadding,
                    bottom: bottom,
                    trailing: CalorynTheme.pagePadding
                )
            )
    }
}

private struct SingleMealTransitionRow: View {
    let entry: FoodLogEntry?
    let emptyText: String
    let onEdit: (FoodLogEntry) -> Void
    let onDelete: (FoodLogEntry) -> Void

    @State private var pendingDeletionID: UUID?
    @State private var showsPendingEmptyState = false

    private var editableEntry: FoodLogEntry? {
        guard let entry, pendingDeletionID != entry.id else { return nil }
        return entry
    }

    private var isDeletingEntry: Bool {
        guard let entry else { return false }
        return pendingDeletionID == entry.id
    }

    private var showsEmptyState: Bool {
        entry == nil || showsPendingEmptyState
    }

    var body: some View {
        ZStack {
            if let entry {
                MealEntryButtonRow(entry: entry, onEdit: onEdit)
                    .opacity(isDeletingEntry ? 0 : 1)
                    .allowsHitTesting(!isDeletingEntry)
                    .accessibilityHidden(isDeletingEntry)
            }

            EmptyMealRow(text: emptyText)
                .opacity(showsEmptyState ? 1 : 0)
                .accessibilityHidden(!showsEmptyState)
        }
        .animation(.easeIn(duration: 0.16), value: entry?.id)
        .onChange(of: entry?.id) { _, newID in
            if pendingDeletionID != newID {
                pendingDeletionID = nil
                showsPendingEmptyState = false
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if let entry = editableEntry {
                Button {
                    onEdit(entry)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(CalorynTheme.fillAction)
            }
        }
        .swipeActions(edge: .trailing) {
            if let entry = editableEntry {
                Button(role: .destructive) {
                    deleteWithFade(entry)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .tint(CalorynTheme.fillAction)
            }
        }
    }

    private func deleteWithFade(_ entry: FoodLogEntry) {
        guard pendingDeletionID != entry.id else { return }

        withAnimation(.easeOut(duration: 0.14)) {
            pendingDeletionID = entry.id
        } completion: {
            guard pendingDeletionID == entry.id else { return }

            withAnimation(.easeIn(duration: 0.16)) {
                showsPendingEmptyState = true
            } completion: {
                guard pendingDeletionID == entry.id else { return }
                onDelete(entry)
            }
        }
    }
}

private struct MealEntryActionRow: View {
    let entry: FoodLogEntry
    let onEdit: (FoodLogEntry) -> Void
    let onDelete: (FoodLogEntry) -> Void

    var body: some View {
        MealEntryButtonRow(entry: entry, onEdit: onEdit)
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                Button {
                    onEdit(entry)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(CalorynTheme.fillAction)
            }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    onDelete(entry)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .tint(CalorynTheme.fillAction)
            }
    }
}

private struct MealEntryButtonRow: View {
    let entry: FoodLogEntry
    let onEdit: (FoodLogEntry) -> Void

    var body: some View {
        Button {
            onEdit(entry)
        } label: {
            MealEntryRow(entry: entry)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Double tap to edit")
        .accessibilityIdentifier("today.entry.\(entry.foodName)")
    }
}

private struct EmptyMealRow: View {
    let text: String

    var body: some View {
        Text(text)
            .font(TodayPlateFont.emptyRow)
            .foregroundStyle(CalorynTheme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 11)
            .accessibilityElement(children: .combine)
    }
}

private struct MealEntryRow: View {
    let entry: FoodLogEntry

    @AppStorage("showNutriscore") private var showNutriscore = true
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .callout) private var kcalColumnWidth: CGFloat = 44

    private var kcal: Int {
        entry.calories.rounded().truncatedSafely
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        name(lineLimit: 3)
                        badges
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        gramsText
                        kcalText(unit: " kcal")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 8) {
                    name(lineLimit: 1)
                    badges

                    Spacer(minLength: 8)

                    gramsText

                    kcalText(unit: "")
                        .frame(minWidth: kcalColumnWidth, alignment: .trailing)
                }
            }
        }
        .padding(.vertical, 11)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func name(lineLimit: Int) -> some View {
        Text(entry.foodName)
            .font(TodayPlateFont.rowTitle)
            .foregroundStyle(CalorynTheme.textPrimary)
            .lineLimit(lineLimit)
    }

    @ViewBuilder
    private var badges: some View {
        if let food = entry.foodItem, food.isRecipe || food.isCustom {
            TodayTypeBadge(isRecipe: food.isRecipe)
        }

        if showNutriscore, let grade = entry.historicalNutriscoreGrade {
            NutriscoreBadge(grade: grade)
        }
    }

    private var gramsText: some View {
        Text(entry.portionGrams.spacedMacroFormatted)
            .font(TodayPlateFont.rowDetail)
            .foregroundStyle(CalorynTheme.textSecondary)
            .lineLimit(1)
            .fixedSize()
            .accessibilityLabel(TrackedNutrientUnit.grams.spokenFormatted(entry.portionGrams))
    }

    private func kcalText(unit: String) -> some View {
        Text("\(kcal)\(unit)")
            .font(TodayPlateFont.rowValue)
            .foregroundStyle(CalorynTheme.textPrimary)
            .lineLimit(1)
            .fixedSize()
            .accessibilityLabel("\(kcal) kcal")
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
    .calorynPlainListStyle()
    .calorynPageCanvas()
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
    .calorynPlainListStyle()
    .calorynPageCanvas()
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
    .calorynPlainListStyle()
    .calorynPageCanvas()
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
    .calorynPlainListStyle()
    .calorynPageCanvas()
}
