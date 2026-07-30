import Foundation
import SwiftData

struct FavoriteIntentCandidate: Equatable, Sendable {
    enum Kind: String, Sendable {
        case manualFood = "Manual food"
        case recipe = "Recipe"
    }

    let id: String
    let name: String
    let brand: String?
    let kind: Kind
    let portionGrams: Double
    let favoritedAt: Date?
    let displayTitle: String

    var displaySubtitle: String {
        "\(kind.rawValue), last logged \(IntentNumberFormatting.grams(portionGrams)) g"
    }
}

@MainActor
enum FavoriteIntentCatalog {
    static func candidates(from foods: [FoodItem]) -> [FavoriteIntentCandidate] {
        let eligible = foods.compactMap { food -> FavoriteIntentCandidate? in
            guard food.isFavorite,
                  food.isManualEntryOrRecipe,
                  FavoriteFoodLogging.isAvailableForLogging(food),
                  let portion = FavoriteFoodLogging.mostRecentlyLoggedSafePortion(for: food) else {
                return nil
            }

            return FavoriteIntentCandidate(
                id: food.id.uuidString,
                name: food.name,
                brand: food.brand,
                kind: food.isRecipe ? .recipe : .manualFood,
                portionGrams: portion,
                favoritedAt: food.pinnedAt,
                displayTitle: food.name
            )
        }
        .sorted(by: candidateSort)

        let nameCounts = Dictionary(
            grouping: eligible,
            by: { normalizedName($0.name) }
        )
        let explicitTitles = eligible.map { candidate -> String in
            guard nameCounts[normalizedName(candidate.name), default: []].count > 1 else {
                return candidate.name
            }
            return "\(candidate.name) — \(candidate.kind.rawValue), last logged \(IntentNumberFormatting.grams(candidate.portionGrams)) g"
        }
        let titleCounts = Dictionary(grouping: explicitTitles, by: normalizedName)

        return zip(eligible, explicitTitles).map { candidate, explicitTitle in
            let displayTitle: String
            if titleCounts[normalizedName(explicitTitle), default: []].count == 1 {
                displayTitle = explicitTitle
            } else if let brand = candidate.brand?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !brand.isEmpty {
                displayTitle = "\(explicitTitle), \(brand)"
            } else {
                displayTitle = "\(explicitTitle), ID \(candidate.id.prefix(4))"
            }

            return FavoriteIntentCandidate(
                id: candidate.id,
                name: candidate.name,
                brand: candidate.brand,
                kind: candidate.kind,
                portionGrams: candidate.portionGrams,
                favoritedAt: candidate.favoritedAt,
                displayTitle: displayTitle
            )
        }
    }

    nonisolated static func matches(
        _ candidate: FavoriteIntentCandidate,
        search: String
    ) -> Bool {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }

        let searchableText = [
            candidate.name,
            candidate.brand,
            candidate.kind.rawValue,
            candidate.displayTitle,
        ]
        .compactMap { $0 }
        .joined(separator: " ")

        return searchableText.range(
            of: query,
            options: [.caseInsensitive, .diacriticInsensitive]
        ) != nil
    }

    private static func candidateSort(
        _ lhs: FavoriteIntentCandidate,
        _ rhs: FavoriteIntentCandidate
    ) -> Bool {
        let lhsDate = lhs.favoritedAt ?? .distantPast
        let rhsDate = rhs.favoritedAt ?? .distantPast
        if lhsDate != rhsDate {
            return lhsDate > rhsDate
        }

        let nameComparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
        if nameComparison != .orderedSame {
            return nameComparison == .orderedAscending
        }
        return lhs.id < rhs.id
    }

    private static func normalizedName(_ value: String) -> String {
        value.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        )
    }
}

struct FavoriteIntentLogResult: Equatable, Sendable {
    let foodName: String
    let portionGrams: Double
    let meal: MealType
    let calories: Double

    var response: String {
        "Logged \(IntentNumberFormatting.grams(portionGrams)) g of \(foodName) to \(meal.rawValue) — \(IntentNumberFormatting.calories(calories)) calories."
    }
}

@MainActor
enum FavoriteIntentLogging {
    enum Error: LocalizedError, Equatable {
        case unauthenticated
        case unavailable

