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
