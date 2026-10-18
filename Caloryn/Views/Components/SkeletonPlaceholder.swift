import SwiftUI

/// One line of placeholder text: a bar the height of the glyphs, centred in the height
/// of the line it stands in for, so a placeholder row is exactly as tall as the row it
/// replaces.
///
/// `maxWidth` rather than `width`: the bar gives its width back under pressure,
/// which is what keeps a large Dynamic Type calorie block from being squeezed
/// out by a placeholder. Squared off with a small corner, like the badges, rather than
/// a capsule.
struct SkeletonBar: View {
    @Environment(\.skeletonDrawsOpaqueMask) private var drawsOpaqueMask

    let width: CGFloat
    let height: CGFloat
    var lineHeight: CGFloat? = nil

    var body: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            // Inside the shimmer's mask the bar must be opaque: a mask multiplies by
            // alpha, and the faint on-screen fill would reduce the highlight to under
            // one percent, which is invisible. The colour of a mask is never painted.
            .fill(drawsOpaqueMask ? Color.black : CalorynTheme.skeletonBase)
            .frame(maxWidth: width)
            .frame(height: height)
            .frame(height: max(lineHeight ?? height, height))
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
                            colors: [.clear, CalorynTheme.skeletonShine, .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: band)
                        .offset(x: -band + Self.sweep(at: timeline.date) * (width + 2 * band))
                    }
                }
                .mask(content.environment(\.skeletonDrawsOpaqueMask, true))
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

/// Set on the copy of the content that serves as the shimmer's mask, so the bars
/// draw fully opaque there and only their shape, not their faint fill, limits the band.
private struct SkeletonDrawsOpaqueMaskKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var skeletonDrawsOpaqueMask: Bool {
        get { self[SkeletonDrawsOpaqueMaskKey.self] }
        set { self[SkeletonDrawsOpaqueMaskKey.self] = newValue }
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
