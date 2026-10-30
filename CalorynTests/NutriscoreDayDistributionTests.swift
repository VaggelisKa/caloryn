import XCTest
@testable import Caloryn

@MainActor
final class NutriscoreDayDistributionTests: XCTestCase {
    func testGradesAreCountedInAToEOrder() {
        let distribution = NutriscoreDayDistribution.distribution(of: ["c", "a", "e", "a"])

        XCTAssertEqual(distribution.map(\.grade), ["a", "c", "e"])
        XCTAssertEqual(distribution.map(\.count), [2, 1, 1])
    }

    func testGradesAreCountedRegardlessOfCase() {
        let distribution = NutriscoreDayDistribution.distribution(of: ["A", "a", "B"])

        XCTAssertEqual(distribution.map(\.grade), ["a", "b"])
        XCTAssertEqual(distribution.map(\.count), [2, 1])
    }

    func testGradesWithNothingLoggedAreOmitted() {
        let distribution = NutriscoreDayDistribution.distribution(of: ["b"])

        XCTAssertEqual(distribution.map(\.grade), ["b"])
    }

    func testUngradedEntriesAreNotCounted() {
        let distribution = NutriscoreDayDistribution.distribution(of: ["a", nil, nil])

        XCTAssertEqual(distribution.map(\.count), [1])
    }

    func testAnUnrecognisedGradeIsNotCountedAsAnyGrade() {
        let distribution = NutriscoreDayDistribution.distribution(of: ["z", "?", ""])

        XCTAssertTrue(distribution.isEmpty)
    }

    func testADayWithNothingLoggedHasNoDistribution() {
        XCTAssertTrue(NutriscoreDayDistribution.distribution(of: []).isEmpty)
    }

    func testADayWithAGradeHasData() {
        XCTAssertTrue(NutriscoreDayDistribution.hasData(["a", nil]))
    }

    func testADayWithNoGradesAtAllHasNoData() {
        XCTAssertFalse(NutriscoreDayDistribution.hasData([nil, nil]))
        XCTAssertFalse(NutriscoreDayDistribution.hasData([]))
    }

    func testAnUnrecognisedGradeStillCountsAsHavingData() {
        XCTAssertTrue(NutriscoreDayDistribution.hasData(["z"]))
        XCTAssertTrue(NutriscoreDayDistribution.distribution(of: ["z"]).isEmpty)
    }
}
