import Foundation
import Testing
@testable import Caloryn

/// Which state the barcode flow is in after which event.
///
/// These transitions used to be five `@State` variables assigned by hand in
/// five different places inside `FoodSearchView`, reachable only through an
/// end-to-end journey with a camera in it. The combinations that matter are the
/// ones where two of the five disagree: a failure that keeps the barcode it
/// failed on, a success that throws it away, and a second scan arriving while
/// the first is still in flight.
struct BarcodeLookupFlowTests {
    private let barcode = "5711953150388"
    private let otherBarcode = "3017620422003"

    // MARK: - Scanning

    @Test("A scanned barcode starts a lookup and is kept for recovery")
    func scanStartsLookup() {
        var flow = BarcodeLookupFlow()
        flow.scanned(barcode)

        #expect(flow.isLookingUp)
        #expect(!flow.hasError)
        #expect(flow.pendingBarcode == barcode)
        #expect(flow.lastScannedBarcode == barcode)
    }

    @Test("A scan normalizes before it is kept, so recovery never sees raw input")
    func scanNormalizes() {
        var flow = BarcodeLookupFlow()
        flow.scanned("  \(barcode)\n")

        #expect(flow.pendingBarcode == barcode)
        #expect(flow.lastScannedBarcode == barcode)
    }

    @Test("A code that is not a product identity fails with nothing to recover from")
    func unreadableScanFails() {
        var flow = BarcodeLookupFlow()
        flow.scanned("12x")

        #expect(!flow.isLookingUp)
        #expect(flow.error == .invalidRequest)
        #expect(flow.lastScannedBarcode == nil)
        #expect(flow.pendingBarcode == nil)
        #expect(!flow.offersManualCreation)
    }

    @Test("An unreadable scan cancels the lookup already in flight")
    func unreadableScanClearsTheLookupInFlight() {
        var flow = BarcodeLookupFlow()
        flow.scanned(barcode)
        #expect(flow.pendingBarcode == barcode)

        flow.scanned("12x")

        // The failure is the screen's state now, so nothing may still be
        // running that would replace it when it resolves.
        #expect(flow.pendingBarcode == nil)
        #expect(flow.error == .invalidRequest)
        #expect(!flow.isLookingUp)
    }

    @Test("A scan clears the failure the previous scan left on screen")
    func scanClearsPreviousFailure() {
        var flow = BarcodeLookupFlow()
        flow.scanned(barcode)
        flow.lookupFailed(.notFound)

        flow.scanned(otherBarcode)

        #expect(!flow.hasError)
        #expect(flow.isLookingUp)
        #expect(flow.lastScannedBarcode == otherBarcode)
    }

    // MARK: - A scan while a lookup is already running

    @Test("Re-scanning the code already in flight leaves that lookup running")
    func rescanningTheSameCodeDoesNotRestartTheLookup() {
        var flow = BarcodeLookupFlow()
        flow.scanned(barcode)
        let inFlight = flow

        flow.scanned(barcode)

        // The pending barcode is the lookup's identity: unchanged means the
        // same request, so the view must not tear it down and start again.
        #expect(flow == inFlight)
        #expect(flow.pendingBarcode == barcode)
    }

    @Test("Scanning a different code while one is in flight supersedes it")
    func scanningAnotherCodeSupersedesTheLookup() {
        var flow = BarcodeLookupFlow()
        flow.scanned(barcode)

        flow.scanned(otherBarcode)

        #expect(flow.isLookingUp)
        #expect(flow.pendingBarcode == otherBarcode)
        #expect(flow.lastScannedBarcode == otherBarcode)
    }

    @Test("The superseded lookup's cancellation does not disturb the one that replaced it")
    func cancellationOfASupersededLookupChangesNothing() {
        var flow = BarcodeLookupFlow()
        flow.scanned(barcode)
        flow.scanned(otherBarcode)
        let running = flow

        let feedback = flow.lookupFailed(.cancelled)

        #expect(feedback == nil)
        #expect(flow == running)
        #expect(flow.isLookingUp)
        #expect(!flow.hasError)
    }

    // MARK: - Failure

    @Test("A failure keeps the barcode it failed on")
    func failureKeepsTheBarcode() {
        var flow = BarcodeLookupFlow()
        flow.scanned(barcode)

        let feedback = flow.lookupFailed(.unavailable)

        #expect(feedback == .error)
        #expect(!flow.isLookingUp)
        #expect(flow.error == .unavailable)
        #expect(flow.pendingBarcode == nil)
        #expect(flow.lastScannedBarcode == barcode)
    }

    @Test("An unknown product is a warning and the only failure offering manual creation")
    func unknownProductOffersManualCreation() {
        var flow = BarcodeLookupFlow()
        flow.scanned(barcode)

        let feedback = flow.lookupFailed(.notFound)
        #expect(feedback == .warning)
        #expect(flow.offersManualCreation)

        for error in [FoodLookupError.offline, .unavailable, .invalidData, .rateLimited] {
            var other = BarcodeLookupFlow()
            other.scanned(barcode)
            let feedback = other.lookupFailed(error)
            #expect(feedback == .error)
            #expect(!other.offersManualCreation)
        }
    }

    // MARK: - Retry

    @Test("Retrying a failure runs the same barcode again")
    func retryRepeatsTheSameLookup() {
        var flow = BarcodeLookupFlow()
        flow.scanned(barcode)
        flow.lookupFailed(.unavailable)

        let action = flow.retryRequested()
        #expect(action == .repeatLookup)
        #expect(flow.isLookingUp)
        #expect(!flow.hasError)
        #expect(flow.pendingBarcode == barcode)
    }

