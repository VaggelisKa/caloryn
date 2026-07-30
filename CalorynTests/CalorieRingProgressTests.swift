import XCTest
@testable import Caloryn

final class CalorieRingProgressTests: XCTestCase {
    // MARK: - Without an auto-adjust stretch

    func testTheBaseArcRunsFromTheTopToWhereverProgressHasReached() {
        let progress = makeProgress(animatedProgress: 0.62, baseProgressEnd: 1)

        XCTAssertEqual(progress.baseArc.start, 0)
        XCTAssertEqual(progress.baseArc.end, 0.62, accuracy: 0.0001)
        XCTAssertTrue(progress.baseArc.isVisible)
    }

    func testTheAutoAdjustArcsStayHiddenWhenNothingWasAdded() {
        let progress = makeProgress(animatedProgress: 0.62, baseProgressEnd: 1)

        XCTAssertFalse(progress.dynamicTrack.isVisible)
        XCTAssertFalse(progress.dynamicArc.isVisible)
    }

    /// A hidden track is also collapsed to zero length, so it cannot flash into
    /// view part-drawn while its opacity animates.
    func testTheHiddenAutoAdjustTrackHasNoLength() {
        let progress = makeProgress(animatedProgress: 0.4, baseProgressEnd: 0.9)

        XCTAssertEqual(progress.dynamicTrack.start, progress.dynamicTrack.end)
    }

    // MARK: - The zero threshold

    func testAnEmptyDayLeavesTheBaseArcUndrawn() {
        XCTAssertFalse(makeProgress(animatedProgress: 0).baseArc.isVisible)
        XCTAssertFalse(makeProgress(animatedProgress: 0.009).baseArc.isVisible)
    }

    func testTheSmallestProgressWorthShowingDrawsTheBaseArc() {
        XCTAssertTrue(makeProgress(animatedProgress: 0.01).baseArc.isVisible)
    }

    /// Characterizing the view's original test, which asked whether progress was
    /// *below* the threshold: a progress that is not a number is below nothing,
    /// so the arc is drawn rather than the ring being blanked.
    func testAProgressThatIsNotANumberStillDrawsTheBaseArc() {
        XCTAssertTrue(makeProgress(animatedProgress: .nan).baseArc.isVisible)
    }

    // MARK: - With an auto-adjust stretch

    func testTheAutoAdjustTrackSpansFromTheBaseGoalToAFullTurn() {
        let progress = makeProgress(
            animatedProgress: 0,
            baseProgressEnd: 0.8,
            hasDynamicIncrease: true
        )

        XCTAssertEqual(progress.dynamicTrack.start, 0.8, accuracy: 0.0001)
        XCTAssertEqual(progress.dynamicTrack.end, 1)
        XCTAssertTrue(progress.dynamicTrack.isVisible)
    }

    func testTheBaseArcStopsAtTheSeamOnceProgressPassesTheBaseGoal() {
        let progress = makeProgress(
            animatedProgress: 0.95,
            baseProgressEnd: 0.8,
            hasDynamicIncrease: true
        )

        XCTAssertEqual(progress.baseArc.end, 0.8, accuracy: 0.0001)
    }

    func testTheAutoAdjustArcCarriesOnFromTheSeam() {
        let progress = makeProgress(
            animatedProgress: 0.95,
            baseProgressEnd: 0.8,
            hasDynamicIncrease: true
        )

        XCTAssertEqual(progress.dynamicArc.start, 0.8, accuracy: 0.0001)
        XCTAssertEqual(progress.dynamicArc.end, 0.95, accuracy: 0.0001)
        XCTAssertTrue(progress.dynamicArc.isVisible)
    }

    func testTheAutoAdjustArcIsUndrawnUntilProgressReachesTheSeam() {
        let progress = makeProgress(
            animatedProgress: 0.5,
            baseProgressEnd: 0.8,
            hasDynamicIncrease: true
        )

        XCTAssertFalse(progress.dynamicArc.isVisible)
        XCTAssertEqual(progress.dynamicArc.start, progress.dynamicArc.end)
    }

    /// The two arcs must meet exactly, or the ring shows a gap or an overlap at
    /// the seam.
    func testTheTwoArcsMeetAtTheSeamWithoutAGap() {
        let progress = makeProgress(
            animatedProgress: 0.87,
            baseProgressEnd: 0.72,
            hasDynamicIncrease: true
        )

        XCTAssertEqual(progress.baseArc.end, progress.dynamicArc.start, accuracy: 0.0001)
    }

    func testNoArcIsEverDrawnPastAFullTurn() {
        let progress = makeProgress(
            animatedProgress: 1.4,
            baseProgressEnd: 0.8,
            hasDynamicIncrease: true
        )

        XCTAssertEqual(progress.dynamicArc.end, 1)
        XCTAssertLessThanOrEqual(progress.baseArc.end, 1)
    }

    // MARK: - Reading the budget

    /// The progress figures have to come from the budget's own derivation; a
    /// second one computed from calories here is how a ring and its number
    /// drift apart.
    func testTheBudgetsOwnProgressFiguresAreUsedAsGiven() {
        let budget = makeBudget(consumed: 1_000, staticTarget: 2_000)
        let progress = CalorieRingProgress(budget: budget, animatedProgress: 0.5)

        XCTAssertEqual(progress.baseProgressEnd, budget.baseProgressEnd)
        XCTAssertEqual(progress.hasDynamicIncrease, budget.hasDynamicIncrease)
        XCTAssertEqual(progress.animatedProgress, 0.5)
    }

    // MARK: - Helpers

    private func makeProgress(
        animatedProgress: Double,
        baseProgressEnd: Double = 1,
        hasDynamicIncrease: Bool = false
    ) -> CalorieRingProgress {
        CalorieRingProgress(
            animatedProgress: animatedProgress,
            baseProgressEnd: baseProgressEnd,
            hasDynamicIncrease: hasDynamicIncrease
        )
    }

    private func makeBudget(consumed: Double, staticTarget: Int) -> ActivityCalorieBudget {
        ActivityCalorieBudget(
            consumed: consumed,
            staticTarget: staticTarget,
            bmr: 1_700,
            calorieDeficit: 500,
            activeEnergyKcal: 0,
            recentActiveEnergySamples: [],
            calculationMode: .lifestyleEstimate,
            isManualOverride: false,
            isActivityLoading: false,
            activityMessage: nil,
            date: .now
        )
    }
}
