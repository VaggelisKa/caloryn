import SwiftUI

extension View {
    @ViewBuilder
    func adaptiveCircleInteractiveGlass() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: .circle)
        } else {
            self.background(.regularMaterial, in: Circle())
        }
    }

    /// Interactive circle glass with a body: tinted with a theme token, with an optional
    /// hairline edge. Clear glass over a surface of nearly its own colour shows only a rim:
    /// Today's day buttons all but vanished on the dark page, and Add Food's scanner on the
    /// white sheet. Before iOS 26 there is no glass to tint, so the token is the fill rather
    /// than a system material.
    @ViewBuilder
    func adaptiveCircleInteractiveGlass(tint: Color, edge: Color? = nil) -> some View {
        if #available(iOS 26.0, *) {
            self
                .glassEffect(.regular.tint(tint).interactive(), in: .circle)
                .overlay {
                    if let edge {
                        Circle().strokeBorder(edge, lineWidth: 1).allowsHitTesting(false)
                    }
                }
        } else {
            self
                .background(tint, in: Circle())
                .overlay {
                    if let edge {
                        Circle().strokeBorder(edge, lineWidth: 1).allowsHitTesting(false)
                    }
                }
        }
    }

    @ViewBuilder
    func adaptiveUnitedInteractiveGlass(tint: Color, id: String, in namespace: Namespace.ID) -> some View {
        if #available(iOS 26.0, *) {
            self
                .glassEffect(.regular.tint(tint).interactive(), in: .capsule)
                .glassEffectUnion(id: id, namespace: namespace)
        } else {
            self.background(tint, in: Circle())
        }
    }

    func adaptiveGlassProminentButton() -> some View {
        buttonStyle(CalorynProminentButtonStyle())
    }

    @ViewBuilder
    func systemProminentButtonStyle() -> some View {
        if #available(iOS 26.0, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }
}

struct AdaptiveGlassGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer {
                content
            }
        } else {
            content
        }
    }
}

private struct CalorynProminentButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        CalorynProminentButton(configuration: configuration)
    }
}

private struct CalorynProminentButton: View {
    let configuration: PrimitiveButtonStyleConfiguration

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(role: configuration.role, action: configuration.trigger) {
            configuration.label
                .foregroundStyle(isEnabled ? CalorynTheme.textOnAccent : CalorynTheme.textSecondary)
        }
        .systemProminentButtonStyle()
    }
}
