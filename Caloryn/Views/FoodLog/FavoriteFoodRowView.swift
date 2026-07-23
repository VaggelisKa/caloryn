import SwiftUI

struct FavoriteFoodRowView: View {
    let food: FoodItem
    let plan: FavoriteFoodLogPlan
    let destinationDescription: String
    let onLog: () -> Void
    let onRemoveFavorite: () -> Void

    private var identityDescription: String {
        let type = food.isRecipe ? "Recipe" : (food.isCustom ? "Manual entry" : "Saved food")
        return food.brand
            .flatMap { $0.isEmpty ? nil : $0 }
            .map { "\($0) · \(type)" } ?? type
    }

    private var visualActionDescription: String? {
        switch plan.action {
        case .log(let portionGrams):
            portionGrams.portionFormatted
        case .confirmQuantity:
            nil
        case .unavailable:
            "Unavailable"
        }
    }

    private var accessibilityActionDescription: String {
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
            "This saved item must be edited or removed from Favorites"
        }
    }

    var body: some View {
        Button(action: onLog) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(food.name)
                        .font(CalorynTheme.itemTitle)
                        .foregroundStyle(CalorynTheme.textPrimary)
                        .lineLimit(1)

                    Text(identityDescription)
                        .font(CalorynTheme.microCaption)
                        .foregroundStyle(CalorynTheme.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if let visualActionDescription {
                    Text(visualActionDescription)
                        .font(CalorynTheme.numericMicroCaptionEmphasized)
                        .foregroundStyle(actionColor)
                        .multilineTextAlignment(.trailing)
                } else {
                    Image(systemName: "chevron.right")
                        .font(CalorynTheme.microCaption)
                        .foregroundStyle(CalorynTheme.textSecondary)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(food.name), \(identityDescription), \(accessibilityActionDescription), destination \(destinationDescription)"
        )
        .accessibilityHint(actionHint)
        .accessibilityAction(
            named: "Remove \(food.name) from favorites",
            onRemoveFavorite
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(action: onRemoveFavorite) {
                Label("Remove Favorite", systemImage: "star.slash")
            }
            .tint(CalorynTheme.terracotta)
        }
        .padding(.vertical, 3)
    }

    private var actionColor: Color {
        plan.action == .unavailable ? CalorynTheme.terracotta : CalorynTheme.sage
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
