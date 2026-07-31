import XCTest
@testable import Caloryn

@MainActor
final class ActiveEnergyDayTrackerTests: XCTestCase {
    override func setUp() {
        super.setUp()
        clearAppleHealthDefaults()
    }

    override func tearDown() {
        clearAppleHealthDefaults()
        super.tearDown()
    }

    func testEnabledConfigurationReadsActiveEnergyForTheSelectedDay() async {
        var readDates: [Date] = []
        let selectedDate = Date(timeIntervalSinceReferenceDate: 100_000)
        let tracker = ActiveEnergyDayTracker(reader: StubActiveEnergyReader(
            isHealthAvailable: { true },
            activeEnergyBurnedKcal: { date in
                readDates.append(date)
                return 240
            },
            dailyActiveEnergyBurnedKcal: { _, _ in [] },
            observeActiveEnergyChanges: { _ in nil }
        ))

        await tracker.configure(date: selectedDate, isEnabled: true)

        XCTAssertEqual(tracker.activeEnergyKcal, 240, accuracy: 0.001)
        XCTAssertFalse(tracker.isLoading)
        XCTAssertNil(tracker.message)
        XCTAssertEqual(readDates, [selectedDate.startOfDay])
    }

    func testZeroActiveEnergyKeepsAdjustmentEnabled() async {
        AppleHealthAdjustmentSettings.persist(
            isEnabled: true,
            authorizationRequested: true,
            message: nil
        )
        let tracker = ActiveEnergyDayTracker(reader: StubActiveEnergyReader(
            isHealthAvailable: { true },
            activeEnergyBurnedKcal: { _ in 0 },
            dailyActiveEnergyBurnedKcal: { _, _ in [] },
            observeActiveEnergyChanges: { _ in nil }
        ))

        await tracker.configure(date: .now, isEnabled: true)

        XCTAssertEqual(tracker.activeEnergyKcal, 0, accuracy: 0.001)
        XCTAssertFalse(tracker.isLoading)
        XCTAssertNil(tracker.message)
        XCTAssertNil(tracker.emptyActivityNotice)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: AppleHealthAdjustmentSettings.adjustmentEnabledKey))
        XCTAssertTrue(UserDefaults.standard.bool(forKey: AppleHealthAdjustmentSettings.authorizationRequestedKey))
    }

    func testRepeatedZeroActiveEnergyShowsAccessHintWithoutDisablingAdjustment() async {
        AppleHealthAdjustmentSettings.persist(
            isEnabled: true,
            authorizationRequested: true,
            message: nil
        )

        for _ in 0..<2 {
            let tracker = ActiveEnergyDayTracker(reader: emptyActivityReader)
            await tracker.configure(date: .now, isEnabled: true)
            XCTAssertNil(tracker.emptyActivityNotice)
        }

        let tracker = ActiveEnergyDayTracker(reader: emptyActivityReader)
        await tracker.configure(date: .now, isEnabled: true)

        XCTAssertEqual(tracker.emptyActivityNotice, AppleHealthAdjustmentSettings.emptyActivityAccessMessage)
        XCTAssertNil(tracker.message)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: AppleHealthAdjustmentSettings.adjustmentEnabledKey))
        XCTAssertTrue(UserDefaults.standard.bool(forKey: AppleHealthAdjustmentSettings.authorizationRequestedKey))
    }

    func testEnabledConfigurationReadsRecentActivityHistoryBeforeTheSelectedDay() async {
        var requestedRanges: [(start: Date, end: Date)] = []
        let selectedDate = makeTestDate(year: 2026, month: 2, day: 14, hour: 8)
        let historySampleDate = makeTestDate(year: 2026, month: 2, day: 13)
        let samples = [
            DailyActiveEnergySample(date: historySampleDate, activeEnergyKcal: 260)
        ]
        let tracker = ActiveEnergyDayTracker(reader: StubActiveEnergyReader(
            isHealthAvailable: { true },
            activeEnergyBurnedKcal: { _ in 240 },
            dailyActiveEnergyBurnedKcal: { start, end in
                requestedRanges.append((start, end))
                return samples
            },
            observeActiveEnergyChanges: { _ in nil }
        ))

        await tracker.configure(date: selectedDate, isEnabled: true)

        XCTAssertEqual(tracker.recentActiveEnergySamples, samples)
        XCTAssertEqual(requestedRanges.count, 1)
        XCTAssertEqual(requestedRanges.first?.end, selectedDate.startOfDay)
        XCTAssertEqual(
            requestedRanges.first?.start,
            Calendar.current.date(
                byAdding: .day,
                value: -ActivityCalorieBudget.historyLookbackDays,
                to: selectedDate.startOfDay
            )
        )
    }

    func testDisabledConfigurationClearsEnergyAndStopsObservation() async {
        var stopCount = 0
        let tracker = ActiveEnergyDayTracker(reader: StubActiveEnergyReader(
            isHealthAvailable: { true },
            activeEnergyBurnedKcal: { _ in 120 },
            dailyActiveEnergyBurnedKcal: { _, _ in [] },
            observeActiveEnergyChanges: { _ in
                ActiveEnergyObservation {
                    stopCount += 1
                }
            }
        ))

        await tracker.configure(date: .now, isEnabled: true)
        XCTAssertEqual(tracker.activeEnergyKcal, 120, accuracy: 0.001)

        await tracker.configure(date: .now, isEnabled: false)

        XCTAssertEqual(tracker.activeEnergyKcal, 0, accuracy: 0.001)
        XCTAssertFalse(tracker.isLoading)
        XCTAssertNil(tracker.message)
        XCTAssertEqual(stopCount, 1)
    }

    func testFailedActiveEnergyReadDisablesTheAdjustmentAndShowsTheErrorMessage() async {
        AppleHealthAdjustmentSettings.persist(
            isEnabled: true,
            authorizationRequested: true,
            message: nil
        )
        let tracker = ActiveEnergyDayTracker(reader: StubActiveEnergyReader(
            isHealthAvailable: { true },
            activeEnergyBurnedKcal: { _ in throw TrackerError.denied },
            dailyActiveEnergyBurnedKcal: { _, _ in [] },
            observeActiveEnergyChanges: { _ in nil }
        ))

        await tracker.configure(date: .now, isEnabled: true)

        XCTAssertEqual(tracker.activeEnergyKcal, 0, accuracy: 0.001)
        XCTAssertFalse(tracker.isLoading)
        XCTAssertEqual(tracker.message, "Active energy access was not allowed.")
        XCTAssertFalse(UserDefaults.standard.bool(forKey: AppleHealthAdjustmentSettings.adjustmentEnabledKey))
        XCTAssertFalse(UserDefaults.standard.bool(forKey: AppleHealthAdjustmentSettings.authorizationRequestedKey))
    }

    func testUnavailableHealthDisablesTheAdjustmentWithoutStartingObservation() async {
        AppleHealthAdjustmentSettings.persist(
            isEnabled: true,
            authorizationRequested: true,
            message: nil
        )
        var didStartObservation = false
        let tracker = ActiveEnergyDayTracker(reader: StubActiveEnergyReader(
            isHealthAvailable: { false },
            activeEnergyBurnedKcal: { _ in
                XCTFail("Active energy should not be read when Health data is unavailable.")
                return 0
            },
            dailyActiveEnergyBurnedKcal: { _, _ in
                XCTFail("Active energy history should not be read when Health data is unavailable.")
                return []
            },
            observeActiveEnergyChanges: { _ in
                didStartObservation = true
                return nil
            }
        ))

        await tracker.configure(date: .now, isEnabled: true)

        XCTAssertEqual(tracker.activeEnergyKcal, 0, accuracy: 0.001)
        XCTAssertFalse(tracker.isLoading)
        XCTAssertEqual(tracker.message, AppleHealthAdjustmentSettings.unavailableMessage)
        XCTAssertFalse(didStartObservation)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: AppleHealthAdjustmentSettings.adjustmentEnabledKey))
        XCTAssertFalse(UserDefaults.standard.bool(forKey: AppleHealthAdjustmentSettings.authorizationRequestedKey))
    }

    func testReconfiguringSameEnabledDayDoesNotReadActiveEnergyAgain() async {
        var readCount = 0
        let selectedDate = makeTestDate(year: 2026, month: 2, day: 14, hour: 8)
        let sameDayLater = makeTestDate(year: 2026, month: 2, day: 14, hour: 18)
        let tracker = ActiveEnergyDayTracker(reader: StubActiveEnergyReader(
            isHealthAvailable: { true },
            activeEnergyBurnedKcal: { _ in
                readCount += 1
                return Double(readCount * 100)
            },
            dailyActiveEnergyBurnedKcal: { _, _ in [] },
            observeActiveEnergyChanges: { _ in
                ActiveEnergyObservation {}
            }
        ))

        await tracker.configure(date: selectedDate, isEnabled: true)
        await tracker.configure(date: sameDayLater, isEnabled: true)

        XCTAssertEqual(readCount, 1)
        XCTAssertEqual(tracker.activeEnergyKcal, 100, accuracy: 0.001)
    }

    func testObserverCallbackRefreshesTheActiveEnergyValue() async {
        var onActiveEnergyChange: (@MainActor () -> Void)?
        var nextActiveEnergy = 100.0
        let tracker = ActiveEnergyDayTracker(reader: StubActiveEnergyReader(
            isHealthAvailable: { true },
            activeEnergyBurnedKcal: { _ in nextActiveEnergy },
            dailyActiveEnergyBurnedKcal: { _, _ in [] },
            observeActiveEnergyChanges: { onChange in
                onActiveEnergyChange = onChange
                return nil
            }
        ))

        await tracker.configure(date: .now, isEnabled: true)
        XCTAssertEqual(tracker.activeEnergyKcal, 100, accuracy: 0.001)

        nextActiveEnergy = 260
        onActiveEnergyChange?()
        await waitUntilActiveEnergy(on: tracker, equals: 260)
    }

    func testOlderRefreshResultCannotOverwriteNewerRefresh() async {
        let firstReadStarted = expectation(description: "First active energy read started")
        let firstDate = makeTestDate(year: 2026, month: 2, day: 14)
        let secondDate = makeTestDate(year: 2026, month: 2, day: 15)
        let staleSamples = [
            DailyActiveEnergySample(date: makeTestDate(year: 2026, month: 2, day: 13), activeEnergyKcal: 100)
        ]
        let latestSamples = [
            DailyActiveEnergySample(date: makeTestDate(year: 2026, month: 2, day: 14), activeEnergyKcal: 320)
        ]
        var activeReadCount = 0
        var historyReadCount = 0
        let tracker = ActiveEnergyDayTracker(reader: StubActiveEnergyReader(
            isHealthAvailable: { true },
            activeEnergyBurnedKcal: { _ in
                activeReadCount += 1
                if activeReadCount == 1 {
                    firstReadStarted.fulfill()
                    try await Task.sleep(nanoseconds: 120_000_000)
                    return 100
                }

                return 320
            },
            dailyActiveEnergyBurnedKcal: { _, _ in
                historyReadCount += 1
                if historyReadCount == 1 {
                    try await Task.sleep(nanoseconds: 120_000_000)
                    return staleSamples
                }

                return latestSamples
            },
            observeActiveEnergyChanges: { _ in nil }
        ))

        let staleRefresh = Task {
            await tracker.configure(date: firstDate, isEnabled: true)
        }
        await fulfillment(of: [firstReadStarted], timeout: 1)
        let latestRefresh = Task {
            await tracker.configure(date: secondDate, isEnabled: true)
        }

        await latestRefresh.value
        await staleRefresh.value

        XCTAssertEqual(tracker.activeEnergyKcal, 320, accuracy: 0.001)
        XCTAssertEqual(tracker.recentActiveEnergySamples, latestSamples)
        XCTAssertFalse(tracker.isLoading)
        XCTAssertNil(tracker.message)
    }

    func testOlderRefreshFailureCannotDisableNewerSuccessfulRefresh() async {
        AppleHealthAdjustmentSettings.persist(
            isEnabled: true,
            authorizationRequested: true,
            message: nil
        )
        let firstReadStarted = expectation(description: "First active energy read started")
        let firstDate = makeTestDate(year: 2026, month: 2, day: 14)
        let secondDate = makeTestDate(year: 2026, month: 2, day: 15)
        let latestSamples = [
            DailyActiveEnergySample(date: makeTestDate(year: 2026, month: 2, day: 14), activeEnergyKcal: 260)
        ]
        var activeReadCount = 0
        var historyReadCount = 0
        let tracker = ActiveEnergyDayTracker(reader: StubActiveEnergyReader(
            isHealthAvailable: { true },
            activeEnergyBurnedKcal: { _ in
                activeReadCount += 1
                if activeReadCount == 1 {
                    firstReadStarted.fulfill()
                    try await Task.sleep(nanoseconds: 120_000_000)
                    throw TrackerError.denied
                }

                return 260
            },
            dailyActiveEnergyBurnedKcal: { _, _ in
                historyReadCount += 1
                if historyReadCount == 1 {
                    try await Task.sleep(nanoseconds: 120_000_000)
                    return []
                }

                return latestSamples
            },
            observeActiveEnergyChanges: { _ in nil }
        ))

        let staleRefresh = Task {
            await tracker.configure(date: firstDate, isEnabled: true)
        }
        await fulfillment(of: [firstReadStarted], timeout: 1)
        let latestRefresh = Task {
            await tracker.configure(date: secondDate, isEnabled: true)
        }

        await latestRefresh.value
        await staleRefresh.value

        XCTAssertEqual(tracker.activeEnergyKcal, 260, accuracy: 0.001)
        XCTAssertEqual(tracker.recentActiveEnergySamples, latestSamples)
        XCTAssertFalse(tracker.isLoading)
        XCTAssertNil(tracker.message)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: AppleHealthAdjustmentSettings.adjustmentEnabledKey))
        XCTAssertTrue(UserDefaults.standard.bool(forKey: AppleHealthAdjustmentSettings.authorizationRequestedKey))
    }

    private func waitUntilActiveEnergy(
        on tracker: ActiveEnergyDayTracker,
        equals expectedValue: Double,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        for _ in 0..<20 {
            if tracker.activeEnergyKcal == expectedValue {
                return
            }

            await Task.yield()
            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTFail(
            "Expected active energy to become \(expectedValue), got \(tracker.activeEnergyKcal)",
            file: file,
            line: line
        )
    }

    private func clearAppleHealthDefaults() {
        UserDefaults.standard.removeObject(forKey: AppleHealthAdjustmentSettings.adjustmentEnabledKey)
        UserDefaults.standard.removeObject(forKey: AppleHealthAdjustmentSettings.authorizationRequestedKey)
        AppleHealthAdjustmentSettings.clearEmptyActiveEnergyTracking()
    }

    private var emptyActivityReader: StubActiveEnergyReader {
        StubActiveEnergyReader(
            isHealthAvailable: { true },
            activeEnergyBurnedKcal: { _ in 0 },
            dailyActiveEnergyBurnedKcal: { _, _ in [] },
            observeActiveEnergyChanges: { _ in nil }
        )
    }
}

private enum TrackerError: LocalizedError {
    case denied

    var errorDescription: String? {
        "Active energy access was not allowed."
    }
}
