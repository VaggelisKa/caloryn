import Foundation
import SwiftData

/// Records and reads the one-per-day goal snapshots that make History
/// date-accurate.
///
/// Finalization timing: the snapshot for the current calendar day is upserted
/// every time Today recomputes its calorie budget. The day's final target is
/// therefore whatever was last written before local midnight — once the device
/// rolls into the next day, `recordSnapshot` refuses to touch earlier days, so
/// history is never rewritten retroactively.
@MainActor
enum DailyGoalSnapshotStore {
    /// Upserts the snapshot for `date`, but only while `date` is still the
    /// current calendar day (per `calendar`/`now`). Past and future days are
    /// ignored: past days are already finalized, and future days have no
    /// authoritative target yet.
    ///
    /// Returns `true` when a snapshot was created or updated.
    @discardableResult
    static func recordSnapshot(
        values: DailyGoalSnapshotValues,
        for date: Date,
        profile: UserProfile?,
        in context: ModelContext,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Bool {
        guard calendar.isDate(date, inSameDayAs: now) else { return false }

        let key = DailyGoalSnapshot.dayKey(for: date, calendar: calendar)
        let existing = snapshots(withDayKey: key, in: context)

        var didChange = false
        if let snapshot = existing.first {
            // Clean up duplicates that can appear after CloudKit merges;
            // the most recently updated snapshot is authoritative.
            for duplicate in existing.dropFirst() {
                context.delete(duplicate)
                didChange = true
            }

            if !snapshot.matches(values, profile: profile) {
                snapshot.apply(values, profile: profile, recordedAt: now)
                didChange = true
            }
        } else {
            context.insert(
                DailyGoalSnapshot(
                    dayKey: key,
                    values: values,
                    profile: profile,
                    recordedAt: now
                )
            )
            didChange = true
        }

        guard didChange else { return false }
        do {
            try context.save()
            return true
        } catch {
            // Discard the insert, update, and duplicate deletions staged above.
            // Leaving them pending would let History read a target that was
            // never stored, or let an unrelated later save persist it. The
            // caller learns the day was not recorded and History falls back to
            // its documented estimate.
            context.rollback()
            return false
        }
    }

    /// Collapses fetched snapshots into one value per day key, preferring the
    /// most recently updated snapshot when duplicates exist.
    static func latestValuesByDayKey(
        _ snapshots: [DailyGoalSnapshot]
    ) -> [String: DailyGoalSnapshotValues] {
        var latest: [String: DailyGoalSnapshot] = [:]
        for snapshot in snapshots {
            if let current = latest[snapshot.dayKey], current.updatedAt >= snapshot.updatedAt {
                continue
            }
            latest[snapshot.dayKey] = snapshot
        }
        return latest.mapValues(\.values)
    }

    private static func snapshots(
        withDayKey key: String,
        in context: ModelContext
    ) -> [DailyGoalSnapshot] {
        let descriptor = FetchDescriptor<DailyGoalSnapshot>(
            predicate: #Predicate { $0.dayKey == key },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}

/// The per-day calorie target History compares against.
struct HistoryDayTarget: Equatable {
    let calories: Int

    /// `true` when no snapshot exists for the day and the target is a
    /// conservative estimate. Estimated days must not be presented with false
    /// precision — History surfaces them with an explicit note.
    let isEstimated: Bool
}

/// Resolves the effective calorie target for any calendar day.
///
/// Days with a persisted `DailyGoalSnapshot` use that snapshot's effective
/// target — the exact goal Today showed on that date. Legacy days recorded
/// before snapshots existed (or days the app was never opened) have no
/// snapshot; the documented fallback is the current profile's static calorie
/// target, flagged as estimated. This matches the pre-snapshot behavior of
/// History and deliberately avoids guessing historical Health adjustments.
struct HistoryDayTargetResolver {
    let fallbackTarget: Int
    private let valuesByDayKey: [String: DailyGoalSnapshotValues]

    init(
        fallbackTarget: Int,
        valuesByDayKey: [String: DailyGoalSnapshotValues] = [:]
    ) {
        self.fallbackTarget = fallbackTarget
        self.valuesByDayKey = valuesByDayKey
    }

    func target(for date: Date, calendar: Calendar = .current) -> HistoryDayTarget {
        let key = DailyGoalSnapshot.dayKey(for: date, calendar: calendar)
        guard let values = valuesByDayKey[key] else {
            return HistoryDayTarget(calories: fallbackTarget, isEstimated: true)
        }
        return HistoryDayTarget(calories: values.effectiveCalorieTarget, isEstimated: false)
    }
}
