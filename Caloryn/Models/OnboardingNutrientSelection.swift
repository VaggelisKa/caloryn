import Foundation

struct OnboardingNutrientSelection: Equatable {
    var rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    var selected: [TrackedNutrient] {
        TrackedNutrient.selected(from: rawValue)
    }

    var extras: [TrackedNutrient] {
        selected.filter { !TrackedNutrient.defaultSelection.contains($0) }
    }

    func isSelected(_ nutrient: TrackedNutrient) -> Bool {
        selected.contains(nutrient)
    }

    var normalizedRawValue: String {
        rebuilt(extras: extras)
    }

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
