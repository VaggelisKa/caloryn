import SwiftUI

struct CalorynCard<Content: View>: View {
    var cornerRadius: CGFloat = CalorynTheme.cornerRadius
    let content: Content

    init(cornerRadius: CGFloat = CalorynTheme.cornerRadius, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding(CalorynTheme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .adaptiveGlassCard(cornerRadius: cornerRadius)
    }
}

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = CalorynTheme.cornerRadius
    
    func body(content: Content) -> some View {
        CalorynCard(cornerRadius: cornerRadius) {
            content
        }
    }
}

struct GlassCircleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .adaptiveGlassCircle()
    }
}

struct CalorynInputFieldModifier: ViewModifier {
    var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.thinMaterial, in: .rect(cornerRadius: CalorynTheme.smallCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: CalorynTheme.smallCornerRadius, style: .continuous)
                    .stroke(
                        isFocused
                            ? CalorynTheme.sage.opacity(0.72)
                            : CalorynTheme.textSecondary.opacity(0.14),
                        lineWidth: isFocused ? 1.2 : 0.6
                    )
                    .allowsHitTesting(false)
            }
            .animation(.smooth(duration: 0.18), value: isFocused)
    }
}

struct DestructiveGlassButton: View {
    let title: LocalizedStringKey
    let systemImage: String
    let action: () -> Void

    init(_ title: LocalizedStringKey, systemImage: String = "trash", action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(role: .destructive, action: action) {
            Label(title, systemImage: systemImage)
                .font(CalorynTheme.buttonLabel)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .adaptiveGlassButtonStyle()
        .tint(CalorynTheme.terracotta)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = CalorynTheme.cornerRadius) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius))
    }

    func glassCircle() -> some View {
        modifier(GlassCircleModifier())
    }

    func calorynInputField(isFocused: Bool = false) -> some View {
        modifier(CalorynInputFieldModifier(isFocused: isFocused))
    }
}
