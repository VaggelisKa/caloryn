import Foundation
@preconcurrency import HealthKit

enum HealthKitServiceError: LocalizedError {
    case unavailable
    case authorizationFailed
    case requestTimedOut

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Apple Health is not available on this device."
        case .authorizationFailed:
            return "Apple Health did not share Active Energy with Caloryn. Allow Active Energy in the Health app, then try again."
        case .requestTimedOut:
            return "Apple Health did not respond. Continue with Activity Level Estimate, then try again from Settings."
        }
    }
}

private struct HealthKitQueryCancellation: @unchecked Sendable {
    private let query: HKQuery

    init(_ query: HKQuery) {
        self.query = query
    }

    @MainActor
    func cancel() {
        HealthKitService.stop(query)
    }
}

private final class HealthKitContinuationGate<Value>: @unchecked Sendable {
    private enum CompletionState {
        case pending
        case finished
        case timedOut
    }

    private let lock = NSLock()
    private var state = CompletionState.pending
    private var timeoutTask: Task<Void, Never>?
    private var cancelOperation: HealthKitQueryCancellation?

    func setTimeoutTask(_ task: Task<Void, Never>) {
        let shouldCancel: Bool

        lock.lock()
        if state == .pending {
            timeoutTask = task
            shouldCancel = false
        } else {
            shouldCancel = true
        }
        lock.unlock()

        if shouldCancel {
            task.cancel()
        }
    }

    func setCancelOperation(_ cancelOperation: HealthKitQueryCancellation) -> HealthKitQueryCancellation? {
        let operationToCancel: HealthKitQueryCancellation?

        lock.lock()
        switch state {
        case .pending:
            self.cancelOperation = cancelOperation
            operationToCancel = nil
        case .finished:
            operationToCancel = nil
        case .timedOut:
            operationToCancel = cancelOperation
        }
        lock.unlock()

        return operationToCancel
    }

    @discardableResult
    func resume(
        _ result: Result<Value, Error>,
        continuation: CheckedContinuation<Value, Error>
    ) -> Bool {
        let taskToCancel: Task<Void, Never>?

        lock.lock()
        guard state == .pending else {
            lock.unlock()
            return false
        }
        state = .finished
        taskToCancel = timeoutTask
        timeoutTask = nil
        cancelOperation = nil
        lock.unlock()

        continuation.resume(with: result)
        taskToCancel?.cancel()
        return true
    }

    func timeOut(continuation: CheckedContinuation<Value, Error>) -> HealthKitQueryCancellation? {
        let operationToCancel: HealthKitQueryCancellation?

        lock.lock()
        guard state == .pending else {
            lock.unlock()
            return nil
        }
        state = .timedOut
        operationToCancel = cancelOperation
        timeoutTask = nil
        cancelOperation = nil
        lock.unlock()

        continuation.resume(throwing: HealthKitServiceError.requestTimedOut)
        return operationToCancel
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

        // HealthKit does not report the read-grant decision here. A completed
        // request lets the app attempt reads; the activity queries below own
        // the distinction between zero data and read failures.
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
            return HealthKitQueryCancellation(query)
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
            return HealthKitQueryCancellation(query)
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
        operation: (@escaping (Result<Value, Error>) -> Void) -> HealthKitQueryCancellation
    ) async throws -> Value {
        try await withCheckedThrowingContinuation { continuation in
            let gate = HealthKitContinuationGate<Value>()
            let timeoutTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: healthKitTimeoutNanoseconds)
                guard !Task.isCancelled else { return }

                let cancelOperation = gate.timeOut(continuation: continuation)
                cancelOperation?.cancel()
            }

            gate.setTimeoutTask(timeoutTask)

            let cancelOperation = operation { result in
                gate.resume(result, continuation: continuation)
            }

            let alreadyTimedOutCancellation = gate.setCancelOperation(cancelOperation)
            alreadyTimedOutCancellation?.cancel()
        }
    }
}
