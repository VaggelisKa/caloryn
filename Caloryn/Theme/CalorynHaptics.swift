import UIKit

enum CalorynHaptics {
    static func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light, intensity: CGFloat = 1) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred(intensity: intensity)
    }

    static func selectionChanged() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func success() {
        notify(.success)
    }

    static func warning() {
        notify(.warning)
    }

    static func error() {
        notify(.error)
    }

    private static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
}