    @Test("A failure with no barcode to repeat sends the user back to the camera")
    func retryWithoutABarcodeRescans() {
        var flow = BarcodeLookupFlow()
        flow.scanned("nope")

        let action = flow.retryRequested()
        #expect(action == .rescan)
        #expect(!flow.hasError)
        #expect(!flow.isLookingUp)
        #expect(flow.pendingBarcode == nil)
    }

    @Test("A retry that fails again can be retried again")
    func retryIsRepeatable() {
        var flow = BarcodeLookupFlow()
        flow.scanned(barcode)
        flow.lookupFailed(.offline)
        let action = flow.retryRequested()
        #expect(action == .repeatLookup)
        flow.lookupFailed(.offline)

        #expect(flow.error == .offline)
        let secondAction = flow.retryRequested()
        #expect(secondAction == .repeatLookup)
        #expect(flow.pendingBarcode == barcode)
    }

    // MARK: - Manual recovery

    @Test("Manual recovery prefills the barcode that failed and clears the failure")
    func manualRecoveryTakesTheFailedBarcode() {
        var flow = BarcodeLookupFlow()
        flow.scanned(barcode)
        flow.lookupFailed(.notFound)

        let opened = flow.manualRecoveryOpened()
        #expect(opened)
        #expect(flow.manualRecoveryBarcode == barcode)
        #expect(!flow.hasError)
        #expect(!flow.isLookingUp)
    }

    @Test("Manual recovery with no barcode to recover leaves the failure on screen")
    func manualRecoveryWithoutABarcodeIsRefused() {
        var flow = BarcodeLookupFlow()
        flow.scanned("nope")

        let opened = flow.manualRecoveryOpened()
        #expect(!opened)
        #expect(flow.manualRecoveryBarcode == nil)
        #expect(flow.error == .invalidRequest)
    }

    @Test("A manual entry started from the toolbar inherits no barcode")
    func toolbarManualEntryDropsTheRecoveryBarcode() {
        var flow = BarcodeLookupFlow()
        flow.scanned(barcode)
        flow.lookupFailed(.notFound)
        let opened = flow.manualRecoveryOpened()
        #expect(opened)

        flow.manualEntryOpened()

        #expect(flow.manualRecoveryBarcode == nil)
    }

    @Test("Saving a manual entry ends the recovery the scan started")
    func savingAManualEntryEndsRecovery() {
        var flow = BarcodeLookupFlow()
        flow.scanned(barcode)
        flow.lookupFailed(.notFound)
        _ = flow.manualRecoveryOpened()

        flow.manualEntrySaved()

        #expect(flow.manualRecoveryBarcode == nil)
        #expect(flow.lastScannedBarcode == nil)
        #expect(!flow.hasError)
    }

    // MARK: - Success

    @Test("A resolved product clears the failure state and the barcode with it")
    func successClearsEverything() {
        var flow = BarcodeLookupFlow()
        flow.scanned(barcode)
        flow.lookupFailed(.unavailable)
        let action = flow.retryRequested()
        #expect(action == .repeatLookup)

        flow.lookupSucceeded()

        #expect(!flow.isLookingUp)
        #expect(!flow.hasError)
        #expect(flow.pendingBarcode == nil)
        #expect(flow.lastScannedBarcode == nil)
    }

    @Test("Nothing is left to retry once a lookup has succeeded")
    func retryAfterSuccessRescans() {
        var flow = BarcodeLookupFlow()
        flow.scanned(barcode)
        flow.lookupSucceeded()

        let action = flow.retryRequested()
        #expect(action == .rescan)
    }

    // MARK: - Dismissal

    @Test("Reopening the camera discards the previous scan's outcome")
    func reopeningTheScannerClearsRecovery() {
        var flow = BarcodeLookupFlow()
        flow.scanned(barcode)
        flow.lookupFailed(.notFound)
        _ = flow.manualRecoveryOpened()

        flow.scannerOpened()

        #expect(!flow.hasError)
        #expect(flow.lastScannedBarcode == nil)
        #expect(flow.manualRecoveryBarcode == nil)
    }

    @Test("Starting a name search gives up on the scan")
    func nameSearchClearsRecovery() {
        var flow = BarcodeLookupFlow()
        flow.scanned(barcode)
        flow.lookupFailed(.notFound)

        flow.nameSearchStarted()

        #expect(!flow.hasError)
        #expect(flow.lastScannedBarcode == nil)
        #expect(!flow.errorDismissesOnNameSearch)
    }

    @Test("Only a failure that is still on screen can be dismissed by typing")
    func onlyAnOnScreenFailureDismissesOnNameSearch() {
        var flow = BarcodeLookupFlow()
        #expect(!flow.errorDismissesOnNameSearch)

        flow.scanned(barcode)
        #expect(!flow.errorDismissesOnNameSearch)

        flow.lookupFailed(.offline)
        #expect(flow.errorDismissesOnNameSearch)
    }

    // MARK: - Seeded state

    @Test("A flow seeded with a failure behaves as if that scan had just failed")
    func seededFailureSupportsRecovery() {
        var flow = BarcodeLookupFlow(error: .notFound, lastScannedBarcode: barcode)

        #expect(flow.hasError)
        #expect(flow.offersManualCreation)
        #expect(!flow.isLookingUp)
        let action = flow.retryRequested()
        #expect(action == .repeatLookup)
        #expect(flow.pendingBarcode == barcode)
    }
}
