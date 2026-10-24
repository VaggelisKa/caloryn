import Foundation

enum SnapshotEntryNotice {
    static func message(for source: FoodDataSource) -> String {
        switch source {
        case .linkImport:
            "This food was imported, so it isn’t saved in My Foods. Editing uses the nutrition values recorded in this log entry."
        case .calorynCatalog, .openFoodFactsCommunity, .userEntered, .mixed, .unknown:
            "The original saved food is missing. Editing uses the nutrition and quality values recorded in this log entry."
        }
    }
}
