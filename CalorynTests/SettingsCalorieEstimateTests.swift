import XCTest
@testable import Caloryn

final class SettingsCalorieEstimateTests: XCTestCase {
    // MARK: - Toggle

    func testToggleIsBoundAndOnWhileAutoAdjustIsEnabled() {
        let estimate = makeEstimate(energyCalculationMode: .dynamicHealth)

        XCTAssertTrue(estimate.isToggleBound)
        XCTAssertTrue(estimate.isToggleOn)
        XCTAssertFalse(estimate.isToggleDisabled)
    }

    func testToggleIsBoundAndOffForLifestyleEstimate() {
        let estimate = makeEstimate(energyCalculationMode: .lifestyleEstimate)

        XCTAssertTrue(estimate.isToggleBound)
        XCTAssertFalse(estimate.isToggleOn)
        XCTAssertFalse(estimate.isToggleDisabled)
    }

    func testManualOverrideShowsAFixedDisabledToggle() {
        let estimate = makeEstimate(isManualOverride: true, energyCalculationMode: .dynamicHealth)

        XCTAssertFalse(estimate.isToggleBound)
        XCTAssertFalse(estimate.isToggleOn)
        XCTAssertTrue(estimate.isToggleDisabled)
    }

    func testToggleIsDisabledWhileAuthorizationIsBeingRequested() {
        let estimate = makeEstimate(
            energyCalculationMode: .lifestyleEstimate,
            isRequestingAuthorization: true
        )

        XCTAssertTrue(estimate.isToggleDisabled)
    }

    func testToggleIsDisabledWhenHealthIsUnavailableAndAutoAdjustIsOff() {
        let estimate = makeEstimate(
            energyCalculationMode: .lifestyleEstimate,
            isHealthAvailable: false
        )

        XCTAssertTrue(estimate.isToggleDisabled)
    }

    func testAlreadyEnabledAutoAdjustStaysTurnOffableWithoutHealth() {
        let estimate = makeEstimate(
            energyCalculationMode: .dynamicHealth,
            isHealthAvailable: false
        )

        XCTAssertFalse(estimate.isToggleDisabled)
    }

    // MARK: - Mode presentation

    func testEffectiveModeIgnoresStoredModeUnderManualOverride() {
        let estimate = makeEstimate(isManualOverride: true, energyCalculationMode: .dynamicHealth)

        XCTAssertEqual(estimate.effectiveEnergyCalculationMode, .lifestyleEstimate)
        XCTAssertEqual(estimate.modeIconName, "figure.walk")
    }

    func testHealthDrivenModeUsesTheHealthIcon() {
        XCTAssertEqual(
            makeEstimate(energyCalculationMode: .dynamicHealth).modeIconName,
            "heart.text.square.fill"
        )
    }

    func testSubtitleNamesTheReasonAutoAdjustIsOff() {
        XCTAssertEqual(
            makeEstimate(isManualOverride: true, energyCalculationMode: .dynamicHealth).modeSubtitle,
            "Off - manual calorie target is set"
        )
        XCTAssertEqual(
            makeEstimate(energyCalculationMode: .lifestyleEstimate).modeSubtitle,
            "Off - using your activity level"
        )
        XCTAssertEqual(
            makeEstimate(energyCalculationMode: .dynamicHealth).modeSubtitle,
            "On - using Health data when available"
        )
    }

    // MARK: - Section content

    func testDynamicMetricsOnlyAppearWhileHealthDrivesTheTarget() {
        XCTAssertTrue(makeEstimate(energyCalculationMode: .dynamicHealth).showsDynamicMetrics)
        XCTAssertFalse(makeEstimate(energyCalculationMode: .lifestyleEstimate).showsDynamicMetrics)
        XCTAssertFalse(
            makeEstimate(isManualOverride: true, energyCalculationMode: .dynamicHealth).showsDynamicMetrics
        )
    }

    func testDynamicStatusReadsAsInformationOnlyWhileAutoAdjustIsOn() {
        XCTAssertTrue(makeEstimate(energyCalculationMode: .dynamicHealth).isDynamicStatusInformational)
        XCTAssertFalse(makeEstimate(energyCalculationMode: .lifestyleEstimate).isDynamicStatusInformational)
    }

