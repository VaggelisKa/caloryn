import Foundation
import Testing
@testable import Caloryn

/// Characterizes `WidgetCalorieSummary` and `DailyWidgetSnapshot` from
/// `CalorynShared/WidgetSnapshot.swift`: the value types that cross the
/// app <-> widget-extension boundary as JSON. These are pure value types
/// with no shared global state, so tests run safely in parallel.
struct WidgetSnapshotModelTests {

    // MARK: - WidgetCalorieSummary boundary clamping

    @Test("Given negative consumed calories, when building a summary, then consumed clamps to zero")
    func negativeConsumedClampsToZero() {
        let summary = WidgetCalorieSummary(consumed: -50, baseTarget: 2_000, target: 2_000)

        #expect(summary.consumed == 0)
    }

    @Test("Given a zero base target, when building a summary, then baseTarget clamps to one")
    func zeroBaseTargetClampsToOne() {
        let summary = WidgetCalorieSummary(consumed: 0, baseTarget: 0, target: 2_000)

        #expect(summary.baseTarget == 1)
    }

    @Test("Given a negative target, when building a summary, then target clamps to one")
    func negativeTargetClampsToOne() {
        let summary = WidgetCalorieSummary(consumed: 0, baseTarget: 2_000, target: -100)

        #expect(summary.target == 1)
    }

    @Test("Given fractional consumed calories, when building a summary, then consumed rounds to the nearest integer")
    func fractionalConsumedRoundsToNearestInteger() {
        let summary = WidgetCalorieSummary(consumed: 799.6, baseTarget: 2_000, target: 2_000)

        #expect(summary.consumed == 800)
    }

    @Test("Given consumed calories exceeding the target, when reading remaining, then remaining floors at zero")
    func remainingFloorsAtZeroWhenOverTarget() {
        let summary = WidgetCalorieSummary(consumed: 2_500, baseTarget: 2_000, target: 2_000)

        #expect(summary.remaining == 0)
        #expect(summary.overAmount == 500)
        #expect(summary.isOver)
    }

    @Test("Given consumed calories under the target, when reading overAmount, then overAmount is zero and isOver is false")
    func overAmountIsZeroWhenUnderTarget() {
        let summary = WidgetCalorieSummary(consumed: 500, baseTarget: 2_000, target: 2_000)

        #expect(summary.overAmount == 0)
        #expect(!summary.isOver)
        #expect(summary.remaining == 1_500)
    }

    @Test("Given consumed calories double the target, when reading progress, then progress clamps to one")
    func progressClampsToOneWhenFarOverTarget() {
        let summary = WidgetCalorieSummary(consumed: 4_000, baseTarget: 2_000, target: 2_000)

        #expect(summary.progress == 1)
    }

    @Test("Given zero consumed calories, when reading progress, then progress is zero")
    func progressIsZeroWhenNothingConsumed() {
        let summary = WidgetCalorieSummary(consumed: 0, baseTarget: 2_000, target: 2_000)

        #expect(summary.progress == 0)
    }

    @Test("Given a typical partial day, when reading progress, then progress reflects the consumed fraction")
    func progressReflectsPartialConsumption() {
        let summary = WidgetCalorieSummary(consumed: 500, baseTarget: 2_000, target: 2_000)

        #expect(summary.progress == 0.25)
    }

    // MARK: - Encode/decode round trip (mirrors WidgetSnapshotStore's coding strategy)

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    @Test("Given a populated snapshot, when encoding then decoding, then the round trip yields an equal value")
    func snapshotRoundTripsThroughJSON() throws {
        let snapshot = DailyWidgetSnapshot(
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            dayStart: Date(timeIntervalSince1970: 1_700_000_000).startOfDay,
            state: .ready,
            calories: WidgetCalorieSummary(consumed: 1_234, baseTarget: 1_900, target: 2_100, dynamicAdjustment: 200),
            usesDynamicTarget: true,
            activityRefreshedAt: Date(timeIntervalSince1970: 1_700_000_500)
        )

        let data = try Self.encoder.encode(snapshot)
        let decoded = try Self.decoder.decode(DailyWidgetSnapshot.self, from: data)

        #expect(decoded == snapshot)
    }

    @Test("Given JSON missing the activityRefreshedAt key, when decoding, then it decodes to nil instead of failing")
    func missingOptionalFieldDecodesToNil() throws {
        let snapshot = DailyWidgetSnapshot(
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            dayStart: Date(timeIntervalSince1970: 1_700_000_000).startOfDay,
            state: .ready,
            calories: WidgetCalorieSummary(consumed: 500, baseTarget: 2_000, target: 2_000),
            activityRefreshedAt: Date(timeIntervalSince1970: 1_700_000_500)
        )
        var data = try Self.encoder.encode(snapshot)
        var json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "activityRefreshedAt")
        data = try JSONSerialization.data(withJSONObject: json)

        let decoded = try Self.decoder.decode(DailyWidgetSnapshot.self, from: data)

