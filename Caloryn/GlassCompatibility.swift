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
    func adaptiveGlassCard(cornerRadius: CGFloat) -> some View {
        adaptiveGlassCard(in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    @ViewBuilder
    func adaptiveGlassCard<S: Shape>(in shape: S) -> some View {
        if #available(iOS 26.0, *) {
            self
                .glassEffect(.regular, in: shape)
        } else {
            solidCardSurface(in: shape)
        }
    }

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

    /// The app's prominent button: `.glassProminent` on iOS 26, `.borderedProminent` before
    /// it, with a paper label (`pageBackground`, or `textSecondary` while disabled).
    ///
    /// The label colour is the point. Both system styles fill with the tint — `AccentColor`,
    /// which is ink — and draw the label in their own white, which vanishes on the near-white
    /// ink of dark mode. Paper on ink reads in both appearances. A call site that tints the
    /// button some other colour must set its own label colour; `calorynPrimaryButton()` does.
    func adaptiveGlassProminentButton() -> some View {
        buttonStyle(CalorynProminentButtonStyle())
    }

    /// The bare system prominent style, label colour untouched — for a style that sets its
    /// own (`calorynPrimaryButton()`). Everything else wants `adaptiveGlassProminentButton()`.
    @ViewBuilder
    func systemProminentButtonStyle() -> some View {
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

/// Rebuilds the button so the colour is set on the label itself, inside the style, where the
/// system style cannot override it and every call site gets it — the string initialiser
/// (`Button("Retry")`) included, which has no label view of its own to colour. A view so it
/// can read `isEnabled`, because the system greys a disabled bezel and paper on that grey
/// disappears.
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
