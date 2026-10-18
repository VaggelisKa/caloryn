import SwiftUI

private struct CalorynPageCanvasModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            pageCanvas(content)
        } else {
            // Before Liquid Glass a bar that is "visible" paints its background and its
            // hairline even at rest, so every page had a system line across the top (and
            // Today, which has no title, an empty bar with one). Setting only the colour
            // keeps the bar transparent at rest and paints the page colour, not the
            // system material, once content scrolls under it.
            pageCanvas(content)
                .toolbarBackground(CalorynTheme.backgroundPrimary, for: .navigationBar)
        }
    }

    private func pageCanvas(_ content: Content) -> some View {
        content.background {
            CalorynTheme.backgroundPrimary
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
                CalorynTheme.backgroundPrimary
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
            // Colour only, as the page canvas does: forcing the bar visible drew a
            // hairline under every sheet title at rest, which the glass bar never has.
            sheetCanvas(content)
                .toolbarBackground(CalorynTheme.backgroundSecondary, for: .navigationBar)
        }
    }

    private func sheetCanvas(_ content: Content) -> some View {
        content.background {
            CalorynTheme.backgroundSecondary
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
        // `.listRowBackground(CalorynTheme.backgroundSecondary)`; this only clears the scroll
        // background so the canvas shows through.
    }
}

private struct CalorynDrillDownNavigationModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            .tint(CalorynTheme.accent)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(CalorynTheme.toolbarIcon)
                            .foregroundStyle(CalorynTheme.accent)
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
        // the colour, so the same list reads correctly on a page (#F6F5F1) and in a sheet
        // (#FFFFFF). Rows still need `.listRowBackground(Color.clear)` — hiding the scroll
        // background does not stop a row drawing its own.
    }
}

extension View {
    /// Canvas for a tab page: the warm page background.
    func calorynPageCanvas() -> some View {
        modifier(CalorynPageCanvasModifier())
    }

    /// Canvas for a modal sheet: the lighter card surface, so a sheet reads as floating
    /// above the page rather than continuing it. Pages stay `backgroundPrimary`.
    func calorynSheetCanvas() -> some View {
        modifier(CalorynSheetCanvasModifier())
    }

    /// Inset-grouped list on the page canvas — the card-like look.
    func calorynGroupedListStyle() -> some View {
        modifier(CalorynGroupedListStyleModifier())
    }

    /// `Form` on whichever canvas surrounds it. Sections still need
    /// `.listRowBackground(CalorynTheme.backgroundSecondary)`.
    func calorynFormStyle() -> some View {
        modifier(CalorynFormStyleModifier())
    }

    /// Navigation chrome for a pushed detail screen: a themed back button.
    ///
    /// The system back button is replaced rather than tinted, because under Liquid Glass it
    /// honours neither the global accent, nor `.tint()`, nor a UIKit
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

    /// An inline navigation title in the app's typeface: 17pt bold ink, as the Add Food sheets
    /// draw theirs. Use in place of `.navigationTitle(_:)` with `.inline` display mode.
    ///
    /// UIKit draws a bare `.navigationTitle` in the system font, so the words go in the
    /// principal slot instead. The navigation title stays set for VoiceOver's screen name and
    /// the back-button menu.
    func calorynInlineTitle(_ title: String) -> some View {
        navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(CalorynTheme.sectionHeaderTitle)
                        .foregroundStyle(CalorynTheme.textPrimary)
                        .lineLimit(1)
                        .accessibilityAddTraits(.isHeader)
                }
            }
    }

    /// Flat list on the page canvas, for content that should not read as cards
    /// (search results, pickers).
    ///
    /// `scrollContentBackground(.hidden)` is the load-bearing part of all three of
    /// these: a `List` paints its own system background *over* anything behind it,
    /// so setting `.background` alone silently does nothing. That is why bare
    /// `.listStyle(...)` is banned — see CLAUDE.md rule 6.
    func calorynPlainListStyle() -> some View {
        modifier(CalorynPlainListStyleModifier())
    }
}
