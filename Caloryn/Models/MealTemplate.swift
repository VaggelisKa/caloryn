import Foundation
import SwiftData

@Model
final class MealTemplate {
    var id: UUID = UUID()
    var name: String = ""
    var defaultMealRaw: String?
    var defaultSnackIndexRaw: Int?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var creationOperationID: UUID?
    var creationFingerprint: String?

    @Relationship(deleteRule: .cascade, inverse: \MealTemplateItem.template)
    var items: [MealTemplateItem]?

    init(
        name: String,
        defaultMeal: MealType,
        defaultSnackIndex: Int,
        creationOperationID: UUID,
        creationFingerprint: String,
        createdAt: Date = Date()
    ) {
        id = UUID()
        self.name = name
        defaultMealRaw = defaultMeal.rawValue
        defaultSnackIndexRaw = defaultMeal == .snack ? max(1, defaultSnackIndex) : 0
        self.creationOperationID = creationOperationID
        self.creationFingerprint = creationFingerprint
        self.createdAt = createdAt
        updatedAt = createdAt
    }

    var defaultMeal: MealType {
        get { MealType(rawValue: defaultMealRaw ?? "") ?? .breakfast }
        set { defaultMealRaw = newValue.rawValue }
    }

    var defaultSnackIndex: Int {
        get {
            defaultMeal == .snack ? max(1, defaultSnackIndexRaw ?? 1) : 0
        }
        set {
            defaultSnackIndexRaw = defaultMeal == .snack ? max(1, newValue) : 0
        }
    }

    var sortedItems: [MealTemplateItem] {
        (items ?? []).sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder {
                return lhs.sortOrder < rhs.sortOrder
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }
}

@Model
final class MealTemplateItem {
    var id: UUID = UUID()
    var sortOrder: Int = 0
    var sourceFoodID: UUID?
    var snapshotData: Data?
    var createdAt: Date = Date()

    var template: MealTemplate?

    init(
        snapshotData: Data,
        sourceFoodID: UUID?,
        sortOrder: Int,
        createdAt: Date = Date()
    ) {
        id = UUID()
        self.sortOrder = sortOrder
        self.sourceFoodID = sourceFoodID
        self.snapshotData = snapshotData
        self.createdAt = createdAt
    }
}
