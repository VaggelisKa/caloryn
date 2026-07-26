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

private struct CalorynPlainListStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listStyle(.plain)
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

    /// Inset-grouped list on the page canvas — the card-like look.
    func calorynGroupedListStyle() -> some View {
        modifier(CalorynGroupedListStyleModifier())
    }

    /// Flat list on the page canvas, for content that should not read as cards
    /// (search results, pickers).
    ///
    /// `scrollContentBackground(.hidden)` is the load-bearing part of all three of
    /// these: a `List` paints its own system background *over* anything behind it,
    /// so setting `.background` alone silently does nothing. That is why bare
    /// `.listStyle(...)` is banned — see CLAUDE.md rule 7.
    func calorynPlainListStyle() -> some View {
        modifier(CalorynPlainListStyleModifier())
    }
}
