import SwiftUI

// MARK: - Glass Container

struct AdaptiveGlassContainer<Content: View>: View {
    let spacing: CGFloat
    let content: Content

    init(spacing: CGFloat = 10, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content
            }
        } else {
            VStack(spacing: spacing) {
                content
            }
        }
    }
}

extension View {

    // MARK: - Card (rect glass)

    @ViewBuilder
    func adaptiveGlassCard(cornerRadius: CGFloat, tint: Color? = nil) -> some View {
        adaptiveGlassCard(
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
            tint: tint
        )
    }

    @ViewBuilder
    func adaptiveGlassCard<S: Shape>(in shape: S, tint: Color? = nil) -> some View {
        if #available(iOS 26.0, *) {
            if let tint {
                self
                    .glassEffect(.regular.tint(tint), in: shape)
            } else {
                self
                    .glassEffect(.regular, in: shape)
            }
        } else {
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
    }

    // MARK: - Circle glass

    @ViewBuilder
    func adaptiveGlassCircle() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: .circle)
        } else {
            self.background(.regularMaterial, in: Circle())
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

    // MARK: - Selected / interactive state glass

    @ViewBuilder
    func adaptiveSelectableGlass(
        isSelected: Bool,
        cornerRadius: CGFloat
    ) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(
                isSelected
                    ? .regular.tint(CalorynTheme.sage).interactive()
                    : .regular.interactive(),
                in: .rect(cornerRadius: cornerRadius)
            )
        } else {
            self
                .background(
                    selectableBackground(isSelected: isSelected),
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            selectableBorder(isSelected: isSelected),
                            lineWidth: isSelected ? 1.2 : 0.5
                        )
                        .allowsHitTesting(false)
                }
        }
    }

    // MARK: - Button style

    @ViewBuilder
    func adaptiveGlassProminentButton() -> some View {
        if #available(iOS 26.0, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }
    
    private func selectableBackground(isSelected: Bool) -> AnyShapeStyle {
        isSelected
            ? AnyShapeStyle(CalorynTheme.sage.opacity(0.20))
            : AnyShapeStyle(.regularMaterial)
    }

    private func selectableBorder(isSelected: Bool) -> Color {
        isSelected
            ? CalorynTheme.sage.opacity(0.72)
            : CalorynTheme.textSecondary.opacity(0.12)
    }
    
    @ViewBuilder
    func adaptiveCapsuleGlass() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: .capsule)
        } else {
            self
                .background(.regularMaterial)
                .clipShape(Capsule())
        }
    }
    
    @ViewBuilder
    func adaptiveGlassButtonStyle() -> some View {
        if #available(iOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }
}
