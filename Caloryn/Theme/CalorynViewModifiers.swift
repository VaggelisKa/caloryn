import SwiftUI

private struct CalorynPageCanvasModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            pageCanvas(content)
        } else {
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
    }
}

private struct CalorynDrillDownNavigationModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            .tint(CalorynTheme.accent)
            .navigationBarBackButtonHidden()
            .toolbar {
                // `cancellationAction` is the placement Apple names for a custom Back: it
                // leads the bar on every axis, so iPhone Duo's vertical bar keeps it at the
                // top. The `Label` draws as the symbol alone; its title is what the vertical
                // bar's overflow menu and VoiceOver read — a bare `Image` has none.
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Back", systemImage: "chevron.left")
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
    }
}

extension ToolbarItemPlacement {
    /// Where a sheet's or edit screen's Save goes. Pinned trailing on iOS 27, which Apple
    /// names for a Done or Save: the item never moves into the overflow menu when iPhone
    /// Duo's vertical bar runs out of room. The ordinary confirmation slot before that, and
    /// also when built with an SDK older than iOS 27: CI's Xcode 26.6 is Swift 6.3, so the
    /// guard is the Xcode 27.1 compiler, the only iOS 27 toolchain in use.
    static var calorynConfirmation: ToolbarItemPlacement {
        #if compiler(>=6.4)
        if #available(iOS 27.0, *) {
            return .topBarPinnedTrailing
        }
        #endif
        return .confirmationAction
    }
}

extension View {
    func calorynPageCanvas() -> some View {
        modifier(CalorynPageCanvasModifier())
    }

    func calorynSheetCanvas() -> some View {
        modifier(CalorynSheetCanvasModifier())
    }

    func calorynGroupedListStyle() -> some View {
        modifier(CalorynGroupedListStyleModifier())
    }

    func calorynFormStyle() -> some View {
        modifier(CalorynFormStyleModifier())
    }

    func calorynDrillDownNavigation() -> some View {
        modifier(CalorynDrillDownNavigationModifier())
    }

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

    func calorynPlainListStyle() -> some View {
        modifier(CalorynPlainListStyleModifier())
    }
}
