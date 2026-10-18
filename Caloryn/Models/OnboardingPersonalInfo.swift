import Foundation

enum OnboardingPersonalInfo {
    static let ageRange = 16...100
    static let heightRange: ClosedRange<Double> = 120...220
    static let heightStep: Double = 1
    static let weightRange: ClosedRange<Double> = 40...200

    static let weightStep: Double = 0.5

    static func ageLabel(_ age: Int) -> String {
        "\(age) years"
    }

    static func heightLabel(_ heightCm: Double) -> String {
        "\(heightCm.truncatedSafely) cm"
    }

    static func weightLabel(_ weightKg: Double, locale: Locale = .current) -> String {
        weightKg.kilogramsFormatted(locale: locale)
    }
}
