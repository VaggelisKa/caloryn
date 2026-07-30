import Foundation

/// The words the multi-add selection UI puts in front of the user.
///
/// Both are counting rules dressed as copy — one pluralises, the other decides
/// whether a row announces a selection state at all — and both are read aloud
/// by VoiceOver, which makes them behaviour rather than decoration.
enum MultiAddSelectionLabels {
    /// The title of the button that opens the review sheet.
    static func reviewButtonTitle(selectedItemCount: Int) -> String {
        let noun = selectedItemCount == 1 ? "Item" : "Items"
        return "Review \(selectedItemCount) \(noun)"
    }

    /// What a row announces as its accessibility value.
    ///
    /// Outside selection mode the rows have no checkboxes, so announcing "Not
    /// selected" on every one of them would be noise about a state the user
    /// cannot see or change.
    static func selectionValue(
        isSelectingMultiple: Bool,
        isSelected: Bool
    ) -> String {
        guard isSelectingMultiple else { return "" }
        return isSelected ? "Selected" : "Not selected"
    }
}
