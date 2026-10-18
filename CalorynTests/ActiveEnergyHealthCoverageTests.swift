import Foundation
import Testing
import XCTest
@testable import Caloryn

nonisolated private final class CoverageActiveEnergyReader: ActiveEnergyReading, @unchecked Sendable {
    var isAvailable = true
    var activeEnergy: @MainActor (Date) async throws -> Double = { _ in 0 }
    var history: @MainActor (Date, Date) async throws -> [DailyActiveEnergySample] = { _, _ in [] }
    var observationToReturn: @MainActor () -> ActiveEnergyObservation? = { nil }
    var authorizationError: Error?

    private(set) var activeEnergyRequests: [(date: Date, calendar: Calendar)] = []
    private(set) var historyRequests: [(start: Date, end: Date, calendar: Calendar)] = []
    private(set) var observeCallCount = 0
    private(set) var authorizationRequestCount = 0
    private(set) var latestOnChange: (@MainActor () -> Void)?

    var isHealthDataAvailable: Bool { isAvailable }

    @MainActor
    func requestActiveEnergyAuthorization() async throws {
        authorizationRequestCount += 1
        if let authorizationError { throw authorizationError }
    }

    @MainActor
    func activeEnergyBurnedKcal(for date: Date, calendar: Calendar) async throws -> Double {
        activeEnergyRequests.append((date, calendar))
        return try await activeEnergy(date)
    }

    @MainActor
    func dailyActiveEnergyBurnedKcal(
        from startDate: Date,
        to endDate: Date,
        calendar: Calendar
    ) async throws -> [DailyActiveEnergySample] {
        historyRequests.append((startDate, endDate, calendar))
        return try await history(startDate, endDate)
    }

    @MainActor
    func observeActiveEnergyChanges(onChange: @escaping @MainActor () -> Void) -> ActiveEnergyObservation? {
        observeCallCount += 1
        latestOnChange = onChange
        return observationToReturn()
    }
}

private enum CoverageReadError: LocalizedError {
    case failed

    var errorDescription: String? { "History read failed." }
}

private func coverageCalendar(_ identifier: String) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: identifier)!
    return calendar
}

private func coverageDate(
    _ calendar: Calendar,
    _ year: Int,
    _ month: Int,
    _ day: Int,
    _ hour: Int = 12,
    _ minute: Int = 0
) -> Date {
    calendar.date(from: DateComponents(
        year: year, month: month, day: day, hour: hour, minute: minute
    ))!
}

private func clearCoverageHealthDefaults() {
    UserDefaults.standard.removeObject(forKey: AppleHealthAdjustmentSettings.adjustmentEnabledKey)
    UserDefaults.standard.removeObject(forKey: AppleHealthAdjustmentSettings.authorizationRequestedKey)
    AppleHealthAdjustmentSettings.clearEmptyActiveEnergyTracking()
}

@MainActor
final class ActiveEnergyDayTrackerCoverageTests: XCTestCase {
    override func setUp() {
        super.setUp()
        clearCoverageHealthDefaults()
    }

    override func tearDown() {
        clearCoverageHealthDefaults()
        super.tearDown()
    }

    func testRefreshWhenActiveRereadsTodayAndRetriesAnObserverThatNeverStarted() async {
        let reader = CoverageActiveEnergyReader()
        reader.activeEnergy = { _ in 100 }
        let tracker = ActiveEnergyDayTracker(reader: reader)

        await tracker.configure(date: makeTestDate(year: 2026, month: 2, day: 14), isEnabled: true)
        XCTAssertEqual(tracker.activeEnergyKcal, 100, accuracy: 0.001)
        XCTAssertEqual(reader.observeCallCount, 1)

        reader.activeEnergy = { _ in 200 }
        tracker.refreshWhenActive()

        XCTAssertEqual(reader.observeCallCount, 2)
        await waitUntil { tracker.activeEnergyKcal == 200 }
        XCTAssertEqual(tracker.activeEnergyKcal, 200, accuracy: 0.001)
        XCTAssertEqual(reader.activeEnergyRequests.count, 2)
    }

