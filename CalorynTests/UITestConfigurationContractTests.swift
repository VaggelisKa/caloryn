#if DEBUG
import Foundation
import Testing
@testable import Caloryn

@MainActor
@Suite("UI test launch configuration")
struct UITestConfigurationContractTests {
    @Test("The flags are the exact strings UITestCase passes")
    func flagSpellings() {
        #expect(UITestConfiguration.resetFlag == "-uitest-reset")
        #expect(UITestConfiguration.seedFlag == "-uitest-seed")
    }

    @Test(
        "Every fixture name UITestCase can send parses to its fixture",
        arguments: [
            ("empty", UITestConfiguration.Fixture.empty),
            ("profileOnly", .profileOnly),
            ("loggedDay", .loggedDay),
            ("loggedYesterday", .loggedYesterday),
            ("customFoods", .customFoods),
            ("history", .history),
            ("historyPattern", .historyPattern),
            ("historyNoPattern", .historyNoPattern),
            ("overBudgetDay", .overBudgetDay),
        ]
    )
    func fixtureNamesParse(name: String, fixture: UITestConfiguration.Fixture) {
        #expect(UITestConfiguration.Fixture(rawValue: name) == fixture)
        #expect(fixture.rawValue == name)
    }

    @Test(
        "A misspelt or differently cased fixture name seeds nothing rather than a near match",
        arguments: ["", "LoggedDay", "logged-day", "loggedday", "History", "unknown"]
    )
    func unknownFixtureNamesAreRejected(name: String) {
        #expect(UITestConfiguration.Fixture(rawValue: name) == nil)
    }

    @Test("Without the flags the app is not in UI-test mode and requests no fixture")
    func hostLaunchHasNoUITestMode() {
        let arguments = ProcessInfo.processInfo.arguments
        #expect(arguments.contains(UITestConfiguration.resetFlag) == false)
        #expect(arguments.contains(UITestConfiguration.seedFlag) == false)

        #expect(UITestConfiguration.isActive == false)
        #expect(UITestConfiguration.fixture == nil)
    }
}
#endif
