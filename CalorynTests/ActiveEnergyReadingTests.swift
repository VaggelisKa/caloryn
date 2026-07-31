import XCTest
@testable import Caloryn

/// Stands in for `HealthKitService`. Nonisolated so `isHealthDataAvailable`
/// can be read from the same synchronous contexts the real reader serves.
nonisolated final class StubActiveEnergyReader: ActiveEnergyReading, @unchecked Sendable {
    private let isHealthAvailable: @Sendable () -> Bool
    private let readActiveEnergy: @MainActor (Date) async throws -> Double
    private let readDailyActiveEnergy: @MainActor (Date, Date) async throws -> [DailyActiveEnergySample]
    private let startObserving: @MainActor (@escaping @MainActor () -> Void) -> ActiveEnergyObservation?

    var authorizationError: Error?
    private(set) var authorizationRequestCount = 0

    init(
        isHealthAvailable: @escaping @Sendable () -> Bool = { true },
        activeEnergyBurnedKcal: @escaping @MainActor (Date) async throws -> Double = { _ in 0 },
        dailyActiveEnergyBurnedKcal: @escaping @MainActor (Date, Date) async throws -> [DailyActiveEnergySample] = { _, _ in [] },
        observeActiveEnergyChanges: @escaping @MainActor (@escaping @MainActor () -> Void) -> ActiveEnergyObservation? = { _ in nil },
        authorizationError: Error? = nil
    ) {
        self.isHealthAvailable = isHealthAvailable
        self.readActiveEnergy = activeEnergyBurnedKcal
        self.readDailyActiveEnergy = dailyActiveEnergyBurnedKcal
        self.startObserving = observeActiveEnergyChanges
        self.authorizationError = authorizationError
    }

    var isHealthDataAvailable: Bool {
        isHealthAvailable()
    }

    @MainActor
    func requestActiveEnergyAuthorization() async throws {
        authorizationRequestCount += 1
        if let authorizationError {
            throw authorizationError
        }
    }

    @MainActor
    func activeEnergyBurnedKcal(for date: Date, calendar: Calendar) async throws -> Double {
        try await readActiveEnergy(date)
    }

    @MainActor
    func dailyActiveEnergyBurnedKcal(
        from startDate: Date,
        to endDate: Date,
        calendar: Calendar
    ) async throws -> [DailyActiveEnergySample] {
        try await readDailyActiveEnergy(startDate, endDate)
    }

    @MainActor
    func observeActiveEnergyChanges(onChange: @escaping @MainActor () -> Void) -> ActiveEnergyObservation? {
        startObserving(onChange)
    }
}

/// Drives the Apple Health callers through the reader seam: the paths that
/// previously needed a device with Health data, an entitlement and a tap on a
/// permission sheet.
@MainActor
final class ActiveEnergyReadingTests: XCTestCase {
    override func setUp() {
        super.setUp()
        clearAppleHealthDefaults()
    }

    override func tearDown() {
        clearAppleHealthDefaults()
        super.tearDown()
    }

    // MARK: - Enabling the adjustment

    func testEnablingAsksForAuthorizationOnceAndTurnsTheAdjustmentOn() async {
        let reader = StubActiveEnergyReader()

        let update = await AppleHealthAdjustmentSettings.enable(reader: reader)

        XCTAssertEqual(reader.authorizationRequestCount, 1)
        XCTAssertEqual(
            update,
            AppleHealthAdjustmentUpdate(isEnabled: true, authorizationRequested: true, message: nil)
        )
        XCTAssertTrue(UserDefaults.standard.bool(forKey: AppleHealthAdjustmentSettings.adjustmentEnabledKey))
    }

    func testEnablingWithoutHealthDataNeverAsksForAuthorization() async {
        let reader = StubActiveEnergyReader(isHealthAvailable: { false })

        let update = await AppleHealthAdjustmentSettings.enable(reader: reader)

        XCTAssertEqual(reader.authorizationRequestCount, 0)
        XCTAssertEqual(
            update,
            AppleHealthAdjustmentUpdate(
                isEnabled: false,
                authorizationRequested: false,
                message: AppleHealthAdjustmentSettings.unavailableMessage
            )
        )
        XCTAssertFalse(UserDefaults.standard.bool(forKey: AppleHealthAdjustmentSettings.adjustmentEnabledKey))
    }

