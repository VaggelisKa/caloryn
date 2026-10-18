import SwiftUI

struct CalorynMealSectionHeader: View {
    let meal: MealType
    let title: String
    let totalText: String?
    let addAccessibilityIdentifier: String
    let addAccessibilityLabel: String
    let addAccessibilityHint: String
    let onAdd: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .headline) private var addButtonSize: CGFloat = 30
    @ScaledMetric(relativeTo: .headline) private var plusSize: CGFloat = 14

    init(
        meal: MealType,
        title: String? = nil,
        totalText: String?,
        addAccessibilityIdentifier: String,
        addAccessibilityLabel: String,
        addAccessibilityHint: String = "Double tap to add food or a saved meal",
        onAdd: @escaping () -> Void
    ) {
        self.meal = meal
        self.title = title ?? meal.displayName
        self.totalText = totalText
        self.addAccessibilityIdentifier = addAccessibilityIdentifier
        self.addAccessibilityLabel = addAccessibilityLabel
        self.addAccessibilityHint = addAccessibilityHint
        self.onAdd = onAdd
    }

    var body: some View {
        Button(action: onAdd) {
            HStack(spacing: 10) {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 2) {
                        titleText
                            .lineLimit(2)
                        totalLabel
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    titleText
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    totalLabel
                }

                Image(systemName: "plus")
                    .font(.system(size: plusSize, weight: .bold))
                    .foregroundStyle(meal.ink)
                    .frame(width: addButtonSize, height: addButtonSize)
                    .background(meal.wash, in: Circle())
            }
            .textCase(nil)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(addAccessibilityLabel)
        .accessibilityHint(addAccessibilityHint)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier(addAccessibilityIdentifier)
    }

    private var titleText: some View {
        Text(title)
            .font(CalorynTheme.sectionHeaderTitle)
            .foregroundStyle(CalorynTheme.mealInk(meal))
    }

    @ViewBuilder
    private var totalLabel: some View {
        if let totalText {
            Text(totalText)
                .font(CalorynTheme.sectionHeaderDetail)
                .foregroundStyle(CalorynTheme.textSecondary)
                .lineLimit(1)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ForEach(MealType.allCases) { meal in
            CalorynMealSectionHeader(
                meal: meal,
                totalText: meal == .dinner ? "nothing yet" : "382 kcal",
                addAccessibilityIdentifier: "today.mealHeader.\(meal.rawValue)",
                addAccessibilityLabel: "Add food or meal to \(meal.displayName)",
                onAdd: {}
            )
        }
    }
    .padding()
    .background(CalorynTheme.backgroundPrimary)
}
