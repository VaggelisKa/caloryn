import Foundation

/// When the goal-type picker belongs under a nutrient goal field.
///
/// Choosing "minimum" or "maximum" is meaningless without a number, so the
/// picker only exists while the field holds one. Whitespace alone does not
/// count as a value.
enum NutrientGoalPickerVisibility {
    static func isVisible(targetText: String) -> Bool {
        !targetText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
