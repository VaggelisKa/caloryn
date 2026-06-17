import Foundation
@preconcurrency import HealthKit

enum HealthKitServiceError: LocalizedError {
    case unavailable
    case authorizationFailed
    case activeEnergyReadDenied
    case requestTimedOut

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Apple Health is not available on this device."
        case .authorizationFailed, .activeEnergyReadDenied:
            return "Apple Health permission wasn't given. Allow Active Energy for Caloryn in the Health app, then try again."
        case .requestTimedOut:
            return "Apple Health did not respond. Continue with Activity Level Estimate, then try again from Settings."
        }
    }
}

private final class HealthKitContinuationGate<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var didResume = false

    @discardableResult
    func resume(
        _ result: Result<Value, Error>,
        continuation: CheckedContinuation<Value, Error>
    ) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard !didResume else { return false }
        didResume = true
        continuation.resume(with: result)
        return true
    }
}

@MainActor
enum HealthKitService {
    private static let store = HKHealthStore()
    private static let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
    private static let healthKitTimeoutNanoseconds: UInt64 = 10_000_000_000

    nonisolated static var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    static func requestActiveEnergyAuthorization() async throws {
        guard isHealthDataAvailable else {
            throw HealthKitServiceError.unavailable
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.requestAuthorization(toShare: [], read: [activeEnergyType]) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthKitServiceError.authorizationFailed)
                }
            }
        }

        do {
            _ = try await activeEnergyBurnedKcal(for: Date())
        } catch HealthKitServiceError.requestTimedOut {
            throw HealthKitServiceError.requestTimedOut
        } catch {
            throw HealthKitServiceError.activeEnergyReadDenied
        }
    }

    static func activeEnergyBurnedKcal(for date: Date, calendar: Calendar = .current) async throws -> Double {
        guard isHealthDataAvailable else {
            throw HealthKitServiceError.unavailable
        }

        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? date
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [.strictStartDate, .strictEndDate])

        return try await withHealthKitTimeout { finish in
            let query = HKStatisticsQuery(
                quantityType: activeEnergyType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error {
                    if isNoDataError(error) {
                        finish(.success(0))
                        return
                    }

                    finish(.failure(error))
                    return
                }

                let quantity = statistics?.sumQuantity()
                let kcal = quantity?.doubleValue(for: .kilocalorie()) ?? 0
                finish(.success(kcal))
            }

            store.execute(query)
        }
    }

    static func dailyActiveEnergyBurnedKcal(
        from startDate: Date,
        to endDate: Date,
        calendar: Calendar = .current
    ) async throws -> [DailyActiveEnergySample] {
        guard isHealthDataAvailable else {
            throw HealthKitServiceError.unavailable
        }

        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        guard start < end else { return [] }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [.strictStartDate, .strictEndDate])
        var interval = DateComponents()
        interval.day = 1

        return try await withHealthKitTimeout { finish in
            let query = HKStatisticsCollectionQuery(
                quantityType: activeEnergyType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: start,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, collection, error in
                if let error {
                    if isNoDataError(error) {
                        finish(.success([]))
                        return
                    }

                    finish(.failure(error))
                    return
                }

                guard let collection else {
                    finish(.success([]))
                    return
                }

                var samples: [DailyActiveEnergySample] = []
                collection.enumerateStatistics(from: start, to: end) { statistics, _ in
                    let kcal = statistics.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                    samples.append(DailyActiveEnergySample(
                        date: calendar.startOfDay(for: statistics.startDate),
                        activeEnergyKcal: kcal
                    ))
                }

                finish(.success(samples))
            }

            store.execute(query)
        }
    }

    static func observeActiveEnergyChanges(onChange: @escaping @MainActor () -> Void) -> HKObserverQuery? {
        guard isHealthDataAvailable else { return nil }

        let query = HKObserverQuery(sampleType: activeEnergyType, predicate: nil) { _, completionHandler, error in
            if error == nil {
                Task { @MainActor in
                    onChange()
                }
            }

            completionHandler()
        }

        store.execute(query)
        return query
    }

    static func stop(_ query: HKQuery?) {
        guard let query else { return }
        store.stop(query)
    }

    nonisolated private static func isNoDataError(_ error: Error) -> Bool {
        if let hkError = error as? HKError {
            return hkError.code == .errorNoData
        }

        let nsError = error as NSError
        return nsError.domain == HKErrorDomain && nsError.code == HKError.Code.errorNoData.rawValue
    }

    private static func withHealthKitTimeout<Value>(
        operation: (@escaping (Result<Value, Error>) -> Void) -> Void
    ) async throws -> Value {
        try await withCheckedThrowingContinuation { continuation in
            let gate = HealthKitContinuationGate<Value>()

            operation { result in
                gate.resume(result, continuation: continuation)
            }

            Task {
                try? await Task.sleep(nanoseconds: healthKitTimeoutNanoseconds)
                gate.resume(.failure(HealthKitServiceError.requestTimedOut), continuation: continuation)
            }
        }
    }
}
