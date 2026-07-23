import SwiftUI

struct MealTemplateLibraryRow: View {
    let template: MealTemplate

    private var snapshots: [FoodLogEntrySnapshot] {
        (try? MealTemplateCommands.snapshots(for: template)) ?? []
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "fork.knife")
                .font(CalorynTheme.inlineIcon)
                .foregroundStyle(CalorynTheme.sage)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(template.name)
                    .font(CalorynTheme.itemTitle)
                    .foregroundStyle(CalorynTheme.textPrimary)

                Text(detailText)
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(CalorynTheme.numericMicroCaption)
                .foregroundStyle(CalorynTheme.textSecondary)
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(template.name), \(detailText)")
        .accessibilityHint("Double tap to open this meal")
    }

    private var detailText: String {
        guard !snapshots.isEmpty else { return "Unavailable meal" }
        let itemLabel = snapshots.count == 1 ? "1 item" : "\(snapshots.count) items"
        let calories = snapshots.reduce(0) { $0 + $1.nutrition.calories }
        return "\(itemLabel) · \(calories.kcalFormatted)"
    }
}
