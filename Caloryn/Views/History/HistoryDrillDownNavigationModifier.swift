import SwiftUI

private struct HistoryDrillDownNavigationModifier: ViewModifier {
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

extension View {
    /// Navigation chrome for the two History drill-downs.
    ///
    /// The back button is replaced rather than tinted. A *system* back button under Liquid
    /// Glass honours neither the AccentColor asset, nor `.tint()`, nor a UIKit
    /// `navigationBar.tintColor` bridge — this file used to carry all three and the chevron
    /// still measured near-black in a screenshot. Only `.foregroundStyle` on a label the app
    /// owns works, which is the same pattern `PortionPickerView` and `MyFoodsView` already use.
    func historyDrillDownNavigation() -> some View {
        modifier(HistoryDrillDownNavigationModifier())
    }
}
