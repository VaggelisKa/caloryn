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
        let tracker = ActiveEnergyDayTracker(dataSource: ActiveEnergyDataSource(
            isHealthAvailable: { true },
            activeEnergyBurnedKcal: { date in
                readDates.append(date)
                return 240
            },
            observeActiveEnergyChanges: { _ in nil }
        ))

        await tracker.configure(date: selectedDate, isEnabled: true)

        XCTAssertEqual(tracker.activeEnergyKcal, 240, accuracy: 0.001)
        XCTAssertFalse(tracker.isLoading)
        XCTAssertNil(tracker.message)
        XCTAssertEqual(readDates, [selectedDate.startOfDay])
    }

    func testDisabledConfigurationClearsEnergyAndStopsObservation() async {
        var stopCount = 0
        let tracker = ActiveEnergyDayTracker(dataSource: ActiveEnergyDataSource(
            isHealthAvailable: { true },
            activeEnergyBurnedKcal: { _ in 120 },
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
        let tracker = ActiveEnergyDayTracker(dataSource: ActiveEnergyDataSource(
            isHealthAvailable: { true },
            activeEnergyBurnedKcal: { _ in throw TrackerError.denied },
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
        let tracker = ActiveEnergyDayTracker(dataSource: ActiveEnergyDataSource(
            isHealthAvailable: { false },
            activeEnergyBurnedKcal: { _ in
                XCTFail("Active energy should not be read when Health data is unavailable.")
                return 0
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
        let tracker = ActiveEnergyDayTracker(dataSource: ActiveEnergyDataSource(
            isHealthAvailable: { true },
            activeEnergyBurnedKcal: { _ in
                readCount += 1
                return Double(readCount * 100)
            },
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
        let tracker = ActiveEnergyDayTracker(dataSource: ActiveEnergyDataSource(
            isHealthAvailable: { true },
            activeEnergyBurnedKcal: { _ in nextActiveEnergy },
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
    }
}

private enum TrackerError: LocalizedError {
    case denied

    var errorDescription: String? {
        "Active energy access was not allowed."
    }
}