    /// The stored mode is what the tracker follows, but a manual override
    /// silences it.
    func testActiveEnergyTrackingFollowsTheEffectiveMode() {
        XCTAssertTrue(makeEstimate(energyCalculationMode: .dynamicHealth).isActiveEnergyTrackingEnabled)
        XCTAssertFalse(
            makeEstimate(isManualOverride: true, energyCalculationMode: .dynamicHealth).isActiveEnergyTrackingEnabled
        )
    }

    func testFooterExplainsManualOverrideFirst() {
        let estimate = makeEstimate(
            isManualOverride: true,
            energyCalculationMode: .dynamicHealth,
            isHealthAvailable: false
        )

        XCTAssertEqual(
            estimate.footerText,
            "Manual calorie targets stay fixed until you turn the override off."
        )
    }

    func testFooterReportsAnUnavailableHealthStore() {
        let estimate = makeEstimate(energyCalculationMode: .lifestyleEstimate, isHealthAvailable: false)

        XCTAssertEqual(estimate.footerText, AppleHealthAdjustmentSettings.unavailableMessage)
    }

    func testFooterDescribesHowToTurnAutoAdjustOffWhenItIsOn() {
        let estimate = makeEstimate(energyCalculationMode: .dynamicHealth)

        XCTAssertTrue(estimate.footerText.contains("Turn it off to use your activity level instead."))
    }

    func testFooterOffersAutoAdjustWhenItIsAvailableButOff() {
        let estimate = makeEstimate(energyCalculationMode: .lifestyleEstimate)

        XCTAssertEqual(
            estimate.footerText,
            "Your activity level sets the estimate. Auto-adjust can use Apple Health activity instead."
        )
    }

    // MARK: - Metric values

    func testValidDaysReadsAgainstTheRequiredCount() {
        XCTAssertEqual(
            SettingsCalorieEstimate.validActivityDaysText(validActivityDays: 3),
            "3/\(ActivityCalorieBudget.requiredDynamicActivityDays)"
        )
    }

    func testBaselineIsADashUntilThereIsOne() {
        XCTAssertEqual(SettingsCalorieEstimate.baselineText(activityBaselineKcal: nil), "-")
    }

    func testBaselineIsRoundedToWholeKilocalories() {
        XCTAssertEqual(SettingsCalorieEstimate.baselineText(activityBaselineKcal: 512.6), "513 kcal")
        XCTAssertEqual(SettingsCalorieEstimate.baselineText(activityBaselineKcal: 512.4), "512 kcal")
    }

    // MARK: - Tracker fallback

    func testTrackerProblemDropsAutoAdjustBackToTheLifestyleEstimate() {
        XCTAssertTrue(
            SettingsCalorieEstimate.fallsBackToLifestyle(
                energyCalculationMode: .dynamicHealth,
                trackerMessage: "No Health access"
            )
        )
    }

    func testTrackerSilenceLeavesAutoAdjustAlone() {
        XCTAssertFalse(
            SettingsCalorieEstimate.fallsBackToLifestyle(
                energyCalculationMode: .dynamicHealth,
                trackerMessage: nil
            )
        )
    }

    func testTrackerProblemChangesNothingWhenAutoAdjustIsAlreadyOff() {
        XCTAssertFalse(
            SettingsCalorieEstimate.fallsBackToLifestyle(
                energyCalculationMode: .lifestyleEstimate,
                trackerMessage: "No Health access"
            )
        )
    }

    private func makeEstimate(
        isManualOverride: Bool = false,
        energyCalculationMode: EnergyCalculationMode,
        isHealthAvailable: Bool = true,
        isRequestingAuthorization: Bool = false
    ) -> SettingsCalorieEstimate {
        SettingsCalorieEstimate(
            isManualOverride: isManualOverride,
            energyCalculationMode: energyCalculationMode,
            isHealthAvailable: isHealthAvailable,
            isRequestingAuthorization: isRequestingAuthorization
        )
    }
}
