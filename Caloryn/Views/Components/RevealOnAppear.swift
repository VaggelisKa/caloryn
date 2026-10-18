import SwiftUI

extension View {
    func revealOnAppear(
        _ isRevealed: Binding<Bool>,
        animation: Animation = .calorynReveal
    ) -> some View {
        modifier(RevealOnAppear(isRevealed: isRevealed, animation: animation))
    }
}

extension Animation {
    static let calorynReveal: Animation = .smooth(duration: 0.55)
}

private struct RevealOnAppear: ViewModifier {
    @Binding var isRevealed: Bool
    let animation: Animation

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .onAppear {
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
