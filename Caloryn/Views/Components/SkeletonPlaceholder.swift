import SwiftUI

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
            .fill(drawsOpaqueMask ? Color.black : CalorynTheme.fillLoading)
            .frame(maxWidth: width)
            .frame(height: height)
            .frame(height: max(lineHeight ?? height, height))
    }
}

struct ShimmeringPlaceholder<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    @ViewBuilder var content: Content

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
                            colors: [.clear, CalorynTheme.fillLoadingHighlight, .clear],
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

    static func sweep(at date: Date) -> Double {
        let elapsed = date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: cycle)
        return min(elapsed / (cycle * sweepFraction), 1)
    }
}

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
