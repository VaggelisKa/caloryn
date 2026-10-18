import XCTest
@testable import Caloryn

final class SettingsProfileSummaryTests: XCTestCase {
    func testMeasurementsRenderInMetricWithTheStoredPrecision() {
        let summary = makeSummary(age: 34, heightCm: 168, weightKg: 72.5)

        XCTAssertEqual(summary.ageText, "34")
        XCTAssertEqual(summary.heightText, "168 cm")
        XCTAssertEqual(summary.weightText(locale: Self.us), "72.5 kg")
    }

    func testWeightAlwaysShowsOneDecimal() {
        XCTAssertEqual(makeSummary(weightKg: 70).weightText(locale: Self.us), "70.0 kg")
    }

    func testWeightIsRoundedToTheNearestTenthNotTruncated() {
        XCTAssertEqual(makeSummary(weightKg: 72.46).weightText(locale: Self.us), "72.5 kg")
    }

    func testWeightIsPointedForTheLocale() {
        XCTAssertEqual(makeSummary(weightKg: 72.5).weightText(locale: Locale(identifier: "da_DK")), "72,5 kg")
    }

    private static let us = Locale(identifier: "en_US")

    func testHeightTruncatesAnyFraction() {
        XCTAssertEqual(makeSummary(heightCm: 179.9).heightText, "179 cm")
    }

    func testSexAndActivityUseTheirDisplayNames() {
        let summary = makeSummary(sex: .female, activityLevel: .moderatelyActive)

        XCTAssertEqual(summary.sexText, Sex.female.displayName)
        XCTAssertEqual(summary.activityText, "Moderately active")
    }

    private func makeSummary(
        age: Int = 30,
        sex: Sex = .male,
        heightCm: Double = 175,
        weightKg: Double = 70,
        activityLevel: ActivityLevel = .sedentary
    ) -> SettingsProfileSummary {
        SettingsProfileSummary(
            age: age,
            sex: sex,
            heightCm: heightCm,
            weightKg: weightKg,
            activityLevel: activityLevel
        )
    }
}
