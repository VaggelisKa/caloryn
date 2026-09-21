import SwiftUI

/// `maxWidth` rather than `width`: the bar gives its width back under pressure,
/// which is what keeps a large Dynamic Type calorie block from being squeezed
/// out by a placeholder.
struct SkeletonBar: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        Capsule(style: .continuous)
            .fill(CalorynTheme.skeletonBase)
            .frame(maxWidth: width)
            .frame(height: height)
    }
}

/// Sweeps a highlight across its content, masked to the content's own shape so
/// only the placeholder bars light up and the gaps between them stay empty.
///
/// `TimelineView(.animation)` rather than a `repeatForever` animation: an
/// animation that never ends is the classic way to hang XCUITest, which waits
/// for the app to stop animating before it will interact with it, and this
/// sheet is on the path of most of the E2E journeys.
///
/// Wrap a whole group of rows in one of these, not each row — a band per row
/// reads as a stack of unrelated spinners.
struct ShimmeringPlaceholder<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    @ViewBuilder var content: Content

    /// The band crosses in the first `sweepFraction` of the cycle and the rest
    /// is rest — a continuous sweep with no gap reads as frantic.
    private static var cycle: TimeInterval { 1.75 }
    private static var sweepFraction: Double { 0.68 }

    var body: some View {
        if accessibilityReduceMotion {
            content
        } else {
            content.overlay {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    GeometryReader { proxy in
                        let width = proxy.size.width
                        let band = max(width * 0.42, 1)
                        LinearGradient(
                            colors: [.clear, CalorynTheme.skeletonHighlight, .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: band)
                        .offset(x: -band + Self.sweep(at: timeline.date) * (width + 2 * band))
                    }
                }
                .mask(content)
                .allowsHitTesting(false)
            }
        }
    }

    /// How far across the band is: 0 at its entry edge, 1 once it has left.
    ///
    /// Anchored to absolute time rather than to an `onAppear`, so rows that
    /// appear late join the sweep already in progress instead of starting their
    /// own.
    static func sweep(at date: Date) -> Double {
        let elapsed = date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: cycle)
        return min(elapsed / (cycle * sweepFraction), 1)
    }
}

#Preview {
    ShimmeringPlaceholder {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(0..<5, id: \.self) { _ in
                SkeletonBar(width: 200, height: 14)
                SkeletonBar(width: 120, height: 10)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CalorynTheme.pagePadding)
    }
    .calorynSheetCanvas()
}
