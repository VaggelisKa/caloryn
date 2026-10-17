import Foundation

extension String {
    /// "Saturated Fat" → "Saturated fat", "Moderately Active" → "Moderately active".
    ///
    /// The Plate copy is sentence case, while the model's display names are title case.
    /// Every screen that shows one converts at the call site (Settings and its edit screens
    /// included) rather than the names changing in the model. Only for those names: it
    /// lowercases everything after the first letter, so an acronym would not survive.
    var sentenceCased: String {
        guard let first else { return self }
        return String(first).uppercased() + dropFirst().lowercased()
    }
}
