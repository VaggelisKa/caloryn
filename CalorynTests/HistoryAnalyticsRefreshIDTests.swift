import Foundation
import Testing
@testable import Caloryn

/// A labeled single-field change, so each analytics-relevant field is its own
/// test case: the case fails by name when a field stops being captured.
struct FieldMutation<Model>: Sendable, CustomTestStringConvertible {
    let field: String
    let mutate: @MainActor (Model) -> Void

    var testDescription: String { field }
}

/// Pins the equality behavior History's `.task(id:)` recompute hangs on: the
/// refresh ID must stay equal while nothing analytics-relevant changed (no
/// spurious recompute), and must become unequal when any rendered fact of an
/// entry, the profile, a goal snapshot, the day, or the entry list itself
/// changes (no silently stale analytics).
///
/// Models are plain in-memory instances, mirroring `DailyGoalSnapshotTests`:
/// nothing here fetches, so no container is needed.
@MainActor
@Suite("History analytics refresh ID")
struct HistoryAnalyticsRefreshIDTests {

    // MARK: - Baselines

    /// An entry whose optional nutrients, Nutri-Score and produce kind are all
    /// present, so a mutation of any captured field is a real change.
    private func makeRichEntry() -> FoodLogEntry {
        makeTestEntry(
            date: makeTestDate(year: 2026, month: 3, day: 9),
            mealType: .breakfast,
            foodItem: makeTestFoodItem(
                name: "Greek Yogurt",
                caloriesPer100g: 150,
                proteinPer100g: 10,
                carbsPer100g: 8,
                fatPer100g: 9,
                fiberPer100g: 1,
                sugarsPer100g: 6,
                addedSugarsPer100g: 2,
                saturatedFatPer100g: 5,
                sodiumPer100g: 0.05,
                cholesterolPer100g: 0.01,
                alcoholPer100g: 0.5,
                nutriscoreGrade: "b",
                produceKind: .fruit
            ),
            portionGrams: 100
        )
    }

    private func makeProfile() -> UserProfile {
        UserProfile(
            age: 30,
            sex: .male,
            heightCm: 180,
            weightKg: 80,
            activityLevel: .moderatelyActive,
            dailyCalorieTarget: 2_000
        )
    }

    private func makeGoalSnapshot() -> DailyGoalSnapshot {
        DailyGoalSnapshot(
            dayKey: "2026-03-09",
            values: DailyGoalSnapshotValues(
                baseCalorieTarget: 2_000,
                healthAdjustment: 200,
                effectiveCalorieTarget: 2_200,
                calculationMode: .dynamicHealth,
                isManualTarget: false
            ),
            profile: nil,
            recordedAt: makeTestDate(year: 2026, month: 3, day: 9, hour: 8)
        )
    }

    private func makeRefreshID(
        dayStart: Date = makeTestDate(year: 2026, month: 3, day: 9, hour: 0),
        profile: UserProfile?,
        entries: [FoodLogEntry],
        goalSnapshots: [DailyGoalSnapshot]
    ) -> HistoryAnalyticsRefreshID {
        HistoryAnalyticsRefreshID(
            dayStart: dayStart,
            profile: profile.map(HistoryProfileSignature.init(profile:)),
            entries: entries.map(HistoryEntrySignature.init(entry:)),
            goalSnapshots: goalSnapshots.map(HistoryGoalSnapshotSignature.init(snapshot:))
        )
    }

    // MARK: - No spurious recompute

    @Test("given unchanged models, when the refresh ID is computed twice, then the IDs are equal so analytics do not rerun")
    func unchangedModelsProduceEqualRefreshIDs() {
        let profile = makeProfile()
        let entries = [makeRichEntry(), makeLegacyTestEntry(foodItem: makeTestFoodItem())]
        let snapshots = [makeGoalSnapshot()]

        let first = makeRefreshID(profile: profile, entries: entries, goalSnapshots: snapshots)
        let second = makeRefreshID(profile: profile, entries: entries, goalSnapshots: snapshots)

        #expect(first == second)
    }