    func testRefreshWhenActiveKeepsARunningObserverInsteadOfStartingAnother() async {
        let reader = CoverageActiveEnergyReader()
        var stopCount = 0
        reader.observationToReturn = { ActiveEnergyObservation { stopCount += 1 } }
        reader.activeEnergy = { _ in 50 }
        let tracker = ActiveEnergyDayTracker(reader: reader)

        await tracker.configure(date: makeTestDate(year: 2026, month: 2, day: 14), isEnabled: true)
        reader.activeEnergy = { _ in 75 }
        tracker.refreshWhenActive()
        await waitUntil { tracker.activeEnergyKcal == 75 }

        XCTAssertEqual(reader.observeCallCount, 1)
        XCTAssertEqual(stopCount, 0)
        XCTAssertEqual(tracker.activeEnergyKcal, 75, accuracy: 0.001)
    }

    func testRefreshWhenActiveDoesNothingWhileDisabled() async {
        let reader = CoverageActiveEnergyReader()
        let tracker = ActiveEnergyDayTracker(reader: reader)

        await tracker.configure(date: makeTestDate(year: 2026, month: 2, day: 14), isEnabled: false)
        tracker.refreshWhenActive()
        await settle()

        XCTAssertEqual(reader.observeCallCount, 0)
        XCTAssertTrue(reader.activeEnergyRequests.isEmpty)
        XCTAssertNil(tracker.lastRefresh)
    }

    func testObserverFiringAfterDisableDoesNotReadHealthAgain() async {
        let reader = CoverageActiveEnergyReader()
        reader.observationToReturn = { ActiveEnergyObservation {} }
        reader.activeEnergy = { _ in 180 }
        let tracker = ActiveEnergyDayTracker(reader: reader)

        await tracker.configure(date: makeTestDate(year: 2026, month: 2, day: 14), isEnabled: true)
        XCTAssertEqual(tracker.activeEnergyKcal, 180, accuracy: 0.001)

        await tracker.configure(date: makeTestDate(year: 2026, month: 2, day: 14), isEnabled: false)
        reader.latestOnChange?()
        await settle()

        XCTAssertEqual(reader.activeEnergyRequests.count, 1)
        XCTAssertEqual(tracker.activeEnergyKcal, 0, accuracy: 0.001)
        XCTAssertNil(tracker.lastRefresh)
        XCTAssertFalse(tracker.isLoading)
    }

    func testAFutureSelectedDayReadsHistoryOnlyUpToTheStartOfToday() async {
        let today = Date.now.startOfDay
        let future = Calendar.current.date(byAdding: .day, value: 3, to: today)!
            .addingTimeInterval(9 * 3_600)
        let reader = CoverageActiveEnergyReader()
        let tracker = ActiveEnergyDayTracker(reader: reader)

        await tracker.configure(date: future, isEnabled: true)

        XCTAssertEqual(reader.activeEnergyRequests.map(\.date), [future.startOfDay])
        XCTAssertEqual(reader.historyRequests.count, 1)
        XCTAssertEqual(reader.historyRequests.first?.end, today)
        XCTAssertEqual(
            reader.historyRequests.first?.start,
            Calendar.current.date(byAdding: .day, value: -21, to: today)
        )
    }

    func testEmptyActivityOnAPastDayNeverCountsTowardsTheAccessHint() async {
        let reader = CoverageActiveEnergyReader()
        let tracker = ActiveEnergyDayTracker(reader: reader)
        let pastDays = (1...3).map {
            Calendar.current.date(byAdding: .day, value: -$0 * 10, to: Date.now.startOfDay)!
        }

        for day in pastDays {
            await tracker.configure(date: day, isEnabled: true)
            XCTAssertNil(tracker.emptyActivityNotice)
        }

        XCTAssertEqual(
            UserDefaults.standard.integer(forKey: AppleHealthAdjustmentSettings.emptyActiveEnergyRefreshCountKey),
            0
        )
        XCTAssertNil(UserDefaults.standard.object(forKey: AppleHealthAdjustmentSettings.emptyActiveEnergyFirstSeenKey))
    }

