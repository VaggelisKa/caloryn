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

private struct CalorynSheetCanvasModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            sheetCanvas(content)
        } else {
            sheetCanvas(content)
                .toolbarBackground(CalorynTheme.cardBackground, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private func sheetCanvas(_ content: Content) -> some View {
        content.background {
            CalorynTheme.cardBackground
                .ignoresSafeArea()
        }
    }
}

private struct CalorynPlainListStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        // Deliberately paints no background of its own: the surrounding canvas supplies
        // the colour, so the same list reads correctly on a page (#F3F1EC) and in a sheet
        // (#FAFAF7). Rows still need `.listRowBackground(Color.clear)` — hiding the scroll
        // background does not stop a row drawing its own.
    }
}

extension View {
    /// Canvas for a tab page: the warm page background.
    func calorynPageCanvas() -> some View {
        modifier(CalorynPageCanvasModifier())
    }

    /// Canvas for a modal sheet: the lighter card surface, so a sheet reads as floating
    /// above the page rather than continuing it. Pages stay `pageBackground`.
    func calorynSheetCanvas() -> some View {
        modifier(CalorynSheetCanvasModifier())
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
