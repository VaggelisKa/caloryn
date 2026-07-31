import Foundation

/// The scan → lookup → recovery sequence, as one value.
///
/// Five separate `@State` flags used to encode this in `FoodSearchView`, and
/// every event had to set the right subset of them by hand: a failure had to
/// clear the spinner but *keep* the scanned barcode, a success had to clear the
/// barcode but a retry had to reuse it, and nothing but an end-to-end journey
/// could tell whether a given combination was reachable at all.
///
/// The two barcodes are not redundant. `pendingBarcode` is the identity of the
/// work the view should be running — the view drives its lookup task off it, so
/// re-scanning the code already in flight deliberately leaves it untouched and
/// does *not* restart the request. `lastScannedBarcode` is the code kept for
/// *recovery*: the failure view shows it, retry re-runs it, and manual creation
/// prefills it. It outlives the request that failed, which is why a failure
/// clears the pending work and keeps the scanned code.
///
/// This type owns which state follows which event. The camera, the haptic, the
/// sheet and the network request stay in the view.
struct BarcodeLookupFlow: Equatable {
    /// What a retry means, which depends on whether a barcode survived.
    enum RetryAction: Equatable {
        /// Run the same barcode again.
        case repeatLookup
        /// Nothing is left to retry, so the user is sent back to the camera.
        case rescan
    }

    /// The tone a failure is announced with. The view maps it to a haptic;
    /// the rule about which failure is merely disappointing and which is wrong
    /// belongs here.
    enum FailureFeedback: Equatable {
        case warning
        case error
    }

    /// Whether a lookup is running and the screen should show its spinner.
    private(set) var isLookingUp = false

    /// The failure on screen, if any.
    private(set) var error: FoodLookupError?

    /// The lookup the view should be running. Identity, not history.
    private(set) var pendingBarcode: String?

    /// The scanned code retained for retry, manual creation and display.
    private(set) var lastScannedBarcode: String?

    /// The barcode to prefill a manual entry with, set only by recovery.
    private(set) var manualRecoveryBarcode: String?

    init(error: FoodLookupError? = nil, lastScannedBarcode: String? = nil) {
        self.error = error
        self.lastScannedBarcode = lastScannedBarcode
    }

    var hasError: Bool { error != nil }

    /// Only an unknown product can be created by hand; every other failure is
    /// about the request, not the product, so inventing one would be wrong.
    var offersManualCreation: Bool { error == .notFound }

    /// Whether typing a name should dismiss the failure currently on screen.
    var errorDismissesOnNameSearch: Bool {
        error?.dismissesWhenNameSearchBegins == true
    }

    /// A barcode arrived from the camera.
    ///
    /// A code that cannot form a product identity is a failure with nothing to
    /// recover from, so no barcode is kept and retry will reopen the camera.
    mutating func scanned(_ code: String) {
        guard let normalizedBarcode = BarcodeIdentity.normalized(code) else {
            isLookingUp = false
            // Cleared like every other failure: leaving it set kept a lookup
            // in flight that would overwrite this failure when it resolved.
            pendingBarcode = nil
            error = .invalidRequest
            lastScannedBarcode = nil
            return
        }
        lastScannedBarcode = normalizedBarcode
        beginLookup(normalizedBarcode)
    }

    /// The lookup resolved to a product — remote or local, the flow is over.
    mutating func lookupSucceeded() {
        isLookingUp = false
        pendingBarcode = nil
        lastScannedBarcode = nil
    }

    /// The lookup failed.
    ///
    /// Returns the tone to announce it with, or `nil` when there is nothing to
    /// announce: a cancelled lookup was superseded by the one that cancelled
    /// it, so it must not clear that lookup's spinner or pending work.
    @discardableResult
    mutating func lookupFailed(_ error: FoodLookupError) -> FailureFeedback? {
        guard error != .cancelled else { return nil }
        isLookingUp = false
        pendingBarcode = nil
        self.error = error
        return error == .notFound ? .warning : .error
    }

    /// The user asked to try again from the failure view.
    mutating func retryRequested() -> RetryAction {
        error = nil
        guard let lastScannedBarcode else {
            return .rescan
        }
        beginLookup(lastScannedBarcode)
        return .repeatLookup
    }

    /// The user asked to create the scanned product by hand.
    ///
    /// Returns whether there is a barcode to create it against; without one
    /// there is nothing to prefill and the failure stays on screen.
    mutating func manualRecoveryOpened() -> Bool {
        guard let normalizedBarcode = BarcodeIdentity.normalized(lastScannedBarcode) else {
            return false
        }
        manualRecoveryBarcode = normalizedBarcode
        error = nil
        return true
    }

    /// A manual entry was started from the toolbar rather than from recovery,
    /// so it must not inherit a barcode from an earlier scan.
    mutating func manualEntryOpened() {
        manualRecoveryBarcode = nil
    }

    /// A manual entry was saved; whatever the scan could not resolve, the user
    /// has now resolved themselves.
    mutating func manualEntrySaved() {
        clearRecoveryContext()
    }

    /// The camera was reopened, which discards the previous scan's outcome.
    mutating func scannerOpened() {
        clearRecoveryContext()
    }

    /// The user started a name search, which is giving up on the scan.
    mutating func nameSearchStarted() {
        clearRecoveryContext()
    }

    /// Both ways a lookup starts. `isLookingUp` is set here rather than when
    /// the request actually begins so the spinner replaces the camera in the
    /// same update, with no frame of the resting list in between.
    private mutating func beginLookup(_ barcode: String) {
        error = nil
        isLookingUp = true
        pendingBarcode = barcode
    }

    /// Leaves any in-flight lookup alone: these are all things the user does
    /// *instead of* the failed scan, not things that stop a running request.
    private mutating func clearRecoveryContext() {
        error = nil
        lastScannedBarcode = nil
        manualRecoveryBarcode = nil
    }
}
