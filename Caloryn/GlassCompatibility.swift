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
