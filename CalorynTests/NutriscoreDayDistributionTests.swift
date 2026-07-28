import XCTest
@testable import Caloryn

final class NutriscoreDayDistributionTests: XCTestCase {
    // MARK: - Counting

    func testGradesAreCountedInAToEOrder() {
        let distribution = NutriscoreDayDistribution.distribution(of: ["c", "a", "e", "a"])

        XCTAssertEqual(distribution.map(\.grade), ["a", "c", "e"])
        XCTAssertEqual(distribution.map(\.count), [2, 1, 1])
    }

    /// Grades arrive from product data in either case, and "A" and "a" are the
    /// same grade.
    func testGradesAreCountedRegardlessOfCase() {
        let distribution = NutriscoreDayDistribution.distribution(of: ["A", "a", "B"])

        XCTAssertEqual(distribution.map(\.grade), ["a", "b"])
        XCTAssertEqual(distribution.map(\.count), [2, 1])
    }

    /// A grade nothing was logged for is left out entirely rather than drawn as
    /// an empty bar.
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

    // MARK: - Presence

    func testADayWithAGradeHasData() {
        XCTAssertTrue(NutriscoreDayDistribution.hasData(["a", nil]))
    }

    func testADayWithNoGradesAtAllHasNoData() {
        XCTAssertFalse(NutriscoreDayDistribution.hasData([nil, nil]))
        XCTAssertFalse(NutriscoreDayDistribution.hasData([]))
    }

    /// Having data and having a countable grade are separate questions: a food
    /// graded with something unrecognised was still graded, and hiding the card
    /// would claim it never was.
    func testAnUnrecognisedGradeStillCountsAsHavingData() {
        XCTAssertTrue(NutriscoreDayDistribution.hasData(["z"]))
        XCTAssertTrue(NutriscoreDayDistribution.distribution(of: ["z"]).isEmpty)
    }
}
