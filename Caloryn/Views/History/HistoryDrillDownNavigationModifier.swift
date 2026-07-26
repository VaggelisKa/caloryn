import SwiftUI
import UIKit

private struct HistoryDrillDownNavigationModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .tint(CalorynTheme.sage)
            .background(HistoryNavigationBarTintView())
    }
}

private struct HistoryNavigationBarTintView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> HistoryNavigationBarTintViewController {
        HistoryNavigationBarTintViewController()
    }

    func updateUIViewController(
        _ viewController: HistoryNavigationBarTintViewController,
        context: Context
    ) {
        viewController.applyTint()
    }
}

private final class HistoryNavigationBarTintViewController: UIViewController {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyTint()
    }

    func applyTint() {
        navigationController?.navigationBar.tintColor = UIColor(CalorynTheme.sage)
    }
}

extension View {
    func historyDrillDownNavigation() -> some View {
        modifier(HistoryDrillDownNavigationModifier())
    }
}
