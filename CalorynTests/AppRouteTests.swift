import XCTest
@testable import Caloryn

final class AppRouteTests: XCTestCase {
    func testTodayRouteRoundTrips() {
        let route = AppRoute.today

        XCTAssertEqual(route.url.absoluteString, "caloryn://today")
        XCTAssertEqual(AppRoute(url: route.url), route)
    }

    func testEveryMealRouteRoundTrips() {
        for meal in WidgetMeal.allCases {
            let route = AppRoute.addFood(meal: meal)

            XCTAssertEqual(AppRoute(url: route.url), route)
        }
    }

    func testInvalidRouteIsRejected() throws {
        let wrongScheme = try XCTUnwrap(URL(string: "https://today"))
        let missingMeal = try XCTUnwrap(URL(string: "caloryn://add-food"))

        XCTAssertNil(AppRoute(url: wrongScheme))
        XCTAssertNil(AppRoute(url: missingMeal))
    }
}
