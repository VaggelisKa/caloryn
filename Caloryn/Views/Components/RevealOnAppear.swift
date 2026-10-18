import SwiftUI

extension View {
    /// Flips `isRevealed` to true just after the view's first frame, inside `animation`, so
    /// a chart or figure can draw its empty state first and grow into its data. Under Reduce
    /// Motion it flips before the first frame, without animation.
    ///
    /// The flag stays true once set: the entrance happens once per view identity, so a tab
    /// switch does not replay it, but a view rebuilt with a new `.id` does.
    func revealOnAppear(
        _ isRevealed: Binding<Bool>,
        animation: Animation = .calorynReveal
    ) -> some View {
        modifier(RevealOnAppear(isRevealed: isRevealed, animation: animation))
    }
}

extension Animation {
    /// The entrance every chart and hero figure shares: the donut's 0.55s smooth curve.
    static let calorynReveal: Animation = .smooth(duration: 0.55)
}

private struct RevealOnAppear: ViewModifier {
    @Binding var isRevealed: Bool
    let animation: Animation

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .onAppear {
                // Before the first frame, so a Reduce Motion reader never sees the empty state.
                if reduceMotion {
                    isRevealed = true
                }
            }
            .task {
                guard !isRevealed else { return }
                // A real frame on the empty state first. A bare `Task.yield()` can resume
                // before the view's first render, and a figure with nothing on screen to
                // roll from just appears at its final value.
                try? await Task.sleep(for: .milliseconds(50))
                guard !Task.isCancelled else { return }
                withAnimation(animation) {
                    isRevealed = true
                }
            }
    }
}