        var errorDescription: String? {
            switch self {
            case .unauthenticated:
                "Open Caloryn and finish setup before logging a favorite."
            case .unavailable:
                "That favorite is no longer available for quick logging. Open Caloryn to log it manually."
            }
        }
    }

    static func log(
        favoriteID: String,
        meal: MealType,
        in modelContext: ModelContext,
        now: Date = .now,
        calendar: Calendar = .current
    ) throws -> FavoriteIntentLogResult {
        guard try hasAuthenticatedUser(in: modelContext) else {
            throw Error.unauthenticated
        }
        guard let id = UUID(uuidString: favoriteID) else {
            throw Error.unavailable
        }

        let descriptor = FetchDescriptor<FoodItem>(
            predicate: #Predicate { food in
                food.id == id
            }
        )
        guard let food = try modelContext.fetch(descriptor).first,
              food.isFavorite,
              food.isManualEntryOrRecipe,
              FavoriteFoodLogging.isAvailableForLogging(food),
              let portion = FavoriteFoodLogging.mostRecentlyLoggedSafePortion(for: food) else {
            throw Error.unavailable
        }

        let entry = DailyFoodLogCommands.logFood(
            foodItem: food,
            portionGrams: portion,
            mealType: meal,
            logDate: calendar.startOfDay(for: now),
            isNewFood: false,
            modelContext: modelContext,
            now: now
        )
        try modelContext.save()

        return FavoriteIntentLogResult(
            foodName: entry.foodName,
            portionGrams: entry.portionGrams,
            meal: entry.mealType,
            calories: entry.calories
        )
    }

    static func hasAuthenticatedUser(in modelContext: ModelContext) throws -> Bool {
        try !modelContext.fetch(FetchDescriptor<UserProfile>()).isEmpty
    }
}

enum TodayCaloriesIntentResponse: Equatable, Sendable {
    case available(String)
    case unavailable(String)

    static func make(
        snapshot: DailyWidgetSnapshot?,
        currentConsumed: Double,
        expectedBaseTarget: Int,
        expectedTarget: Int,
        expectsDynamicTarget: Bool,
        now: Date = .now,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> TodayCaloriesIntentResponse {
        guard let snapshot,
              snapshot.state == .ready,
              calendar.isDate(snapshot.dayStart, inSameDayAs: now),
              snapshot.calories.consumed == max(0, currentConsumed.rounded().truncatedSafely),
              snapshot.calories.baseTarget == max(1, expectedBaseTarget),
              snapshot.calories.target == max(1, expectedTarget),
              snapshot.usesDynamicTarget == expectsDynamicTarget else {
            return .unavailable("Open Caloryn to refresh today’s calorie snapshot.")
        }

        return make(
            consumed: snapshot.calories.consumed,
            target: snapshot.calories.target > 0 ? snapshot.calories.target : nil,
            locale: locale
        )
    }

    static func make(
        consumed: Int,
        target: Int?,
        locale: Locale = .current
    ) -> TodayCaloriesIntentResponse {
        let safeConsumed = max(0, consumed)
        let consumedText = formatted(safeConsumed, locale: locale)
        guard let target, target > 0 else {
            return .available("\(consumedText) calories logged today.")
        }

        let targetText = formatted(target, locale: locale)
        if safeConsumed > target {
            let over = formatted(
                safeConsumed - target,
                locale: locale
            )
            return .available(
                "\(consumedText) of \(targetText) calories logged today. \(over) over target."
            )
        }

        let remaining = formatted(
            target - safeConsumed,
            locale: locale
        )
        return .available(
            "\(consumedText) of \(targetText) calories logged today. \(remaining) remaining."
        )
    }

    private static func formatted(_ value: Int, locale: Locale) -> String {
        value.formatted(
            .number
                .locale(locale)
                .grouping(.automatic)
                .precision(.fractionLength(0))
        )
    }
}

enum IntentNumberFormatting {
    static func grams(_ value: Double) -> String {
        value.formatted(
            .number
                .grouping(.never)
                .precision(.fractionLength(0...2))
        )
    }

    static func calories(_ value: Double) -> String {
        value.rounded().truncatedSafely.formatted(.number.grouping(.automatic))
    }
}
