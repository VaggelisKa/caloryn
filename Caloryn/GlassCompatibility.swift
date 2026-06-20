//
//  GlassCompatibility.swift
//  Caloryn
//
//  Created by Konstantinos Stergiannis on 13/6/26.
//

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
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            self
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
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
            self.background(selectableBackground(isSelected: isSelected))
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
            ? AnyShapeStyle(CalorynTheme.sage.opacity(0.15))
            : AnyShapeStyle(.regularMaterial)
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
