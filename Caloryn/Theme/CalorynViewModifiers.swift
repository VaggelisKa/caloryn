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

private struct CalorynFormStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
        // A `Form` paints `systemGroupedBackground` over its canvas exactly as a `List`
        // does — cool grey-blue, not the warm palette. Sections still need
        // `.listRowBackground(CalorynTheme.cardBackground)`; this only clears the scroll
        // background so the canvas shows through.
    }
}

private struct CalorynDrillDownNavigationModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            .tint(CalorynTheme.sage)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(CalorynTheme.toolbarIcon)
                            .foregroundStyle(CalorynTheme.sage)
                    }
                    .accessibilityLabel("Back")
                }
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

    /// `Form` on whichever canvas surrounds it. Sections still need
    /// `.listRowBackground(CalorynTheme.cardBackground)`.
    func calorynFormStyle() -> some View {
        modifier(CalorynFormStyleModifier())
    }

    /// Navigation chrome for a pushed detail screen: a themed back button.
    ///
    /// The system back button is replaced rather than tinted, because under Liquid Glass it
    /// honours neither the `AccentColor` asset, nor `.tint()`, nor a UIKit
    /// `navigationBar.tintColor` bridge. History carried all three at once and its chevron
    /// still measured near-black in a screenshot. Only `.foregroundStyle` on a label the app
    /// owns works.
    ///
    /// Apply to anything reached by `NavigationLink` or `navigationDestination`. Screens that
    /// already build their own leading toolbar item — `PortionPickerView`, `MyFoodsView` —
    /// do not need it and must not have two.
    func calorynDrillDownNavigation() -> some View {
        modifier(CalorynDrillDownNavigationModifier())
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
