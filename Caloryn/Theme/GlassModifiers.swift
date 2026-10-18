import SwiftUI

struct CalorynInputFieldModifier: ViewModifier {
    var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                CalorynTheme.backgroundTertiary,
                in: RoundedRectangle(cornerRadius: CalorynTheme.smallCornerRadius, style: .continuous)
            )
            .overlay {
                // A well, not a card: `backgroundTertiary` with a `separator` edge, and `accent` when focused.
                RoundedRectangle(cornerRadius: CalorynTheme.smallCornerRadius, style: .continuous)
                    .strokeBorder(
                        isFocused ? CalorynTheme.accent : CalorynTheme.separator,
                        lineWidth: isFocused ? 1.2 : CalorynTheme.hairlineWidth
                    )
                    .allowsHitTesting(false)
            }
            .animation(.smooth(duration: 0.18), value: isFocused)
    }
}

extension View {
    func calorynInputField(isFocused: Bool = false) -> some View {
        modifier(CalorynInputFieldModifier(isFocused: isFocused))
    }
}
