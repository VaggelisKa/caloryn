import SwiftUI

struct PinnedFoodRowView: View {
    let food: FoodItem
    let plan: PinnedFoodLogPlan
    let destinationDescription: String
    let onLog: () -> Void
    let onUnpin: () -> Void

    private var identityDescription: String {
        let type = food.isRecipe ? "Recipe" : (food.isCustom ? "Manual entry" : "Saved food")
        return food.brand
            .flatMap { $0.isEmpty ? nil : $0 }
            .map { "\($0) · \(type)" } ?? type
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

                Text(actionDescription)
                    .font(CalorynTheme.numericMicroCaptionEmphasized)
                    .foregroundStyle(actionColor)
                    .multilineTextAlignment(.trailing)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(food.name), \(identityDescription), \(actionDescription), destination \(destinationDescription)")
        .accessibilityHint(actionHint)
        .accessibilityAction(named: "Unpin \(food.name)", onUnpin)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(action: onUnpin) {
                Label("Unpin", systemImage: "pin.slash")
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
