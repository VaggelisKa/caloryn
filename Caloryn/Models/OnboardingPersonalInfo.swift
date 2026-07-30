import Foundation

/// The bounds and readouts of the About You step.
///
/// Every field on that step is a stepper or a slider, so its bounds *are* its
/// validation — there is no invalid state to reject, only a range that cannot
/// be left. Naming the ranges here keeps them checkable, and keeps the same
/// numbers from drifting apart between the control and anything that reasons
/// about them.
enum OnboardingPersonalInfo {
    static let ageRange = 16...100
    static let heightRange: ClosedRange<Double> = 120...220
    static let heightStep: Double = 1
    static let weightRange: ClosedRange<Double> = 40...200

    /// Half a kilogram, because the daily target moves by roughly ten calories
    /// over that — a finer step would be noise.
    static let weightStep: Double = 0.5

    static func ageLabel(_ age: Int) -> String {
        "\(age) years"
    }

    /// Truncates rather than rounds, matching the whole-number readouts
    /// elsewhere in the app. The slider steps by 1 within a finite range, so
    /// there is no fractional or non-finite value to reach the conversion.
    static func heightLabel(_ heightCm: Double) -> String {
        "\(heightCm.truncatedSafely) cm"
    }

    /// Kept to one decimal because the slider steps by half a kilogram.
    static func weightLabel(_ weightKg: Double) -> String {
        String(format: "%.1f kg", weightKg)
    }
}
