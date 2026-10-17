import Foundation

/// Where a stepped slider settles, for the sliders that move in steps without drawing them.
///
/// On iOS 26 `Slider(value:in:step:)` draws a tick for every step under the track: 100 of
/// them for height, 320 for weight, which reads as a dotted rule rather than a control. The
/// onboarding sliders take no `step:` and snap their value through this instead, so they
/// still land on exactly the values the stepped slider produced.
enum SliderStep {
    /// `value` moved to the nearest `lowerBound + n * step` inside `range`.
    ///
    /// Counted from the lower bound, as `Slider` counts its steps, and rounded to six
    /// places so a 5% macro step reads back as 0.35, not 0.35000000000000003. A value that
    /// is not finite settles on the lower bound rather than reaching a binding as NaN.
    static func snap(_ value: Double, in range: ClosedRange<Double>, step: Double) -> Double {
        guard value.isFinite else { return range.lowerBound }
        let clamped = min(max(value, range.lowerBound), range.upperBound)
        guard step.isFinite, step > 0 else { return clamped }

        let steps = ((clamped - range.lowerBound) / step).rounded()
        let snapped = ((range.lowerBound + steps * step) * 1_000_000).rounded() / 1_000_000
        return min(max(snapped, range.lowerBound), range.upperBound)
    }
}
