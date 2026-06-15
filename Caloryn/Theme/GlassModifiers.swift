import SwiftUI

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = CalorynTheme.cornerRadius
    
    func body(content: Content) -> some View {
        content
            .padding(CalorynTheme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .adaptiveGlassCard(cornerRadius: cornerRadius)
    }
}

struct GlassCircleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .adaptiveGlassCircle()
    }
}


extension View {
    func glassCard(cornerRadius: CGFloat = CalorynTheme.cornerRadius) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius))
    }

    func glassCircle() -> some View {
        modifier(GlassCircleModifier())
    }
}
