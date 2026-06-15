import Foundation
@preconcurrency import HealthKit

enum HealthKitServiceError: LocalizedError {
    case unavailable
    case authorizationFailed
    case activeEnergyReadDenied

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Apple Health is not available on this device."
        case .authorizationFailed, .activeEnergyReadDenied:
            return "Apple Health permission wasn't given. Allow Active Energy for Caloryn in the Health app, then try again."
        }
    }
}

@MainActor
enum HealthKitService {
    private static let store = HKHealthStore()
    private static let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!

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

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Double, Error>) in
            let query = HKStatisticsQuery(
                quantityType: activeEnergyType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error {
                    if isNoDataError(error) {
                        continuation.resume(returning: 0)
                        return
                    }

                    continuation.resume(throwing: error)
                    return
                }

                let quantity = statistics?.sumQuantity()
                let kcal = quantity?.doubleValue(for: .kilocalorie()) ?? 0
                continuation.resume(returning: kcal)
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
}