    func testRefusedAuthorizationReportsTheServiceMessageAndRemembersTheRequest() async {
        let reader = StubActiveEnergyReader(authorizationError: HealthKitServiceError.authorizationFailed)

        let update = await AppleHealthAdjustmentSettings.enable(reader: reader)

        XCTAssertFalse(update.isEnabled)
        XCTAssertTrue(update.authorizationRequested)
        XCTAssertEqual(update.message, HealthKitServiceError.authorizationFailed.localizedDescription)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: AppleHealthAdjustmentSettings.authorizationRequestedKey))
    }

    func testEnablingClearsAnEarlierEmptyActivityStreak() async {
        // Two empty refreshes short of the warning; enabling must reset the
        // streak so the hint does not fire on the first refresh afterwards.
        for _ in 0..<2 {
            _ = AppleHealthAdjustmentSettings.recordActiveEnergyRefresh(
                activeEnergyKcal: 0,
                recentActiveEnergySamples: []
            )
        }

        _ = await AppleHealthAdjustmentSettings.enable(reader: StubActiveEnergyReader())

        XCTAssertNil(AppleHealthAdjustmentSettings.recordActiveEnergyRefresh(
            activeEnergyKcal: 0,
            recentActiveEnergySamples: []
        ))
    }

    // MARK: - Reading a day's budget

    func testBudgetIsUnavailableWithoutHealthData() async {
        let reader = StubActiveEnergyReader(
            isHealthAvailable: { false },
            activeEnergyBurnedKcal: { _ in
                XCTFail("Active energy must not be read when Health data is unavailable.")
                return 0
            }
        )

        let budget = await CurrentActivityCalorieBudget.load(
            profile: makeDynamicHealthProfile(),
            consumed: 1_200,
            now: makeTestDate(year: 2026, month: 7, day: 25),
            calendar: .current,
            reader: reader
        )

        XCTAssertNil(budget)
    }

    func testBudgetIsUnavailableWhenTheReadFails() async {
        let reader = StubActiveEnergyReader(
            activeEnergyBurnedKcal: { _ in throw HealthKitServiceError.requestTimedOut }
        )

        let budget = await CurrentActivityCalorieBudget.load(
            profile: makeDynamicHealthProfile(),
            consumed: 1_200,
            now: makeTestDate(year: 2026, month: 7, day: 25),
            calendar: .current,
            reader: reader
        )

        XCTAssertNil(budget)
    }

    func testBudgetReadsTheHistoryWindowEndingAtTheStartOfToday() async {
        let now = makeTestDate(year: 2026, month: 7, day: 25, hour: 14)
        var requestedRange: (start: Date, end: Date)?
        let reader = StubActiveEnergyReader(
            activeEnergyBurnedKcal: { _ in 500 },
            dailyActiveEnergyBurnedKcal: { start, end in
                requestedRange = (start, end)
                return []
            }
        )

        let budget = await CurrentActivityCalorieBudget.load(
            profile: makeDynamicHealthProfile(),
            consumed: 1_200,
            now: now,
            calendar: .current,
            reader: reader
        )

        XCTAssertEqual(budget?.activeEnergyKcal, 500)
        XCTAssertEqual(requestedRange?.end, now.startOfDay)
        XCTAssertEqual(
            requestedRange?.start,
            Calendar.current.date(
                byAdding: .day,
                value: -ActivityCalorieBudget.historyLookbackDays,
                to: now.startOfDay
            )
        )
    }

    // MARK: - Tracking a day

    func testTimedOutReadSurfacesTheServiceMessageAndTurnsTheAdjustmentOff() async {
        AppleHealthAdjustmentSettings.persist(
            isEnabled: true,
            authorizationRequested: true,
            message: nil
        )
        let tracker = ActiveEnergyDayTracker(
            reader: StubActiveEnergyReader(
                activeEnergyBurnedKcal: { _ in throw HealthKitServiceError.requestTimedOut }
            )
        )

        await tracker.configure(date: .now, isEnabled: true)

        XCTAssertEqual(tracker.message, HealthKitServiceError.requestTimedOut.localizedDescription)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: AppleHealthAdjustmentSettings.adjustmentEnabledKey))
    }

    func testTrackerObservesActiveEnergyOnlyOnceAcrossReconfigurations() async {
        var observationCount = 0
        let tracker = ActiveEnergyDayTracker(
            reader: StubActiveEnergyReader(
                activeEnergyBurnedKcal: { _ in 240 },
                observeActiveEnergyChanges: { _ in
                    observationCount += 1
                    return ActiveEnergyObservation {}
                }
            )
        )

        await tracker.configure(date: makeTestDate(year: 2026, month: 2, day: 14), isEnabled: true)
        await tracker.configure(date: makeTestDate(year: 2026, month: 2, day: 15), isEnabled: true)

        XCTAssertEqual(observationCount, 1)
    }

    func testDisablingStopsTheObservationSoReenablingStartsAFreshOne() async {
        var observationCount = 0
        var stopCount = 0
        let tracker = ActiveEnergyDayTracker(
            reader: StubActiveEnergyReader(
                activeEnergyBurnedKcal: { _ in 240 },
                observeActiveEnergyChanges: { _ in
                    observationCount += 1
                    return ActiveEnergyObservation { stopCount += 1 }
                }
            )
        )

        await tracker.configure(date: .now, isEnabled: true)
        await tracker.configure(date: .now, isEnabled: false)
        await tracker.configure(date: .now, isEnabled: true)

        XCTAssertEqual(observationCount, 2)
        XCTAssertEqual(stopCount, 1)
        XCTAssertEqual(tracker.activeEnergyKcal, 240, accuracy: 0.001)
    }

    // MARK: - Helpers

    private func makeDynamicHealthProfile() -> UserProfile {
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

    private func clearAppleHealthDefaults() {
        UserDefaults.standard.removeObject(forKey: AppleHealthAdjustmentSettings.adjustmentEnabledKey)
        UserDefaults.standard.removeObject(forKey: AppleHealthAdjustmentSettings.authorizationRequestedKey)
        AppleHealthAdjustmentSettings.clearEmptyActiveEnergyTracking()
    }
}