    // MARK: - Entry fields trigger a recompute

    nonisolated private static let entryMutations: [FieldMutation<FoodLogEntry>] = [
        FieldMutation(field: "id (delete and re-log)") { $0.id = UUID() },
        FieldMutation(field: "date") { $0.date = makeTestDate(year: 2026, month: 3, day: 10) },
        FieldMutation(field: "mealType") { $0.mealType = .lunch },
        FieldMutation(field: "snackIndex") { $0.snackIndex = 3 },
        FieldMutation(field: "foodName") { $0.foodName = "Renamed Yogurt" },
        FieldMutation(field: "portionGrams") { $0.portionGrams = 150 },
        FieldMutation(field: "calories") { $0.calories += 10 },
        FieldMutation(field: "proteinG") { $0.proteinG += 1 },
        FieldMutation(field: "carbsG") { $0.carbsG += 1 },
        FieldMutation(field: "fatG") { $0.fatG += 1 },
        FieldMutation(field: "fiberG") { $0.fiberG += 1 },
        FieldMutation(field: "sugarsG") { $0.sugarsG = 7 },
        FieldMutation(field: "addedSugarsG") { $0.addedSugarsG = 3 },
        FieldMutation(field: "saturatedFatG") { $0.saturatedFatG = 6 },
        FieldMutation(field: "sodiumG") { $0.sodiumG = 0.2 },
        FieldMutation(field: "cholesterolG") { $0.cholesterolG = 0.05 },
        FieldMutation(field: "alcoholG cleared to nil") { $0.alcoholG = nil },
        FieldMutation(field: "nutriscore grade") { $0.nutriscoreGradeSnapshot = "d" },
        FieldMutation(field: "produce kind") {
            $0.produceKindSnapshotRaw = ProduceKind.vegetable.rawValue
        },
        FieldMutation(field: "produce items snapshot") {
            $0.produceItemsSnapshot = [FoodLogProduceItemSnapshot(name: "Apple", kind: .fruit)]
        }
    ]

    @Test(
        "given a logged entry, when one rendered field changes, then its signature changes so analytics rerun",
        arguments: entryMutations
    )
    func entryFieldChangeChangesTheSignature(mutation: FieldMutation<FoodLogEntry>) {
        let entry = makeRichEntry()
        let before = HistoryEntrySignature(entry: entry)

        mutation.mutate(entry)

        #expect(HistoryEntrySignature(entry: entry) != before)
    }

    // MARK: - Profile fields trigger a recompute

    nonisolated private static let profileMutations: [FieldMutation<UserProfile>] = [
        FieldMutation(field: "id (profile replaced)") { $0.id = UUID() },
        FieldMutation(field: "updatedAt") {
            $0.updatedAt = makeTestDate(year: 2020, month: 1, day: 1)
        },
        FieldMutation(field: "dailyCalorieTarget") { $0.dailyCalorieTarget += 100 },
        FieldMutation(field: "proteinTargetG") { $0.proteinTargetG += 5 },
        FieldMutation(field: "carbTargetG") { $0.carbTargetG += 5 },
        FieldMutation(field: "fatTargetG") { $0.fatTargetG += 5 },
        FieldMutation(field: "proteinGoalKindRaw") {
            $0.proteinGoalKindRaw = NutrientGoalKind.maximum.rawValue
        },
        FieldMutation(field: "carbGoalKindRaw") {
            $0.carbGoalKindRaw = NutrientGoalKind.maximum.rawValue
        },
        FieldMutation(field: "fatGoalKindRaw") {
            $0.fatGoalKindRaw = NutrientGoalKind.minimum.rawValue
        }
    ]

    @Test(
        "given a profile, when one target-shaping field changes, then its signature changes so analytics rerun",
        arguments: profileMutations
    )
    func profileFieldChangeChangesTheSignature(mutation: FieldMutation<UserProfile>) {
        let profile = makeProfile()
        let before = HistoryProfileSignature(profile: profile)

        mutation.mutate(profile)

        #expect(HistoryProfileSignature(profile: profile) != before)
    }

