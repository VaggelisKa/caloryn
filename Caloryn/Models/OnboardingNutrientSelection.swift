import Foundation

/// The nutrient multi-select on the last onboarding step.
///
/// The three core macros are always tracked and are shown as fixed cards rather
/// than toggles, so every rule here concerns the *extras* around them. The
/// stored value is always rebuilt as the core macros followed by the extras in
/// the order they were picked, which is why a toggle produces a whole new raw
/// string rather than editing one in place.
struct OnboardingNutrientSelection: Equatable {
    var rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// What the stored value means once the shared normalization has run: no
    /// duplicates, and never fewer than the minimum tracked count. That top-up
    /// stops at the minimum, so it is `normalizedRawValue` — not reading — that
    /// guarantees all three core macros.
    var selected: [TrackedNutrient] {
        TrackedNutrient.selected(from: rawValue)
    }

    /// The picked nutrients that are not core macros.
    var extras: [TrackedNutrient] {
        selected.filter { !TrackedNutrient.defaultSelection.contains($0) }
    }

    func isSelected(_ nutrient: TrackedNutrient) -> Bool {
        selected.contains(nutrient)
    }

    /// The stored value with the core macros put back in front of the extras.
    ///
    /// Written on appearance, so a selection saved when the macros were
    /// optional — or one a later screen trimmed — cannot leave onboarding with
    /// a macro switched off.
    var normalizedRawValue: String {
        rebuilt(extras: extras)
    }

    /// The stored value after adding or removing `nutrient` as an extra.
    ///
    /// Only the optional nutrients get a tile, so a core macro never reaches
    /// this; if one did it would be appended after the macros already in front
    /// and read back as the same selection, since reading de-duplicates.
    func toggling(_ nutrient: TrackedNutrient) -> String {
        var updated = extras
        if updated.contains(nutrient) {
            updated.removeAll { $0 == nutrient }
        } else {
            updated.append(nutrient)
        }
        return rebuilt(extras: updated)
    }

    private func rebuilt(extras: [TrackedNutrient]) -> String {
        TrackedNutrient.rawSelection(from: TrackedNutrient.defaultSelection + extras)
    }
}
