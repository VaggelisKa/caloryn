import UIKit

/// Restores the interactive swipe-from-edge pop gesture on screens that hide the
/// system back button.
///
/// `calorynDrillDownNavigation()` calls `navigationBarBackButtonHidden()` because the
/// system chevron cannot be tinted under Liquid Glass — see `CalorynViewModifiers`.
/// The cost is invisible in review: `UINavigationController` owns
/// `interactivePopGestureRecognizer`, whose default delegate refuses to begin whenever
/// the back button is hidden. It cannot assume a custom leading item means "pop", so
/// hiding the button silently takes the swipe with it. SwiftUI exposes no way to say
/// "I hid the button but kept the meaning".
///
/// So the app takes the delegate. `gestureRecognizerShouldBegin` re-states the one
/// condition the default delegate got right — there must be something to pop back to —
/// and drops the back-button check.
///
/// **Pushes inside a sheet are deliberately left without the gesture.** Swiping one back
/// on a device drags a slab of the presenting screen's keyboard in from the left; the
/// food-search sheet focuses its field on appear, so its push always carries one. The
/// tinted back button still pops those screens. Tab pushes have no such artifact and
/// keep the gesture.
///
/// `shouldRecognizeSimultaneouslyWith` returns `false`: letting the pop gesture run
/// alongside a scroll view's pan is what makes a horizontally-scrolling detail screen
/// pop mid-swipe.
extension UINavigationController: UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === interactivePopGestureRecognizer else { return true }
        guard viewControllers.count > 1 else { return false }

        // `presentingViewController` is non-nil for a controller whose nearest presented
        // ancestor was presented modally, which is exactly "this stack lives in a sheet".
        // A stack inside a tab reports nil.
        return presentingViewController == nil
    }

    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        false
    }
}
