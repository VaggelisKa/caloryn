import SwiftUI

private struct PlateLargeTitleModifier: ViewModifier {
    let title: String

    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 30

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .navigationTitle(title)
                .toolbar {
                    ToolbarItem(placement: .largeTitle) {
                        Text(title)
                            .font(CalorynTypeface.fixed(size: size, weight: .heavy))
                            .tracking(-0.01 * size)
                            .foregroundStyle(CalorynTheme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityAddTraits(.isHeader)
                    }
                }
        } else {
            content
                .navigationTitle(title)
        }
    }
}

extension View {
    func calorynLargeTitle(_ title: String) -> some View {
        modifier(PlateLargeTitleModifier(title: title))
    }
}
