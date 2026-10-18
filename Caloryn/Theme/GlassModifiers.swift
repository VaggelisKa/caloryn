import SwiftUI

struct SolidCardModifier: ViewModifier {
    var cornerRadius: CGFloat = CalorynTheme.cornerRadius

    func body(content: Content) -> some View {
        content
            .padding(CalorynTheme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .solidCardSurface(cornerRadius: cornerRadius)
    }
}

struct CalorynInputFieldModifier: ViewModifier {
    var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                CalorynTheme.surface,
                in: RoundedRectangle(cornerRadius: CalorynTheme.smallCornerRadius, style: .continuous)
            )
            .overlay {
                // A well, not a card: `surface` with a hairline edge, and ink when focused.
                RoundedRectangle(cornerRadius: CalorynTheme.smallCornerRadius, style: .continuous)
                    .strokeBorder(
                        isFocused ? CalorynTheme.textPrimary : CalorynTheme.hairline,
                        lineWidth: isFocused ? 1.2 : CalorynTheme.hairlineWidth
                    )
                    .allowsHitTesting(false)
            }
            .animation(.smooth(duration: 0.18), value: isFocused)
    }
}

extension View {
    func solidCard(cornerRadius: CGFloat = CalorynTheme.cornerRadius) -> some View {
        modifier(SolidCardModifier(cornerRadius: cornerRadius))
    }

    func calorynInputField(isFocused: Bool = false) -> some View {
        modifier(CalorynInputFieldModifier(isFocused: isFocused))
    }
}
