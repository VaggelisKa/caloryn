import SwiftUI

extension View {
    func solidCardSurface(cornerRadius: CGFloat) -> some View {
        solidCardSurface(in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    func solidCardSurface<S: Shape>(in shape: S) -> some View {
        self
            .background {
                shape
                    .fill(CalorynTheme.cardBackground)
                    .shadow(color: .black.opacity(0.05), radius: 14, x: 0, y: 6)
            }
            .overlay {
                shape
                    .stroke(CalorynTheme.cardSeparator.opacity(0.75), lineWidth: 0.8)
                    .allowsHitTesting(false)
            }
    }

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
                .foregroundStyle(isEnabled ? CalorynTheme.pageBackground : CalorynTheme.textSecondary)
        }
        .systemProminentButtonStyle()
    }
}
