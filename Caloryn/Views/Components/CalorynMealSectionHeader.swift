import SwiftUI

/// A meal's section header on the Plate / Market palette: the meal's name in its ink, the
/// meal's total in secondary text ("382 kcal", "nothing yet"), and a round add button: the
/// meal's fill as a light wash with the plus in the meal's ink, the same for every meal.
///
/// The whole row is the add button, as the header on Today has always been, so the
/// accessibility identifier, label and hint land on an element that still does the same
/// thing (`today.mealHeader.<raw>` keeps working). Callers own those strings. It is a
/// heading as well as a button, so the VoiceOver rotor can jump from meal to meal.
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

    /// - Parameters:
    ///   - title: defaults to the meal's display name; pass the snack slot's name for a snack.
    ///   - totalText: "382 kcal", "nothing yet", or nil for no trailing text. Both read in
    ///     secondary text: "nothing yet" is words, not a figure, so it cannot be mistaken for
    ///     a total, and in tertiary it fell to 2.8:1 on the page.
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

    /// Name, total and plus on one line as the board draws them. At accessibility sizes the
    /// three overflow the row (from AX2 a total could read "1.3…"), so the total moves under
    /// the name and the plus stays on the trailing edge; a number is never truncated.
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
                    // Over the header's opaque page fill, so the wash is the same colour
                    // whether the header is pinned or scrolling with its meal.
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
