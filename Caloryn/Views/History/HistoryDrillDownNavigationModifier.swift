import SwiftUI

private struct HistoryDrillDownNavigationModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
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
                    .tint(CalorynTheme.sage)
                    .accessibilityLabel("Back")
                }
            }
    }
}

extension View {
    func historyDrillDownNavigation() -> some View {
        modifier(HistoryDrillDownNavigationModifier())
    }
}
