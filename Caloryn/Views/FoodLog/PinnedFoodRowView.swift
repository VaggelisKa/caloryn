import SwiftUI

struct PinnedFoodRowView: View {
    let food: FoodItem
    let plan: PinnedFoodLogPlan
    let destinationDescription: String
    let onLog: () -> Void
    let onUnpin: () -> Void

    private var identityDescription: String {
        let type = food.isRecipe ? "Recipe" : (food.isCustom ? "Manual entry" : "Saved food")
        let prefix = food.brand.flatMap { $0.isEmpty ? nil : $0 }.map { "\($0) · \(type)" } ?? type
        return "\(prefix) · \(Int(food.caloriesPer100g.rounded())) kcal/100g"
    }

    private var actionDescription: String {
        switch plan.action {
        case .log(let portionGrams):
            "Log \(portionGrams.portionFormatted)"
        case .confirmQuantity:
            "Choose portion"
        case .unavailable:
            "Unavailable"
        }
    }

    private var actionHint: String {
        switch plan.action {
        case .log:
            "Logs this portion to \(destinationDescription)"
        case .confirmQuantity:
            "Opens a quantity confirmation for \(destinationDescription)"
        case .unavailable:
            "This saved item must be edited or unpinned"
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onLog) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(food.name)
                            .font(CalorynTheme.itemTitle)
                            .foregroundStyle(CalorynTheme.textPrimary)
                            .lineLimit(1)

                        Text(identityDescription)
                            .font(CalorynTheme.microCaption)
                            .foregroundStyle(CalorynTheme.textSecondary)
                            .lineLimit(1)

                        Label(destinationDescription, systemImage: "calendar")
                            .font(CalorynTheme.caption)
                            .foregroundStyle(CalorynTheme.textSecondary)
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 4) {
                        Image(systemName: actionIcon)
                            .font(CalorynTheme.inlineIcon)
                            .foregroundStyle(actionColor)

                        Text(actionDescription)
                            .font(CalorynTheme.numericMicroCaptionEmphasized)
                            .foregroundStyle(actionColor)
                            .multilineTextAlignment(.trailing)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(food.name), \(identityDescription), \(actionDescription), destination \(destinationDescription)")
            .accessibilityHint(actionHint)

            Button(action: onUnpin) {
                Image(systemName: "star.fill")
                    .font(CalorynTheme.inlineIcon)
                    .foregroundStyle(CalorynTheme.terracotta)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Unpin \(food.name)")
            .accessibilityHint("Removes this item from favorites")
        }
        .padding(.vertical, 4)
    }

    private var actionIcon: String {
        switch plan.action {
        case .log: "plus.circle.fill"
        case .confirmQuantity: "slider.horizontal.3"
        case .unavailable: "exclamationmark.triangle.fill"
        }
    }

    private var actionColor: Color {
        switch plan.action {
        case .unavailable: CalorynTheme.terracotta
        case .log, .confirmQuantity: CalorynTheme.sage
        }
    }
}

struct PinnedFoodsEmptyRow: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "star")
                .font(CalorynTheme.inlineIcon)
                .foregroundStyle(CalorynTheme.textSecondary)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text("No Pinned Foods")
                    .font(CalorynTheme.itemTitle)
                    .foregroundStyle(CalorynTheme.textPrimary)
                Text("Tap a star beside a saved food or recipe to keep it here.")
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

struct SearchEmptyRow: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(CalorynTheme.inlineIcon)
                .foregroundStyle(CalorynTheme.textSecondary)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(CalorynTheme.itemTitle)
                    .foregroundStyle(CalorynTheme.textPrimary)
                Text(message)
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

private extension Double {
    var portionFormatted: String {
        if rounded() == self {
            return "\(Int(self))g"
        }
        return "\(formatted(.number.precision(.fractionLength(0...1))))g"
    }
}