    func testASuccessfulReadStampsLastRefreshAndDisablingClearsIt() async {
        let reader = CoverageActiveEnergyReader()
        reader.activeEnergy = { _ in 90 }
        let samples = [DailyActiveEnergySample(date: makeTestDate(year: 2026, month: 2, day: 13), activeEnergyKcal: 300)]
        reader.history = { _, _ in samples }
        let tracker = ActiveEnergyDayTracker(reader: reader)

        let before = Date()
        await tracker.configure(date: makeTestDate(year: 2026, month: 2, day: 14), isEnabled: true)
        let after = Date()

        guard let stamped = tracker.lastRefresh else {
            return XCTFail("A successful read must stamp lastRefresh")
        }
        XCTAssertGreaterThanOrEqual(stamped, before)
        XCTAssertLessThanOrEqual(stamped, after)
        XCTAssertEqual(tracker.recentActiveEnergySamples, samples)

        await tracker.configure(date: makeTestDate(year: 2026, month: 2, day: 14), isEnabled: false)

        XCTAssertNil(tracker.lastRefresh)
        XCTAssertEqual(tracker.recentActiveEnergySamples, [])
    }

    func testAFailedHistoryReadClearsEarlierSamplesAndStopsObserving() async {
        AppleHealthAdjustmentSettings.persist(isEnabled: true, authorizationRequested: true, message: nil)
        let reader = CoverageActiveEnergyReader()
        var stopCount = 0
        reader.observationToReturn = { ActiveEnergyObservation { stopCount += 1 } }
        let samples = [DailyActiveEnergySample(date: makeTestDate(year: 2026, month: 2, day: 13), activeEnergyKcal: 300)]
        reader.activeEnergy = { _ in 120 }
        reader.history = { _, _ in samples }
        let tracker = ActiveEnergyDayTracker(reader: reader)

        await tracker.configure(date: makeTestDate(year: 2026, month: 2, day: 14), isEnabled: true)
        XCTAssertEqual(tracker.recentActiveEnergySamples, samples)

        reader.history = { _, _ in throw CoverageReadError.failed }
        await tracker.configure(date: makeTestDate(year: 2026, month: 2, day: 15), isEnabled: true)

        XCTAssertEqual(tracker.recentActiveEnergySamples, [])
        XCTAssertEqual(tracker.activeEnergyKcal, 0, accuracy: 0.001)
        XCTAssertEqual(tracker.message, "History read failed.")
        XCTAssertEqual(stopCount, 1)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: AppleHealthAdjustmentSettings.adjustmentEnabledKey))
    }

    private func settle() async {
        for _ in 0..<5 {
            await Task.yield()
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<100 where !condition() {
            await Task.yield()
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}

final class AppleHealthAdjustmentSettingsCoverageTests: XCTestCase {
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    override func setUp() {
        super.setUp()
        clearCoverageHealthDefaults()
    }

    override func tearDown() {
        clearCoverageHealthDefaults()
        super.tearDown()
    }

    func testAuthorizationRequestedReadsBackWhatWasPersisted() {
        XCTAssertFalse(AppleHealthAdjustmentSettings.authorizationRequested)

        AppleHealthAdjustmentSettings.persist(isEnabled: false, authorizationRequested: true, message: nil)
        XCTAssertTrue(AppleHealthAdjustmentSettings.authorizationRequested)

        AppleHealthAdjustmentSettings.disable()
        XCTAssertFalse(AppleHealthAdjustmentSettings.authorizationRequested)
    }

    func testHealthIsAvailableOnTheIPhoneSimulator() {
        XCTAssertTrue(AppleHealthAdjustmentSettings.isHealthAvailable)
    }

    func testUserFacingCopy() {
        XCTAssertEqual(AppleHealthAdjustmentSettings.dynamicEnergyPolicyText, "Apple Health activity")
        XCTAssertEqual(AppleHealthAdjustmentSettings.dynamicEnergyShortText, "Auto-adjust calories")
        XCTAssertEqual(AppleHealthAdjustmentSettings.unavailableMessage, "Apple Health is not available on this device.")
        XCTAssertEqual(
            AppleHealthAdjustmentSettings.connectedWaitingMessage,
            "Auto-adjust is on. Waiting for Active Energy data."
        )
        XCTAssertEqual(
            AppleHealthAdjustmentSettings.emptyActivityAccessMessage,
            "No Active Energy found yet. This can happen if activity has not been recorded or Health access is off."
        )
    }

    func testAFullDayOfEmptyRefreshesShowsTheHintAfterOnlyTwoRefreshes() {
        XCTAssertNil(record(empty: true, at: t0))

        XCTAssertEqual(
            record(empty: true, at: t0.addingTimeInterval(86_400)),
            AppleHealthAdjustmentSettings.emptyActivityAccessMessage
        )
    }

    func testOneSecondShortOfADayStaysQuietOnTheSecondRefresh() {
        XCTAssertNil(record(empty: true, at: t0))
        XCTAssertNil(record(empty: true, at: t0.addingTimeInterval(86_399)))
    }

    func testTheFirstEmptySightingIsKeptWhileTheCountGrows() {
        _ = record(empty: true, at: t0)
        _ = record(empty: true, at: t0.addingTimeInterval(600))

        XCTAssertEqual(
            UserDefaults.standard.object(forKey: AppleHealthAdjustmentSettings.emptyActiveEnergyFirstSeenKey) as? Date,
            t0
        )
        XCTAssertEqual(
            UserDefaults.standard.integer(forKey: AppleHealthAdjustmentSettings.emptyActiveEnergyRefreshCountKey),
            2
        )
    }

    func testRecentHistoryAloneCountsAsActivityAndResetsTheStreak() {
        _ = record(empty: true, at: t0)
        _ = record(empty: true, at: t0.addingTimeInterval(60))

        let result = AppleHealthAdjustmentSettings.recordActiveEnergyRefresh(
            activeEnergyKcal: 0,
            recentActiveEnergySamples: [DailyActiveEnergySample(date: t0, activeEnergyKcal: 1)],
            now: t0.addingTimeInterval(120)
        )

        XCTAssertNil(result)
        XCTAssertNil(UserDefaults.standard.object(forKey: AppleHealthAdjustmentSettings.emptyActiveEnergyRefreshCountKey))
        XCTAssertNil(UserDefaults.standard.object(forKey: AppleHealthAdjustmentSettings.emptyActiveEnergyFirstSeenKey))
    }

    func testZeroValuedHistoryDaysStillCountAsEmpty() {
        let zeroSamples = (1...3).map {
            DailyActiveEnergySample(date: t0.addingTimeInterval(Double(-$0) * 86_400), activeEnergyKcal: 0)
        }
        var results: [String?] = []
        for offset in 0..<3 {
            results.append(AppleHealthAdjustmentSettings.recordActiveEnergyRefresh(
                activeEnergyKcal: 0,
                recentActiveEnergySamples: zeroSamples,
                now: t0.addingTimeInterval(Double(offset) * 60)
            ))
        }

        XCTAssertEqual(results, [nil, nil, AppleHealthAdjustmentSettings.emptyActivityAccessMessage])
    }

    func testDisablingRestartsTheEmptyActivityStreak() {
        _ = record(empty: true, at: t0)
        _ = record(empty: true, at: t0.addingTimeInterval(60))

        AppleHealthAdjustmentSettings.disable()

        XCTAssertNil(record(empty: true, at: t0.addingTimeInterval(120)))
        XCTAssertNil(record(empty: true, at: t0.addingTimeInterval(180)))
    }

    @MainActor
    func testRefusedAuthorizationAlsoRestartsTheStreak() async {
        _ = record(empty: true, at: t0)
        _ = record(empty: true, at: t0.addingTimeInterval(60))
        let reader = CoverageActiveEnergyReader()
        reader.authorizationError = CoverageReadError.failed

        let update = await AppleHealthAdjustmentSettings.enable(reader: reader)

        XCTAssertEqual(update, AppleHealthAdjustmentUpdate(
            isEnabled: false,
            authorizationRequested: true,
            message: "History read failed."
        ))
        XCTAssertNil(UserDefaults.standard.object(forKey: AppleHealthAdjustmentSettings.emptyActiveEnergyRefreshCountKey))
    }

    @MainActor
    func testUnavailableHealthNeverAsksAndForgetsAnyEarlierRequest() async {
        AppleHealthAdjustmentSettings.persist(isEnabled: true, authorizationRequested: true, message: nil)
        let reader = CoverageActiveEnergyReader()
        reader.isAvailable = false

        let update = await AppleHealthAdjustmentSettings.enable(reader: reader)

        XCTAssertEqual(reader.authorizationRequestCount, 0)
        XCTAssertEqual(update, AppleHealthAdjustmentUpdate(
            isEnabled: false,
            authorizationRequested: false,
            message: AppleHealthAdjustmentSettings.unavailableMessage
        ))
        XCTAssertFalse(AppleHealthAdjustmentSettings.authorizationRequested)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: AppleHealthAdjustmentSettings.adjustmentEnabledKey))
    }

    private func record(empty: Bool, at date: Date) -> String? {
        AppleHealthAdjustmentSettings.recordActiveEnergyRefresh(
            activeEnergyKcal: empty ? 0 : 100,
            recentActiveEnergySamples: [],
            now: date
        )
    }
}

