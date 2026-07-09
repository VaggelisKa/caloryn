import SwiftUI

private struct CalorynPageCanvasModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            pageCanvas(content)
        } else {
            pageCanvas(content)
                .toolbarBackground(CalorynTheme.pageBackground, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private func pageCanvas(_ content: Content) -> some View {
        content.background {
            CalorynTheme.pageBackground
                .ignoresSafeArea()
        }
    }
}

private struct CalorynGroupedListStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listStyle(.insetGrouped)
            .listSectionSpacing(.custom(CalorynTheme.cardSpacing))
            .scrollContentBackground(.hidden)
            .background {
                CalorynTheme.pageBackground
                    .ignoresSafeArea()
            }
    }
}

extension View {
    func calorynPageCanvas() -> some View {
        modifier(CalorynPageCanvasModifier())
    }

    func calorynGroupedListStyle() -> some View {
        modifier(CalorynGroupedListStyleModifier())
    }
}
