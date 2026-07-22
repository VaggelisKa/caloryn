import Foundation

struct ProduceVarietyItem: Identifiable, Hashable {
    let id: String
    let name: String
    let kind: ProduceKind
}

struct ProduceVarietySummary {
    let items: [ProduceVarietyItem]

    var totalCount: Int {
        items.count
    }

    var fruitCount: Int {
        items.filter { $0.kind == .fruit }.count
    }

    var vegetableCount: Int {
        items.filter { $0.kind == .vegetable }.count
    }

    var breakdownText: String {
        guard totalCount > 0 else { return "No fruit or veg logged" }

        let fruitLabel = fruitCount == 1 ? "fruit" : "fruits"
        let vegetableLabel = vegetableCount == 1 ? "vegetable" : "veg"

        switch (fruitCount, vegetableCount) {
        case (0, let vegetables):
            return "\(vegetables) \(vegetableLabel)"
        case (let fruits, 0):
            return "\(fruits) \(fruitLabel)"
        default:
            return "\(fruitCount) \(fruitLabel), \(vegetableCount) \(vegetableLabel)"
        }
    }

    var previewText: String? {
        guard !items.isEmpty else { return nil }

        let previewNames = items.prefix(3).map(\.name).joined(separator: ", ")
        let remainingCount = items.count - 3

        guard remainingCount > 0 else { return previewNames }
        return "\(previewNames) + \(remainingCount) more"
    }

    init(entries: [FoodLogEntry]) {
        var uniqueItems: [String: ProduceVarietyItem] = [:]

        for entry in entries where entry.portionGrams > 0 {
            if entry.hasQualitySnapshot {
                if let snapshotItems = entry.produceItemsSnapshot {
                    for item in snapshotItems {
                        Self.insert(
                            name: item.name,
                            kind: item.kind,
                            into: &uniqueItems
                        )
                    }
                } else {
                    Self.insert(
                        name: entry.foodName,
                        kind: entry.produceKindSnapshot ?? .unclassified,
                        into: &uniqueItems
                    )
                }
            } else if let foodItem = entry.foodItem {
                // Legacy entries (pre-snapshot) fall back to the live
                // saved-food relationship, exactly as before snapshots
                // existed. Once that food is deleted nothing is counted —
                // classifications are never fabricated.
                if foodItem.isRecipe, let ingredients = foodItem.recipeIngredients, !ingredients.isEmpty {
                    for ingredient in ingredients where ingredient.portionGrams > 0 {
                        Self.insert(
                            name: ingredient.name,
                            kind: ingredient.produceKind,
                            into: &uniqueItems
                        )
                    }
                } else {
                    Self.insert(
                        name: foodItem.name,
                        kind: foodItem.produceKind,
                        into: &uniqueItems
                    )
                }
            }
        }

        items = uniqueItems.values.sorted {
            if $0.kind != $1.kind {
                return $0.kind.sortOrder < $1.kind.sortOrder
            }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    nonisolated private static func insert(
        name: String,
        kind: ProduceKind,
        into uniqueItems: inout [String: ProduceVarietyItem]
    ) {
        guard kind.countsTowardVariety else { return }
        let displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !displayName.isEmpty else { return }

        let normalizedName = Self.normalizedName(displayName)
        guard !normalizedName.isEmpty else { return }

        let id = "\(kind.rawValue):\(normalizedName)"
        guard uniqueItems.index(forKey: id) == nil else { return }

        uniqueItems[id] = ProduceVarietyItem(id: id, name: displayName, kind: kind)
    }

    nonisolated private static func normalizedName(_ name: String) -> String {
        let folded = name
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
        let words = folded
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map(singularized(_:))
            .filter { !$0.isEmpty }

        return words.joined(separator: " ")
    }

    nonisolated private static func singularized(_ word: String) -> String {
        guard word.count > 3 else { return word }

        if word.hasSuffix("ies") {
            return String(word.dropLast(3)) + "y"
        }

        if word.hasSuffix("es") {
            let stem = String(word.dropLast(2))
            if stem.hasSuffix("ch") || stem.hasSuffix("sh") || stem.hasSuffix("s") || stem.hasSuffix("x") || stem.hasSuffix("z") {
                return stem
            }
        }

        if word.hasSuffix("s") && !word.hasSuffix("ss") {
            return String(word.dropLast())
        }

        return word
    }
}

private extension ProduceKind {
    nonisolated var sortOrder: Int {
        switch self {
        case .fruit:
            0
        case .vegetable:
            1
        case .unclassified:
            2
        }
    }
}