    // MARK: - Goal snapshot fields trigger a recompute

    nonisolated private static let goalSnapshotMutations: [FieldMutation<DailyGoalSnapshot>] = [
        FieldMutation(field: "dayKey") { $0.dayKey = "2026-03-10" },
        FieldMutation(field: "effectiveCalorieTarget") { $0.effectiveCalorieTarget += 100 },
        FieldMutation(field: "updatedAt (values re-recorded)") {
            $0.updatedAt = makeTestDate(year: 2026, month: 3, day: 9, hour: 20)
        }
    ]

    @Test(
        "given a day's goal snapshot, when one captured field changes, then its signature changes so analytics rerun",
        arguments: goalSnapshotMutations
    )
    func goalSnapshotFieldChangeChangesTheSignature(mutation: FieldMutation<DailyGoalSnapshot>) {
        let snapshot = makeGoalSnapshot()
        let before = HistoryGoalSnapshotSignature(snapshot: snapshot)

        mutation.mutate(snapshot)

        #expect(HistoryGoalSnapshotSignature(snapshot: snapshot) != before)
    }

    // MARK: - The remaining refresh-ID inputs

    @Test("given midnight passes, when the day start moves, then the refresh ID changes so the window advances")
    func dayStartChangeChangesTheRefreshID() {
        let profile = makeProfile()
        let entries = [makeRichEntry()]

        let today = makeRefreshID(
            dayStart: makeTestDate(year: 2026, month: 3, day: 9, hour: 0),
            profile: profile, entries: entries, goalSnapshots: []
        )
        let tomorrow = makeRefreshID(
            dayStart: makeTestDate(year: 2026, month: 3, day: 10, hour: 0),
            profile: profile, entries: entries, goalSnapshots: []
        )

        #expect(today != tomorrow)
    }

    @Test("given no profile yet, when onboarding creates one, then the refresh ID changes so analytics rerun")
    func profileAppearingChangesTheRefreshID() {
        let entries = [makeRichEntry()]

        let without = makeRefreshID(profile: nil, entries: entries, goalSnapshots: [])
        let with = makeRefreshID(profile: makeProfile(), entries: entries, goalSnapshots: [])

        #expect(without != with)
    }

    @Test("given the same entries, when their order changes, then the refresh ID changes")
    func entryOrderChangeChangesTheRefreshID() {
        let profile = makeProfile()
        let first = makeRichEntry()
        let second = makeTestEntry(
            date: makeTestDate(year: 2026, month: 3, day: 8),
            foodItem: makeTestFoodItem(name: "Oats")
        )

        let original = makeRefreshID(profile: profile, entries: [first, second], goalSnapshots: [])
        let reordered = makeRefreshID(profile: profile, entries: [second, first], goalSnapshots: [])

        #expect(original != reordered)
    }

    @Test("given a log, when an entry is added or removed, then the refresh ID changes")
    func entryCountChangeChangesTheRefreshID() {
        let profile = makeProfile()
        let first = makeRichEntry()
        let second = makeTestEntry(
            date: makeTestDate(year: 2026, month: 3, day: 8),
            foodItem: makeTestFoodItem(name: "Oats")
        )

        let one = makeRefreshID(profile: profile, entries: [first], goalSnapshots: [])
        let two = makeRefreshID(profile: profile, entries: [first, second], goalSnapshots: [])

        #expect(one != two)
    }

    @Test("given a day rolls over, when its goal snapshot is recorded, then the refresh ID changes")
    func goalSnapshotCountChangeChangesTheRefreshID() {
        let profile = makeProfile()
        let entries = [makeRichEntry()]

        let without = makeRefreshID(profile: profile, entries: entries, goalSnapshots: [])
        let with = makeRefreshID(
            profile: profile, entries: entries, goalSnapshots: [makeGoalSnapshot()]
        )

        #expect(without != with)
    }
}