        #expect(decoded.activityRefreshedAt == nil)
    }

    @Test("Given JSON with an unrecognized extra field, when decoding, then the known fields still decode successfully")
    func unknownExtraFieldIsIgnoredWhenDecoding() throws {
        let snapshot = DailyWidgetSnapshot(
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            dayStart: Date(timeIntervalSince1970: 1_700_000_000).startOfDay,
            state: .ready,
            calories: WidgetCalorieSummary(consumed: 500, baseTarget: 2_000, target: 2_000)
        )
        var data = try Self.encoder.encode(snapshot)
        var json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        json["futureFieldFromANewerAppVersion"] = "unexpected-value"
        data = try JSONSerialization.data(withJSONObject: json)

        let decoded = try Self.decoder.decode(DailyWidgetSnapshot.self, from: data)

        #expect(decoded.state == .ready)
        #expect(decoded.calories.consumed == 500)
    }

    @Test("Given garbage bytes, when decoding, then decoding throws instead of crashing")
    func garbageDataThrowsInsteadOfCrashing() {
        let garbage = Data([0xFF, 0x00, 0xDE, 0xAD, 0xBE, 0xEF])

        #expect(throws: (any Error).self) {
            try Self.decoder.decode(DailyWidgetSnapshot.self, from: garbage)
        }
    }

    @Test("Given well-formed JSON with a wrong-typed field, when decoding, then decoding throws instead of crashing")
    func wrongTypedFieldThrowsInsteadOfCrashing() throws {
        let snapshot = DailyWidgetSnapshot(
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            dayStart: Date(timeIntervalSince1970: 1_700_000_000).startOfDay,
            state: .ready,
            calories: WidgetCalorieSummary(consumed: 500, baseTarget: 2_000, target: 2_000)
        )
        var data = try Self.encoder.encode(snapshot)
        var json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        var calories = try #require(json["calories"] as? [String: Any])
        calories["consumed"] = "not-a-number"
        json["calories"] = calories
        data = try JSONSerialization.data(withJSONObject: json)

        #expect(throws: (any Error).self) {
            try Self.decoder.decode(DailyWidgetSnapshot.self, from: data)
        }
    }

    @Test("Given empty data, when decoding, then decoding throws instead of crashing")
    func emptyDataThrowsInsteadOfCrashing() {
        #expect(throws: (any Error).self) {
            try Self.decoder.decode(DailyWidgetSnapshot.self, from: Data())
        }
    }

    // MARK: - displaySnapshot staleness

    @Test("Given a needsOnboarding snapshot from a prior day, when requesting a display snapshot for today, then it is returned unchanged and not marked stale")
    func nonReadyStateIsNeverMarkedStale() {
        let calendar = Calendar(identifier: .gregorian)
        let day = calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 12))!
        let nextDay = calendar.date(byAdding: .day, value: 1, to: day)!
        let snapshot = DailyWidgetSnapshot.needsOnboarding(at: day, calendar: calendar)

        let result = snapshot.displaySnapshot(at: nextDay, calendar: calendar)

        #expect(result.isStale == false)
        #expect(result.snapshot == snapshot)
    }

    @Test("Given a ready snapshot for the same day, when requesting a display snapshot, then it is returned unchanged and not marked stale")
    func sameDaySnapshotIsNeverMarkedStale() {
        let calendar = Calendar(identifier: .gregorian)
        let day = calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 9))!
        let laterSameDay = calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 20))!
        let snapshot = DailyWidgetSnapshot(
            generatedAt: day,
            dayStart: calendar.startOfDay(for: day),
            state: .ready,
            calories: WidgetCalorieSummary(consumed: 800, baseTarget: 2_000, target: 2_000)
        )

        let result = snapshot.displaySnapshot(at: laterSameDay, calendar: calendar)

        #expect(result.isStale == false)
        #expect(result.snapshot == snapshot)
    }

    // MARK: - Fixed-state factories

    @Test("Given the needsOnboarding factory, when built, then it uses the fixed 2000 kcal fallback target with zero consumed")
    func needsOnboardingUsesFixedFallbackTarget() {
        let snapshot = DailyWidgetSnapshot.needsOnboarding(at: .now)

        #expect(snapshot.state == .needsOnboarding)
        #expect(snapshot.calories.consumed == 0)
        #expect(snapshot.calories.target == 2_000)
    }

    @Test("Given the unavailable factory, when built, then the state is unavailable with zero consumed")
    func unavailableFactoryProducesUnavailableState() {
        let snapshot = DailyWidgetSnapshot.unavailable(at: .now)

        #expect(snapshot.state == .unavailable)
        #expect(snapshot.calories.consumed == 0)
    }

    @Test("Given two snapshots differing only by state, when comparing render identity, then they are not equal")
    func renderIdentityDiffersWhenStateDiffers() {
        let dayStart = Date(timeIntervalSince1970: 1_700_000_000).startOfDay
        let calories = WidgetCalorieSummary(consumed: 500, baseTarget: 2_000, target: 2_000)
        let ready = DailyWidgetSnapshot(generatedAt: dayStart, dayStart: dayStart, state: .ready, calories: calories)
        let unavailable = DailyWidgetSnapshot(generatedAt: dayStart, dayStart: dayStart, state: .unavailable, calories: calories)

        #expect(ready.renderIdentity != unavailable.renderIdentity)
    }
}
