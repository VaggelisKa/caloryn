import Foundation

enum SliderStep {
    static func snap(_ value: Double, in range: ClosedRange<Double>, step: Double) -> Double {
        guard value.isFinite else { return range.lowerBound }
        let clamped = min(max(value, range.lowerBound), range.upperBound)
        guard step.isFinite, step > 0 else { return clamped }

        let steps = ((clamped - range.lowerBound) / step).rounded()
        let snapped = ((range.lowerBound + steps * step) * 1_000_000).rounded() / 1_000_000
        return min(max(snapped, range.lowerBound), range.upperBound)
    }
}
