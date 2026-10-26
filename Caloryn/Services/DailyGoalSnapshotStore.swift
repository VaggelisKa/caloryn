import Foundation
import SwiftData

@MainActor
enum DailyGoalSnapshotStore {
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
            context.rollback()
            return false
        }
    }

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

struct HistoryDayTarget: Equatable {
    let calories: Int
    let isEstimated: Bool
}

struct HistoryDayTargetResolver {
    let fallbackTarget: Int
    private let valuesByDayKey: [String: DailyGoalSnapshotValues]
    private let chronologicalDayKeys: [String]

    init(
        fallbackTarget: Int,
        valuesByDayKey: [String: DailyGoalSnapshotValues] = [:]
    ) {
        self.fallbackTarget = fallbackTarget
        self.valuesByDayKey = valuesByDayKey
        self.chronologicalDayKeys = valuesByDayKey.keys.sorted()
    }

    func target(for date: Date, calendar: Calendar = .current) -> HistoryDayTarget {
        let key = DailyGoalSnapshot.dayKey(for: date, calendar: calendar)
        if let values = valuesByDayKey[key] {
            return HistoryDayTarget(calories: values.calorieTarget, isEstimated: false)
        }
        return HistoryDayTarget(calories: estimatedTarget(forDayKey: key), isEstimated: true)
    }

    private func estimatedTarget(forDayKey key: String) -> Int {
        let nearestKey = chronologicalDayKeys.last { $0 < key } ?? chronologicalDayKeys.first
        guard let nearestKey, let values = valuesByDayKey[nearestKey] else { return fallbackTarget }
        return values.calorieTarget
    }
}
