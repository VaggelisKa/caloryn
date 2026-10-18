import Foundation

struct BarcodeLookupFlow: Equatable {
    enum RetryAction: Equatable {
        case repeatLookup
        case rescan
    }

    enum FailureFeedback: Equatable {
        case warning
        case error
    }

    private(set) var isLookingUp = false

    private(set) var error: FoodLookupError?

    private(set) var pendingBarcode: String?

    private(set) var lastScannedBarcode: String?

    private(set) var manualRecoveryBarcode: String?

    init(error: FoodLookupError? = nil, lastScannedBarcode: String? = nil) {
        self.error = error
        self.lastScannedBarcode = lastScannedBarcode
    }

    var hasError: Bool { error != nil }

    var offersManualCreation: Bool { error == .notFound }

    var errorDismissesOnNameSearch: Bool {
        error?.dismissesWhenNameSearchBegins == true
    }

    mutating func scanned(_ code: String) {
        guard let normalizedBarcode = BarcodeIdentity.normalized(code) else {
            isLookingUp = false
            pendingBarcode = nil
            error = .invalidRequest
            lastScannedBarcode = nil
            return
        }
        lastScannedBarcode = normalizedBarcode
        beginLookup(normalizedBarcode)
    }

    mutating func lookupSucceeded() {
        isLookingUp = false
        pendingBarcode = nil
        lastScannedBarcode = nil
    }

    @discardableResult
    mutating func lookupFailed(_ error: FoodLookupError) -> FailureFeedback? {
        guard error != .cancelled else { return nil }
        isLookingUp = false
        pendingBarcode = nil
        self.error = error
        return error == .notFound ? .warning : .error
    }

    mutating func retryRequested() -> RetryAction {
        error = nil
        guard let lastScannedBarcode else {
            return .rescan
        }
        beginLookup(lastScannedBarcode)
        return .repeatLookup
    }

    mutating func manualRecoveryOpened() -> Bool {
        guard let normalizedBarcode = BarcodeIdentity.normalized(lastScannedBarcode) else {
            return false
        }
        manualRecoveryBarcode = normalizedBarcode
        error = nil
        return true
    }

    mutating func manualEntryOpened() {
        manualRecoveryBarcode = nil
    }

    mutating func manualEntrySaved() {
        clearRecoveryContext()
    }

    mutating func scannerOpened() {
        clearRecoveryContext()
    }

    mutating func nameSearchStarted() {
        clearRecoveryContext()
    }

    private mutating func beginLookup(_ barcode: String) {
        error = nil
        isLookingUp = true
        pendingBarcode = barcode
    }

    private mutating func clearRecoveryContext() {
        error = nil
        lastScannedBarcode = nil
        manualRecoveryBarcode = nil
    }
}
