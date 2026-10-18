import Foundation

enum NutrientGoalPickerVisibility {
    static func isVisible(targetText: String) -> Bool {
        !targetText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