@MainActor
@Suite("HealthKit service error copy")
struct HealthKitServiceErrorCoverageTests {
    @Test(
        "Each service error explains itself to the user",
        arguments: [
            (HealthKitServiceError.unavailable, "Apple Health is not available on this device."),
            (
                HealthKitServiceError.authorizationFailed,
                "Apple Health did not share Active Energy with Caloryn. Allow Active Energy in the Health app, then try again."
            ),
            (
                HealthKitServiceError.requestTimedOut,
                "Apple Health did not respond. Continue with Activity Level Estimate, then try again from Settings."
            ),
        ]
    )
    func errorDescription(error: HealthKitServiceError, expected: String) {
        #expect(error.errorDescription == expected)
        #expect((error as Error).localizedDescription == expected)
    }

    @Test("The unavailable error matches the settings copy for the same situation")
    func unavailableMatchesSettingsCopy() {
        #expect(HealthKitServiceError.unavailable.errorDescription == AppleHealthAdjustmentSettings.unavailableMessage)
    }
}

@MainActor
@Suite("Current activity calorie budget across time zones")
struct CurrentActivityCalorieBudgetCoverageTests {
    private func makeProfile() -> UserProfile {
        UserProfile(
            age: 30,
            sex: .male,
            heightCm: 180,
            weightKg: 75,
            activityLevel: .moderatelyActive,
            dailyCalorieTarget: 1_700,
            manualOverride: false,
            calorieDeficit: 0,
            energyCalculationMode: .dynamicHealth
        )
    }

