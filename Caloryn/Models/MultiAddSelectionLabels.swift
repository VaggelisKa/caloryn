import Foundation

enum MultiAddSelectionLabels {
    static func reviewButtonTitle(selectedItemCount: Int) -> String {
        let noun = selectedItemCount == 1 ? "item" : "items"
        return "Review \(selectedItemCount) \(noun)"
    }

    static func selectionValue(
        isSelectingMultiple: Bool,
        isSelected: Bool
    ) -> String {
        guard isSelectingMultiple else { return "" }
        return isSelected ? "Selected" : "Not selected"
    }
}