    @Test("The day and history window come from the injected calendar, not the device's")
    func usesInjectedCalendarForDayBoundaries() async {
        let tokyo = coverageCalendar("Asia/Tokyo")
        let now = coverageDate(tokyo, 2026, 7, 25, 1)
        let expectedDayStart = coverageDate(tokyo, 2026, 7, 25, 0)
        let reader = CoverageActiveEnergyReader()
        reader.activeEnergy = { _ in 420 }

        let budget = await CurrentActivityCalorieBudget.load(
            profile: makeProfile(),
            consumed: 800,
            now: now,
            calendar: tokyo,
            reader: reader
        )

        #expect(budget?.date == expectedDayStart)
        #expect(budget?.consumed == 800)
        #expect(budget?.activeEnergyKcal == 420)
        #expect(reader.activeEnergyRequests.map(\.date) == [expectedDayStart])
        #expect(reader.activeEnergyRequests.first?.calendar.timeZone.identifier == "Asia/Tokyo")
        #expect(reader.historyRequests.first?.end == expectedDayStart)
        #expect(reader.historyRequests.first?.start == coverageDate(tokyo, 2026, 7, 4, 0))
        #expect(reader.historyRequests.first?.calendar.timeZone.identifier == "Asia/Tokyo")
    }

    @Test("The same instant belongs to a different day in a calendar west of UTC")
    func sameInstantDifferentDayWestOfUTC() async {
        let tokyo = coverageCalendar("Asia/Tokyo")
        let honolulu = coverageCalendar("Pacific/Honolulu")
        let now = coverageDate(tokyo, 2026, 7, 25, 1)
        let reader = CoverageActiveEnergyReader()

        let budget = await CurrentActivityCalorieBudget.load(
            profile: makeProfile(),
            consumed: 0,
            now: now,
            calendar: honolulu,
            reader: reader
        )

        #expect(budget?.date == coverageDate(honolulu, 2026, 7, 24, 0))
    }

    @Test("A failed history read makes the whole budget unavailable")
    func historyFailureYieldsNoBudget() async {
        let reader = CoverageActiveEnergyReader()
        reader.activeEnergy = { _ in 500 }
        reader.history = { _, _ in throw CoverageReadError.failed }

        let budget = await CurrentActivityCalorieBudget.load(
            profile: makeProfile(),
            consumed: 0,
            now: coverageDate(coverageCalendar("UTC"), 2026, 7, 25),
            calendar: coverageCalendar("UTC"),
            reader: reader
        )

        #expect(budget == nil)
    }
}
